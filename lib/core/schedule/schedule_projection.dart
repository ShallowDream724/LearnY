import 'package:intl/intl.dart';

import '../api/models.dart' as api;
import '../database/database.dart' as db;
import 'semester_schedule_cache.dart' as schedule_cache;
import 'schedule_models.dart';

String buildHomeScheduleEmptyLabel(HomeScheduleDayOption day) {
  if (day.isToday) {
    return '今天没有课';
  }
  return '${DateFormat('M月d日').format(day.date)} 没有课';
}

List<HomeScheduleDayOption> buildHomeScheduleDays(
  DateTime startDay, {
  int length = 7,
  DateTime? today,
}) {
  final start = DateTime(startDay.year, startDay.month, startDay.day);
  final reference = today ?? start;
  return List<HomeScheduleDayOption>.generate(length, (index) {
    final date = start.add(Duration(days: index));
    return HomeScheduleDayOption(
      date: date,
      label: _buildDayLabel(date, today: reference),
      weekdayLabel: _weekdayLabel(date),
      shortDateLabel: DateFormat('M/d').format(date),
      isToday: _isSameDay(date, reference),
    );
  });
}

DateTime scheduleWeekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

HomeScheduleSnapshot buildHomeScheduleSnapshotFromCalendarEvents({
  required List<HomeScheduleDayOption> days,
  required List<api.CalendarEvent> events,
  Map<String, String>? courseIdsByName,
}) {
  final allowedKeys = {for (final day in days) day.dateKey};
  final grouped = <String, List<TodayScheduleItem>>{
    for (final day in days) day.dateKey: <TodayScheduleItem>[],
  };

  for (final event in events) {
    final dayKey = _resolveEventDayKey(event.date, allowedKeys);
    if (dayKey == null) {
      continue;
    }

    final item = _mapCalendarEvent(
      event,
      courseId: courseIdsByName?[event.courseName.trim()],
    );
    if (item == null) {
      continue;
    }

    grouped.putIfAbsent(dayKey, () => <TodayScheduleItem>[]).add(item);
  }

  for (final entry in grouped.entries) {
    entry.value.sort(
      (left, right) => left.startTime.compareTo(right.startTime),
    );
    grouped[entry.key] = _mergeAdjacentScheduleItems(entry.value);
  }

  return HomeScheduleSnapshot(days: days, itemsByDateKey: grouped);
}

HomeScheduleSnapshot buildHomeScheduleSnapshotFromCachedCourses({
  required List<HomeScheduleDayOption> days,
  required List<db.Course> courses,
  required String semesterStartDate,
  String? semesterEndDate,
}) {
  final cache = schedule_cache.buildSemesterScheduleCacheFromCourses(
    semesterId: '',
    semesterStartDate: semesterStartDate,
    courses: courses,
  );
  return buildHomeScheduleSnapshotFromSemesterScheduleCache(
    days: days,
    cache: cache,
    semesterEndDate: semesterEndDate,
  );
}

HomeScheduleSnapshot mergeHomeScheduleSnapshots({
  required HomeScheduleSnapshot primary,
  required HomeScheduleSnapshot fallback,
}) {
  final mergedItemsByDateKey = <String, List<TodayScheduleItem>>{};

  for (final day in primary.days) {
    final primaryItems = [...primary.itemsFor(day)];
    final knownKeys = primaryItems
        .map(_scheduleItemIdentityKey)
        .whereType<String>()
        .toSet();

    for (final item in fallback.itemsFor(day)) {
      // A calendar occurrence overrides a local estimate of the same class,
      // even when the registrar changed its room or duration.
      final overlapping = primaryItems.indexWhere(
        (known) =>
            _matchesScheduleCourse(known, item) &&
            _overlapsScheduleTime(known, item),
      );
      if (overlapping >= 0) {
        final preferred = primaryItems[overlapping];
        primaryItems[overlapping] = TodayScheduleItem(
          courseId: preferred.courseId ?? item.courseId,
          courseName: preferred.courseName,
          startTime: preferred.startTime,
          endTime: preferred.endTime,
          location: preferred.location.isEmpty
              ? item.location
              : preferred.location,
        );
        continue;
      }
      final identityKey = _scheduleItemIdentityKey(item);
      if (identityKey != null && knownKeys.contains(identityKey)) {
        continue;
      }
      primaryItems.add(item);
      if (identityKey != null) {
        knownKeys.add(identityKey);
      }
    }

    primaryItems.sort((left, right) {
      final byStart = left.startTime.compareTo(right.startTime);
      if (byStart != 0) {
        return byStart;
      }
      final byCourse = left.courseName.compareTo(right.courseName);
      if (byCourse != 0) {
        return byCourse;
      }
      return left.location.compareTo(right.location);
    });

    mergedItemsByDateKey[day.dateKey] = _mergeAdjacentScheduleItems(
      primaryItems,
    );
  }

  return HomeScheduleSnapshot(
    days: primary.days,
    itemsByDateKey: mergedItemsByDateKey,
  );
}

HomeScheduleSnapshot buildHomeScheduleSnapshotFromSemesterScheduleCache({
  required List<HomeScheduleDayOption> days,
  required schedule_cache.SemesterScheduleCache cache,
  String? semesterEndDate,
}) {
  final endDate = DateTime.tryParse(semesterEndDate ?? '');
  final resolved = schedule_cache.resolveSemesterScheduleItemsByDateKey(
    cache: cache,
    dates: days
        .map((day) => day.date)
        .where((date) => endDate == null || !date.isAfter(endDate))
        .toList(growable: false),
  );
  return HomeScheduleSnapshot(
    days: days,
    itemsByDateKey: {
      for (final day in days)
        day.dateKey: [
          for (final item in resolved[day.dateKey] ?? const [])
            TodayScheduleItem(
              courseId: item.courseId,
              courseName: item.courseName,
              startTime: item.startTime,
              endTime: item.endTime,
              location: item.location,
            ),
        ],
    },
  );
}

HomeScheduleSnapshot emptyScheduleSnapshot(List<HomeScheduleDayOption> days) {
  return HomeScheduleSnapshot(
    days: days,
    itemsByDateKey: {
      for (final day in days) day.dateKey: const <TodayScheduleItem>[],
    },
  );
}

const Duration _homeScheduleRemoteRefreshInterval = Duration(hours: 12);
const Duration _homeScheduleRemoteRetryBackoff = Duration(hours: 2);
bool shouldFetchHomeScheduleRemoteSnapshot({
  required String semesterId,
  required HomeScheduleSnapshot? cachedSnapshot,
  required HomeScheduleSnapshot localSnapshot,
  HomeScheduleSnapshot? semesterSnapshot,
  required HomeScheduleRemoteRefreshState? refreshState,
  required DateTime now,
}) {
  final hasAnyData =
      (cachedSnapshot != null && hasScheduleItems(cachedSnapshot)) ||
      hasScheduleItems(localSnapshot) ||
      (semesterSnapshot != null && hasScheduleItems(semesterSnapshot));

  if (refreshState == null || refreshState.semesterId != semesterId) {
    return true;
  }
  if (refreshState.hasSuccessfulRefresh) {
    return now.difference(refreshState.lastAttemptAt) >=
        _homeScheduleRemoteRefreshInterval;
  }
  if (!hasAnyData) {
    return now.difference(refreshState.lastAttemptAt) >=
        const Duration(minutes: 1);
  }
  return now.difference(refreshState.lastAttemptAt) >=
      _homeScheduleRemoteRetryBackoff;
}

HomeScheduleSnapshot mergeLocalScheduleSnapshot({
  required HomeScheduleSnapshot currentSnapshot,
  required HomeScheduleSnapshot? semesterSnapshot,
}) {
  final hasCurrent = hasScheduleItems(currentSnapshot);
  final hasSemester =
      semesterSnapshot != null && hasScheduleItems(semesterSnapshot);

  if (hasCurrent && hasSemester) {
    return mergeHomeScheduleSnapshots(
      primary: currentSnapshot,
      fallback: semesterSnapshot,
    );
  }
  if (hasCurrent) {
    return currentSnapshot;
  }
  if (hasSemester) {
    return semesterSnapshot;
  }
  return currentSnapshot;
}

bool hasScheduleItems(HomeScheduleSnapshot snapshot) {
  return snapshot.itemsByDateKey.values.any((items) => items.isNotEmpty);
}

String? _scheduleItemIdentityKey(TodayScheduleItem item) {
  final courseName = item.courseName.trim();
  final courseIdentity = courseName.isNotEmpty
      ? courseName
      : item.courseId?.trim() ?? '';
  if (courseIdentity.isEmpty) {
    return null;
  }
  final startTime = item.startTime.trim();
  final location = item.location.trim();
  return '$courseIdentity|$startTime|$location';
}

List<TodayScheduleItem> _mergeAdjacentScheduleItems(
  List<TodayScheduleItem> items,
) {
  if (items.isEmpty) {
    return const <TodayScheduleItem>[];
  }

  final sorted = [...items]
    ..sort((left, right) {
      final byStart = left.startTime.compareTo(right.startTime);
      if (byStart != 0) {
        return byStart;
      }
      final byCourse = _scheduleCourseSortKey(
        left,
      ).compareTo(_scheduleCourseSortKey(right));
      if (byCourse != 0) {
        return byCourse;
      }
      return left.location.compareTo(right.location);
    });

  final merged = <TodayScheduleItem>[sorted.first];
  for (final next in sorted.skip(1)) {
    final current = merged.last;
    if (_canMergeAdjacentScheduleItems(current, next)) {
      merged[merged.length - 1] = TodayScheduleItem(
        courseId: current.courseId ?? next.courseId,
        courseName: current.courseName.isNotEmpty
            ? current.courseName
            : next.courseName,
        startTime: current.startTime,
        endTime: next.endTime.isNotEmpty ? next.endTime : current.endTime,
        location: current.location.isNotEmpty
            ? current.location
            : next.location,
      );
      continue;
    }
    merged.add(next);
  }

  return merged;
}

bool _canMergeAdjacentScheduleItems(
  TodayScheduleItem current,
  TodayScheduleItem next,
) {
  if (!_matchesScheduleCourse(current, next)) {
    return false;
  }

  if (current.location.trim() != next.location.trim()) {
    return false;
  }

  return _isAdjacentScheduleBoundary(
    currentEndTime: current.endTime,
    nextStartTime: next.startTime,
  );
}

String _scheduleCourseSortKey(TodayScheduleItem item) {
  final courseName = item.courseName.trim();
  if (courseName.isNotEmpty) {
    return courseName;
  }
  final courseId = item.courseId?.trim() ?? '';
  if (courseId.isNotEmpty) {
    return courseId;
  }
  return '';
}

bool _matchesScheduleCourse(TodayScheduleItem left, TodayScheduleItem right) {
  final leftCourseId = left.courseId?.trim() ?? '';
  final rightCourseId = right.courseId?.trim() ?? '';
  if (leftCourseId.isNotEmpty && rightCourseId.isNotEmpty) {
    return leftCourseId == rightCourseId;
  }

  final leftCourseName = left.courseName.trim();
  final rightCourseName = right.courseName.trim();
  if (leftCourseName.isNotEmpty &&
      rightCourseName.isNotEmpty &&
      leftCourseName == rightCourseName) {
    return true;
  }

  return false;
}

bool _overlapsScheduleTime(TodayScheduleItem left, TodayScheduleItem right) {
  int? minutes(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return null;
    final hours = int.parse(match[1]!);
    final minutes = int.parse(match[2]!);
    return hours < 24 && minutes < 60 ? hours * 60 + minutes : null;
  }

  final leftStart = minutes(left.startTime);
  final rightStart = minutes(right.startTime);
  if (leftStart == null || rightStart == null) return false;
  if (leftStart == rightStart) return true;
  final leftEnd = minutes(left.endTime);
  final rightEnd = minutes(right.endTime);
  return leftEnd != null &&
      rightEnd != null &&
      leftStart < rightEnd &&
      rightStart < leftEnd;
}

bool _isAdjacentScheduleBoundary({
  required String currentEndTime,
  required String nextStartTime,
}) {
  final endTime = currentEndTime.trim();
  final startTime = nextStartTime.trim();
  if (endTime.isEmpty || startTime.isEmpty) {
    return false;
  }

  const adjacentBoundaries = <String, Set<String>>{
    '08:45': {'08:50'},
    '09:35': {'09:50'},
    '10:35': {'10:40'},
    '11:25': {'11:30', '13:30'},
    '12:15': {'13:30'},
    '14:15': {'14:20'},
    '15:05': {'15:20'},
    '16:05': {'16:10'},
    '16:55': {'17:05'},
    '17:50': {'17:55'},
    '18:40': {'19:20'},
    '20:05': {'20:10'},
    '20:55': {'21:00'},
  };

  return adjacentBoundaries[endTime]?.contains(startTime) == true;
}

String? _resolveEventDayKey(String raw, Set<String> allowedKeys) {
  final normalized = _normalizeDateKey(raw);
  if (normalized != null && allowedKeys.contains(normalized)) {
    return normalized;
  }

  if (allowedKeys.length == 1) {
    return allowedKeys.first;
  }

  return null;
}

String? _normalizeDateKey(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }

  final parsed = _parseDateOnly(value);
  if (parsed != null) {
    return DateFormat('yyyy-MM-dd').format(parsed);
  }

  return null;
}

DateTime? _parseDateOnly(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }

  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  final match = RegExp(r'(20\d{2})[^\d]?(\d{1,2})[^\d]?(\d{1,2})').firstMatch(
    value.replaceAll('年', '-').replaceAll('月', '-').replaceAll('日', ''),
  );
  if (match == null) {
    return null;
  }

  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

TodayScheduleItem? _mapCalendarEvent(
  api.CalendarEvent event, {
  String? courseId,
}) {
  final courseName = event.courseName.trim();
  final startTime = _normalizeClockText(event.startTime);
  final endTime = _normalizeClockText(event.endTime);
  final location = event.location.trim();

  if (courseName.isEmpty && startTime.isEmpty && location.isEmpty) {
    return null;
  }

  return TodayScheduleItem(
    courseId: courseId,
    courseName: courseName,
    startTime: startTime,
    endTime: endTime,
    location: location,
  );
}

String _normalizeClockText(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return '';
  }

  final match = RegExp(r'(\d{1,2}:\d{2})').firstMatch(value);
  if (match != null) {
    return match.group(1)!;
  }

  return value;
}

bool _isSameDay(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

String _buildDayLabel(DateTime date, {required DateTime today}) {
  final diff = date.difference(today).inDays;
  if (diff == 0) return '今天';
  if (diff == 1) return '明天';
  if (diff == 2) return '后天';

  const weekdayNames = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return weekdayNames[date.weekday - 1];
}

String _weekdayLabel(DateTime date) {
  const weekdayNames = <String>['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  return weekdayNames[date.weekday - 1];
}

Map<String, String> uniqueCourseIdsByName(List<db.Course> courses) {
  final grouped = <String, Set<String>>{};
  for (final course in courses) {
    for (final candidate in [
      course.name,
      course.chineseName,
      course.englishName,
    ]) {
      final name = candidate.trim();
      if (name.isEmpty) {
        continue;
      }
      grouped.putIfAbsent(name, () => <String>{}).add(course.id);
    }
  }

  return {
    for (final entry in grouped.entries)
      if (entry.value.length == 1) entry.key: entry.value.first,
  };
}
