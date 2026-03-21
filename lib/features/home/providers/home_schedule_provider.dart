import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/models.dart' as api;
import '../../../core/database/app_state_keys.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/providers/providers.dart';

class TodayScheduleItem {
  const TodayScheduleItem({
    this.courseId,
    required this.courseName,
    required this.startTime,
    required this.endTime,
    required this.location,
  });

  final String? courseId;
  final String courseName;
  final String startTime;
  final String endTime;
  final String location;

  String get timeLabel {
    if (startTime.isEmpty && endTime.isEmpty) {
      return '时间待定';
    }
    if (endTime.isEmpty) {
      return startTime;
    }
    return '$startTime-$endTime';
  }
}

class HomeScheduleDayOption {
  const HomeScheduleDayOption({
    required this.date,
    required this.label,
    required this.weekdayLabel,
    required this.shortDateLabel,
    required this.isToday,
  });

  final DateTime date;
  final String label;
  final String weekdayLabel;
  final String shortDateLabel;
  final bool isToday;

  String get dateKey => DateFormat('yyyy-MM-dd').format(date);
}

class HomeScheduleSnapshot {
  const HomeScheduleSnapshot({
    required this.days,
    required this.itemsByDateKey,
  });

  final List<HomeScheduleDayOption> days;
  final Map<String, List<TodayScheduleItem>> itemsByDateKey;

  List<TodayScheduleItem> itemsFor(HomeScheduleDayOption day) {
    return itemsByDateKey[day.dateKey] ?? const <TodayScheduleItem>[];
  }
}

class _ParsedCourseMeeting {
  const _ParsedCourseMeeting({
    required this.dayOfWeek,
    required this.periods,
    required this.location,
    required this.activeWeeks,
    required this.usesTeachingBlockClock,
  });

  final int dayOfWeek;
  final List<int> periods;
  final String location;
  final Set<int>? activeWeeks;
  final bool usesTeachingBlockClock;

  bool matchesWeek(int weekNumber) {
    final weeks = activeWeeks;
    return weeks == null || weeks.contains(weekNumber);
  }
}

class _ScheduledOccurrence {
  const _ScheduledOccurrence({
    required this.courseId,
    required this.courseName,
    required this.location,
    required this.startPeriod,
    required this.endPeriod,
    required this.usesTeachingBlockClock,
  });

  final String courseId;
  final String courseName;
  final String location;
  final int startPeriod;
  final int endPeriod;
  final bool usesTeachingBlockClock;
}

final homeSchedulePageIndexProvider = StateProvider<int>((ref) => 0);

final homeScheduleVisibleDaysProvider = Provider<List<HomeScheduleDayOption>>((
  ref,
) {
  return buildHomeScheduleDays(_shanghaiToday());
});

final homeScheduleCurrentDayProvider = Provider<HomeScheduleDayOption>((ref) {
  final days = ref.watch(homeScheduleVisibleDaysProvider);
  final pageIndex = ref.watch(homeSchedulePageIndexProvider);
  final resolvedIndex = pageIndex.clamp(0, days.length - 1);
  return days[resolvedIndex];
});

final homeScheduleSnapshotProvider = StreamProvider<HomeScheduleSnapshot>((
  ref,
) {
  final authState = ref.watch(authProvider);
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  final days = ref.watch(homeScheduleVisibleDaysProvider);

  if (semesterId == null || !authState.canAccessCachedData) {
    return Stream.value(_emptyScheduleSnapshot(days));
  }

  return database.watchCoursesBySemester(semesterId).asyncExpand((
    courses,
  ) async* {
    final cachedSnapshotFuture = _readCachedHomeScheduleSnapshot(
      database: database,
      semesterId: semesterId,
      days: days,
    );
    final localSnapshotFuture = _buildCachedScheduleSnapshot(
      database: database,
      semesterId: semesterId,
      days: days,
      courses: courses,
    );
    HomeScheduleSnapshot? emittedSnapshot;

    final cachedSnapshot = await cachedSnapshotFuture;
    if (cachedSnapshot != null && _hasAnyScheduleItems(cachedSnapshot)) {
      emittedSnapshot = cachedSnapshot;
      yield cachedSnapshot;
    }

    final localSnapshot = await localSnapshotFuture;
    if (emittedSnapshot == null ||
        (!_hasAnyScheduleItems(emittedSnapshot) &&
            _hasAnyScheduleItems(localSnapshot))) {
      emittedSnapshot = localSnapshot;
      yield localSnapshot;
    }

    if (!authState.isLoggedIn) {
      return;
    }

    try {
      final events = await ref
          .read(apiClientProvider)
          .getCalendar(days.first.dateKey, days.last.dateKey);
      final remoteSnapshot = buildHomeScheduleSnapshotFromCalendarEvents(
        days: days,
        events: events,
        courseIdsByName: _uniqueCourseIdsByName(courses),
      );
      await _persistHomeScheduleSnapshot(
        database: database,
        semesterId: semesterId,
        snapshot: remoteSnapshot,
      );
      if (!_scheduleSnapshotsEqual(remoteSnapshot, emittedSnapshot)) {
        yield remoteSnapshot;
      }
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to load home schedule snapshot from registrar: '
        '$error\n$stackTrace',
      );
    }
  });
});

String buildHomeScheduleSectionTitle() => '今日课程';

String buildHomeScheduleEmptyLabel(HomeScheduleDayOption day) {
  if (day.isToday) {
    return '今天没有课';
  }
  return '${DateFormat('M月d日').format(day.date)} 没有课';
}

@visibleForTesting
List<HomeScheduleDayOption> buildHomeScheduleDays(
  DateTime startDay, {
  int length = 6,
}) {
  final today = DateTime(startDay.year, startDay.month, startDay.day);
  return List<HomeScheduleDayOption>.generate(length, (index) {
    final date = today.add(Duration(days: index));
    return HomeScheduleDayOption(
      date: date,
      label: _buildDayLabel(date, today: today),
      weekdayLabel: _weekdayLabel(date),
      shortDateLabel: DateFormat('M/d').format(date),
      isToday: _isSameDay(date, today),
    );
  });
}

@visibleForTesting
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
  }

  return HomeScheduleSnapshot(days: days, itemsByDateKey: grouped);
}

@visibleForTesting
HomeScheduleSnapshot buildHomeScheduleSnapshotFromCachedCourses({
  required List<HomeScheduleDayOption> days,
  required List<db.Course> courses,
  required String semesterStartDate,
}) {
  final semesterStart = _parseDateOnly(semesterStartDate);
  if (semesterStart == null) {
    return _emptyScheduleSnapshot(days);
  }

  final occurrencesByDateKey = <String, List<_ScheduledOccurrence>>{
    for (final day in days) day.dateKey: <_ScheduledOccurrence>[],
  };

  for (final course in courses) {
    final meetings = _decodeCourseMeetings(course.timeAndLocationJson);
    if (meetings.isEmpty) {
      continue;
    }

    for (final day in days) {
      final dayOffset = day.date.difference(semesterStart).inDays;
      if (dayOffset < 0) {
        continue;
      }

      final weekNumber = (dayOffset ~/ 7) + 1;
      final dayOccurrences = occurrencesByDateKey[day.dateKey]!;

      for (final meeting in meetings) {
        if (meeting.dayOfWeek != day.date.weekday ||
            !meeting.matchesWeek(weekNumber)) {
          continue;
        }

        for (final run in _collapseConsecutivePeriods(meeting.periods)) {
          dayOccurrences.add(
            _ScheduledOccurrence(
              courseId: course.id,
              courseName: course.name,
              location: meeting.location,
              startPeriod: run.$1,
              endPeriod: run.$2,
              usesTeachingBlockClock: meeting.usesTeachingBlockClock,
            ),
          );
        }
      }
    }
  }

  final itemsByDateKey = <String, List<TodayScheduleItem>>{};
  for (final entry in occurrencesByDateKey.entries) {
    final merged = _mergeOccurrences(entry.value);
    itemsByDateKey[entry.key] = merged.map(_mapOccurrenceToItem).toList();
  }

  return HomeScheduleSnapshot(days: days, itemsByDateKey: itemsByDateKey);
}

Future<HomeScheduleSnapshot> _buildCachedScheduleSnapshot({
  required db.AppDatabase database,
  required String semesterId,
  required List<HomeScheduleDayOption> days,
  required List<db.Course> courses,
}) async {
  final semester = await database.getSemesterById(semesterId);
  if (semester == null) {
    return _emptyScheduleSnapshot(days);
  }

  return buildHomeScheduleSnapshotFromCachedCourses(
    days: days,
    courses: courses,
    semesterStartDate: semester.startDate,
  );
}

HomeScheduleSnapshot _emptyScheduleSnapshot(List<HomeScheduleDayOption> days) {
  return HomeScheduleSnapshot(
    days: days,
    itemsByDateKey: {
      for (final day in days) day.dateKey: const <TodayScheduleItem>[],
    },
  );
}

const int _homeScheduleCacheVersion = 1;

Future<void> _persistHomeScheduleSnapshot({
  required db.AppDatabase database,
  required String semesterId,
  required HomeScheduleSnapshot snapshot,
}) {
  return database.setState(
    AppStateKeys.homeScheduleSnapshot,
    encodeHomeScheduleSnapshotCachePayload(
      semesterId: semesterId,
      snapshot: snapshot,
    ),
  );
}

Future<HomeScheduleSnapshot?> _readCachedHomeScheduleSnapshot({
  required db.AppDatabase database,
  required String semesterId,
  required List<HomeScheduleDayOption> days,
}) async {
  final raw = await database.getState(AppStateKeys.homeScheduleSnapshot);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return decodeHomeScheduleSnapshotCachePayload(
    semesterId: semesterId,
    days: days,
    raw: raw,
  );
}

@visibleForTesting
String encodeHomeScheduleSnapshotCachePayload({
  required String semesterId,
  required HomeScheduleSnapshot snapshot,
}) {
  return jsonEncode({
    'version': _homeScheduleCacheVersion,
    'semesterId': semesterId,
    'days': snapshot.days.map((day) => day.dateKey).toList(growable: false),
    'itemsByDateKey': {
      for (final entry in snapshot.itemsByDateKey.entries)
        entry.key: entry.value
            .map(
              (item) => {
                'courseId': item.courseId,
                'courseName': item.courseName,
                'startTime': item.startTime,
                'endTime': item.endTime,
                'location': item.location,
              },
            )
            .toList(growable: false),
    },
  });
}

@visibleForTesting
HomeScheduleSnapshot? decodeHomeScheduleSnapshotCachePayload({
  required String semesterId,
  required List<HomeScheduleDayOption> days,
  required String raw,
}) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    if (decoded['version'] != _homeScheduleCacheVersion ||
        decoded['semesterId'] != semesterId) {
      return null;
    }

    final cachedDays = (decoded['days'] as List?)?.whereType<String>().toList();
    final dayKeys = days.map((day) => day.dateKey).toList(growable: false);
    if (cachedDays == null ||
        cachedDays.length != dayKeys.length ||
        !_stringListsEqual(cachedDays, dayKeys)) {
      return null;
    }

    final rawItemsByDateKey = decoded['itemsByDateKey'];
    if (rawItemsByDateKey is! Map) {
      return null;
    }

    final itemsByDateKey = <String, List<TodayScheduleItem>>{};
    for (final day in days) {
      final rawItems = rawItemsByDateKey[day.dateKey];
      if (rawItems is! List) {
        itemsByDateKey[day.dateKey] = const <TodayScheduleItem>[];
        continue;
      }

      itemsByDateKey[day.dateKey] = rawItems
          .whereType<Map>()
          .map(
            (item) => TodayScheduleItem(
              courseId: item['courseId'] as String?,
              courseName: item['courseName']?.toString() ?? '',
              startTime: item['startTime']?.toString() ?? '',
              endTime: item['endTime']?.toString() ?? '',
              location: item['location']?.toString() ?? '',
            ),
          )
          .toList(growable: false);
    }

    return HomeScheduleSnapshot(days: days, itemsByDateKey: itemsByDateKey);
  } catch (_) {
    return null;
  }
}

bool _hasAnyScheduleItems(HomeScheduleSnapshot snapshot) {
  return snapshot.itemsByDateKey.values.any((items) => items.isNotEmpty);
}

bool _scheduleSnapshotsEqual(
  HomeScheduleSnapshot left,
  HomeScheduleSnapshot right,
) {
  if (left.itemsByDateKey.length != right.itemsByDateKey.length) {
    return false;
  }

  for (final entry in left.itemsByDateKey.entries) {
    final otherItems = right.itemsByDateKey[entry.key];
    final items = entry.value;
    if (otherItems == null || otherItems.length != items.length) {
      return false;
    }

    for (var index = 0; index < items.length; index += 1) {
      final a = items[index];
      final b = otherItems[index];
      if (a.courseId != b.courseId ||
          a.courseName != b.courseName ||
          a.startTime != b.startTime ||
          a.endTime != b.endTime ||
          a.location != b.location) {
        return false;
      }
    }
  }

  return true;
}

bool _stringListsEqual(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

List<_ParsedCourseMeeting> _decodeCourseMeetings(String rawJson) {
  if (rawJson.trim().isEmpty) {
    return const <_ParsedCourseMeeting>[];
  }

  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const <_ParsedCourseMeeting>[];
    }

    final meetings = <_ParsedCourseMeeting>[];
    for (final entry in decoded) {
      final parsed = _parseCourseMeeting(entry?.toString() ?? '');
      if (parsed != null) {
        meetings.add(parsed);
      }
    }
    return meetings;
  } catch (_) {
    return const <_ParsedCourseMeeting>[];
  }
}

_ParsedCourseMeeting? _parseCourseMeeting(String raw) {
  final value = raw.replaceAll(RegExp(r'\s+'), '').trim();
  if (value.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^星期([一二三四五六日天])第([^节]+)节\(([^)]*)\)(?:[，,](.*))?$',
  ).firstMatch(value);
  if (match == null) {
    return null;
  }

  final dayOfWeek = _parseChineseWeekday(match.group(1)!);
  final periods = _parsePeriods(match.group(2)!);
  final weeks = _parseWeeks(match.group(3)!);
  final location = (match.group(4) ?? '').trim();

  if (dayOfWeek == null || periods.isEmpty || weeks.isEmpty) {
    return null;
  }

  return _ParsedCourseMeeting(
    dayOfWeek: dayOfWeek,
    periods: periods,
    location: location,
    activeWeeks: weeks.length >= 30 ? null : weeks,
    usesTeachingBlockClock: true,
  );
}

int? _parseChineseWeekday(String raw) {
  return switch (raw) {
    '一' => 1,
    '二' => 2,
    '三' => 3,
    '四' => 4,
    '五' => 5,
    '六' => 6,
    '日' || '天' => 7,
    _ => null,
  };
}

List<int> _parsePeriods(String raw) {
  final periods = <int>{};
  for (final token in raw.split(RegExp(r'[，,、]'))) {
    final value = token.trim();
    if (value.isEmpty) {
      continue;
    }

    final rangeMatch = RegExp(r'^(\d+)-(\d+)$').firstMatch(value);
    if (rangeMatch != null) {
      final start = int.parse(rangeMatch.group(1)!);
      final end = int.parse(rangeMatch.group(2)!);
      for (var period = start; period <= end; period += 1) {
        if (period >= 1 && period <= 14) {
          periods.add(period);
        }
      }
      continue;
    }

    final single = int.tryParse(value);
    if (single != null && single >= 1 && single <= 14) {
      periods.add(single);
    }
  }

  final sorted = periods.toList()..sort();
  return sorted;
}

Set<int> _parseWeeks(String raw) {
  final value = raw.replaceAll(' ', '');
  final oddOnly = value.contains('单');
  final evenOnly = value.contains('双');
  final isAllWeeks = value.contains('全周');

  final weeks = <int>{};
  if (isAllWeeks || (value.isEmpty && !oddOnly && !evenOnly)) {
    weeks.addAll(_fullWeekSet());
  }

  for (final token
      in value
          .replaceAll('全周', '')
          .replaceAll('单周', '')
          .replaceAll('双周', '')
          .split(RegExp(r'[，,、]'))) {
    final cleaned = token.trim();
    if (cleaned.isEmpty) {
      continue;
    }

    final rangeMatch = RegExp(r'^(\d+)-(\d+)(?:周)?$').firstMatch(cleaned);
    if (rangeMatch != null) {
      final start = int.parse(rangeMatch.group(1)!);
      final end = int.parse(rangeMatch.group(2)!);
      for (var week = start; week <= end; week += 1) {
        weeks.add(week);
      }
      continue;
    }

    final singleMatch = RegExp(r'^(\d+)(?:周)?$').firstMatch(cleaned);
    if (singleMatch != null) {
      weeks.add(int.parse(singleMatch.group(1)!));
    }
  }

  if (weeks.isEmpty && (oddOnly || evenOnly)) {
    weeks.addAll(_fullWeekSet());
  }

  if (oddOnly) {
    weeks.removeWhere((week) => week.isEven);
  }
  if (evenOnly) {
    weeks.removeWhere((week) => week.isOdd);
  }

  return weeks;
}

Set<int> _fullWeekSet() => {for (var week = 1; week <= 30; week += 1) week};

List<(int, int)> _collapseConsecutivePeriods(List<int> periods) {
  if (periods.isEmpty) {
    return const <(int, int)>[];
  }

  final runs = <(int, int)>[];
  var start = periods.first;
  var end = periods.first;

  for (final period in periods.skip(1)) {
    if (period == end + 1) {
      end = period;
      continue;
    }
    runs.add((start, end));
    start = period;
    end = period;
  }

  runs.add((start, end));
  return runs;
}

List<_ScheduledOccurrence> _mergeOccurrences(
  List<_ScheduledOccurrence> occurrences,
) {
  if (occurrences.isEmpty) {
    return const <_ScheduledOccurrence>[];
  }

  final sorted = [...occurrences]
    ..sort((left, right) {
      final byStart = left.startPeriod.compareTo(right.startPeriod);
      if (byStart != 0) {
        return byStart;
      }
      final byCourse = left.courseName.compareTo(right.courseName);
      if (byCourse != 0) {
        return byCourse;
      }
      final byCourseId = left.courseId.compareTo(right.courseId);
      if (byCourseId != 0) {
        return byCourseId;
      }
      return left.location.compareTo(right.location);
    });

  final merged = <_ScheduledOccurrence>[];
  var current = sorted.first;

  for (final next in sorted.skip(1)) {
    if (next.courseName == current.courseName &&
        next.courseId == current.courseId &&
        next.location == current.location &&
        next.startPeriod <= current.endPeriod + 1) {
      current = _ScheduledOccurrence(
        courseId: current.courseId,
        courseName: current.courseName,
        location: current.location,
        startPeriod: current.startPeriod,
        endPeriod: next.endPeriod > current.endPeriod
            ? next.endPeriod
            : current.endPeriod,
        usesTeachingBlockClock: current.usesTeachingBlockClock,
      );
      continue;
    }

    merged.add(current);
    current = next;
  }

  merged.add(current);
  return merged;
}

TodayScheduleItem _mapOccurrenceToItem(_ScheduledOccurrence occurrence) {
  return TodayScheduleItem(
    courseId: occurrence.courseId,
    courseName: occurrence.courseName,
    startTime: _periodStartTime(
      occurrence.startPeriod,
      usesTeachingBlockClock: occurrence.usesTeachingBlockClock,
    ),
    endTime: _periodEndTime(
      occurrence.endPeriod,
      usesTeachingBlockClock: occurrence.usesTeachingBlockClock,
    ),
    location: occurrence.location,
  );
}

String _periodStartTime(int period, {required bool usesTeachingBlockClock}) {
  if (usesTeachingBlockClock) {
    const teachingBlockStartTimes = <int, String>{
      1: '08:00',
      2: '09:50',
      3: '13:30',
      4: '15:20',
      5: '17:05',
      6: '19:20',
    };
    return teachingBlockStartTimes[period] ?? '';
  }

  const startTimes = <int, String>{
    1: '08:00',
    2: '08:50',
    3: '09:50',
    4: '10:40',
    5: '11:30',
    6: '13:30',
    7: '14:20',
    8: '15:20',
    9: '16:10',
    10: '17:05',
    11: '17:55',
    12: '19:20',
    13: '20:10',
    14: '21:00',
  };
  return startTimes[period] ?? '';
}

String _periodEndTime(int period, {required bool usesTeachingBlockClock}) {
  if (usesTeachingBlockClock) {
    const teachingBlockEndTimes = <int, String>{
      1: '09:35',
      2: '11:25',
      3: '15:05',
      4: '16:55',
      5: '18:40',
      6: '20:55',
    };
    return teachingBlockEndTimes[period] ?? '';
  }

  const endTimes = <int, String>{
    1: '08:45',
    2: '09:35',
    3: '10:35',
    4: '11:25',
    5: '12:15',
    6: '14:15',
    7: '15:05',
    8: '16:05',
    9: '16:55',
    10: '17:50',
    11: '18:40',
    12: '20:05',
    13: '20:55',
    14: '21:45',
  };
  return endTimes[period] ?? '';
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

DateTime _shanghaiToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return DateTime(now.year, now.month, now.day);
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

Map<String, String> _uniqueCourseIdsByName(List<db.Course> courses) {
  final grouped = <String, Set<String>>{};
  for (final course in courses) {
    final name = course.name.trim();
    if (name.isEmpty) {
      continue;
    }
    grouped.putIfAbsent(name, () => <String>{}).add(course.id);
  }

  return {
    for (final entry in grouped.entries)
      if (entry.value.length == 1) entry.key: entry.value.first,
  };
}
