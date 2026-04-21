import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/api/models.dart' as api;
import '../../../core/database/app_state_keys.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/providers/providers.dart';
import '../../../core/schedule/semester_schedule_cache.dart' as schedule_cache;

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

class HomeScheduleRemoteRefreshState {
  const HomeScheduleRemoteRefreshState({
    required this.semesterId,
    required this.lastAttemptAt,
    required this.hasSuccessfulRefresh,
  });

  final String semesterId;
  final DateTime lastAttemptAt;
  final bool hasSuccessfulRefresh;
}

class _CachedScheduleArtifacts {
  const _CachedScheduleArtifacts({required this.snapshot, required this.cache});

  final HomeScheduleSnapshot snapshot;
  final schedule_cache.SemesterScheduleCache? cache;
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
    final cachedSemesterSnapshotFuture = _readCachedSemesterScheduleSnapshot(
      database: database,
      semesterId: semesterId,
      days: days,
    );
    final localArtifactsFuture = _buildCachedScheduleArtifacts(
      database: database,
      semesterId: semesterId,
      days: days,
      courses: courses,
    );
    HomeScheduleSnapshot? emittedSnapshot;

    final cachedSnapshot = await cachedSnapshotFuture;
    final cachedSemesterSnapshot = await cachedSemesterSnapshotFuture;
    final persistedSnapshot = _mergePersistedScheduleSnapshots(
      cachedSnapshot: cachedSnapshot,
      semesterSnapshot: cachedSemesterSnapshot,
    );
    if (persistedSnapshot != null && _hasAnyScheduleItems(persistedSnapshot)) {
      emittedSnapshot = persistedSnapshot;
      yield persistedSnapshot;
    }

    final localArtifacts = await localArtifactsFuture;
    final localCache = localArtifacts.cache;
    if (localCache != null && localCache.hasAnyMeetings) {
      await _persistSemesterScheduleCache(
        database: database,
        cache: localCache,
      );
    }
    final localSnapshot = _mergeLocalScheduleSnapshot(
      currentSnapshot: localArtifacts.snapshot,
      semesterSnapshot: cachedSemesterSnapshot,
    );
    if (_hasAnyScheduleItems(localSnapshot) &&
        (emittedSnapshot == null ||
            !_scheduleSnapshotsEqual(localSnapshot, emittedSnapshot))) {
      emittedSnapshot = localSnapshot;
      yield localSnapshot;
    }

    if (!authState.isLoggedIn) {
      return;
    }

    final remoteRefreshState = await readHomeScheduleRemoteRefreshState(
      database: database,
    );
    if (!shouldFetchHomeScheduleRemoteSnapshot(
      semesterId: semesterId,
      cachedSnapshot: cachedSnapshot,
      localSnapshot: localSnapshot,
      semesterSnapshot: cachedSemesterSnapshot,
      refreshState: remoteRefreshState,
      now: DateTime.now(),
    )) {
      return;
    }

    await persistHomeScheduleRemoteRefreshState(
      database: database,
      state: HomeScheduleRemoteRefreshState(
        semesterId: semesterId,
        lastAttemptAt: DateTime.now(),
        hasSuccessfulRefresh: false,
      ),
    );

    try {
      final events = await ref
          .read(apiClientProvider)
          .getCalendar(days.first.dateKey, days.last.dateKey);
      final remoteSnapshot = buildHomeScheduleSnapshotFromCalendarEvents(
        days: days,
        events: events,
        courseIdsByName: _uniqueCourseIdsByName(courses),
      );
      final mergedSnapshot = mergeHomeScheduleSnapshots(
        primary: remoteSnapshot,
        fallback: localSnapshot,
      );
      await _persistHomeScheduleSnapshot(
        database: database,
        semesterId: semesterId,
        snapshot: mergedSnapshot,
      );
      await persistHomeScheduleRemoteRefreshState(
        database: database,
        state: HomeScheduleRemoteRefreshState(
          semesterId: semesterId,
          lastAttemptAt: DateTime.now(),
          hasSuccessfulRefresh: true,
        ),
      );
      if (emittedSnapshot == null ||
          !_scheduleSnapshotsEqual(mergedSnapshot, emittedSnapshot)) {
        yield mergedSnapshot;
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
    grouped[entry.key] = _mergeAdjacentScheduleItems(entry.value);
  }

  return HomeScheduleSnapshot(days: days, itemsByDateKey: grouped);
}

@visibleForTesting
HomeScheduleSnapshot buildHomeScheduleSnapshotFromCachedCourses({
  required List<HomeScheduleDayOption> days,
  required List<db.Course> courses,
  required String semesterStartDate,
}) {
  final cache = schedule_cache.buildSemesterScheduleCacheFromCourses(
    semesterId: '',
    semesterStartDate: semesterStartDate,
    courses: courses,
  );
  return buildHomeScheduleSnapshotFromSemesterScheduleCache(
    days: days,
    cache: cache,
  );
}

@visibleForTesting
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
}) {
  final resolved = schedule_cache.resolveSemesterScheduleItemsByDateKey(
    cache: cache,
    dates: days.map((day) => day.date).toList(growable: false),
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

Future<_CachedScheduleArtifacts> _buildCachedScheduleArtifacts({
  required db.AppDatabase database,
  required String semesterId,
  required List<HomeScheduleDayOption> days,
  required List<db.Course> courses,
}) async {
  final semester = await database.getSemesterById(semesterId);
  if (semester == null) {
    return _CachedScheduleArtifacts(
      snapshot: _emptyScheduleSnapshot(days),
      cache: null,
    );
  }

  final cache = schedule_cache.buildSemesterScheduleCacheFromCourses(
    semesterId: semesterId,
    semesterStartDate: semester.startDate,
    courses: courses,
  );
  return _CachedScheduleArtifacts(
    snapshot: buildHomeScheduleSnapshotFromSemesterScheduleCache(
      days: days,
      cache: cache,
    ),
    cache: cache,
  );
}

Future<void> _persistSemesterScheduleCache({
  required db.AppDatabase database,
  required schedule_cache.SemesterScheduleCache cache,
}) async {
  if (!cache.hasAnyMeetings) {
    return;
  }
  final key = AppStateKeys.homeScheduleSemesterCache(cache.semesterId);
  final payload = schedule_cache.encodeSemesterScheduleCachePayload(cache);
  final existing = await database.getState(key);
  if (existing == payload) {
    return;
  }
  await database.setState(key, payload);
}

Future<HomeScheduleSnapshot?> _readCachedSemesterScheduleSnapshot({
  required db.AppDatabase database,
  required String semesterId,
  required List<HomeScheduleDayOption> days,
}) async {
  final raw = await database.getState(
    AppStateKeys.homeScheduleSemesterCache(semesterId),
  );
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final cache = schedule_cache.decodeSemesterScheduleCachePayload(
    semesterId: semesterId,
    raw: raw,
  );
  if (cache == null) {
    return null;
  }
  return buildHomeScheduleSnapshotFromSemesterScheduleCache(
    days: days,
    cache: cache,
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
const int _homeScheduleRemoteRefreshStateVersion = 1;
const Duration _homeScheduleRemoteRefreshInterval = Duration(hours: 12);
const Duration _homeScheduleRemoteRetryBackoff = Duration(hours: 2);

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

Future<void> persistHomeScheduleRemoteRefreshState({
  required db.AppDatabase database,
  required HomeScheduleRemoteRefreshState state,
}) {
  return database.setState(
    AppStateKeys.homeScheduleRemoteRefreshState,
    encodeHomeScheduleRemoteRefreshPayload(state),
  );
}

Future<HomeScheduleRemoteRefreshState?> readHomeScheduleRemoteRefreshState({
  required db.AppDatabase database,
}) async {
  final raw = await database.getState(
    AppStateKeys.homeScheduleRemoteRefreshState,
  );
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return decodeHomeScheduleRemoteRefreshPayload(raw);
}

Future<void> resetHomeScheduleRemoteRefreshState({
  required db.AppDatabase database,
}) {
  return database.deleteState(AppStateKeys.homeScheduleRemoteRefreshState);
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
String encodeHomeScheduleRemoteRefreshPayload(
  HomeScheduleRemoteRefreshState state,
) {
  return jsonEncode({
    'version': _homeScheduleRemoteRefreshStateVersion,
    'semesterId': state.semesterId,
    'lastAttemptAt': state.lastAttemptAt.millisecondsSinceEpoch,
    'hasSuccessfulRefresh': state.hasSuccessfulRefresh,
  });
}

@visibleForTesting
HomeScheduleRemoteRefreshState? decodeHomeScheduleRemoteRefreshPayload(
  String raw,
) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    if (decoded['version'] != _homeScheduleRemoteRefreshStateVersion) {
      return null;
    }
    final semesterId = decoded['semesterId']?.toString() ?? '';
    final lastAttemptAtMs = decoded['lastAttemptAt'] as int?;
    final hasSuccessfulRefresh = decoded['hasSuccessfulRefresh'] == true;
    if (semesterId.isEmpty || lastAttemptAtMs == null) {
      return null;
    }
    return HomeScheduleRemoteRefreshState(
      semesterId: semesterId,
      lastAttemptAt: DateTime.fromMillisecondsSinceEpoch(lastAttemptAtMs),
      hasSuccessfulRefresh: hasSuccessfulRefresh,
    );
  } catch (_) {
    return null;
  }
}

@visibleForTesting
bool shouldFetchHomeScheduleRemoteSnapshot({
  required String semesterId,
  required HomeScheduleSnapshot? cachedSnapshot,
  required HomeScheduleSnapshot localSnapshot,
  HomeScheduleSnapshot? semesterSnapshot,
  required HomeScheduleRemoteRefreshState? refreshState,
  required DateTime now,
}) {
  final hasAnyData =
      (cachedSnapshot != null && _hasAnyScheduleItems(cachedSnapshot)) ||
      _hasAnyScheduleItems(localSnapshot) ||
      (semesterSnapshot != null && _hasAnyScheduleItems(semesterSnapshot));

  if (refreshState == null || refreshState.semesterId != semesterId) {
    return true;
  }
  if (refreshState.hasSuccessfulRefresh) {
    return now.difference(refreshState.lastAttemptAt) >=
        _homeScheduleRemoteRefreshInterval;
  }
  if (!hasAnyData) {
    return true;
  }
  return now.difference(refreshState.lastAttemptAt) >=
      _homeScheduleRemoteRetryBackoff;
}

HomeScheduleSnapshot? _mergePersistedScheduleSnapshots({
  required HomeScheduleSnapshot? cachedSnapshot,
  required HomeScheduleSnapshot? semesterSnapshot,
}) {
  final hasCached =
      cachedSnapshot != null && _hasAnyScheduleItems(cachedSnapshot);
  final hasSemester =
      semesterSnapshot != null && _hasAnyScheduleItems(semesterSnapshot);

  if (hasCached && hasSemester) {
    return mergeHomeScheduleSnapshots(
      primary: cachedSnapshot,
      fallback: semesterSnapshot,
    );
  }
  if (hasCached) {
    return cachedSnapshot;
  }
  if (hasSemester) {
    return semesterSnapshot;
  }
  return null;
}

HomeScheduleSnapshot _mergeLocalScheduleSnapshot({
  required HomeScheduleSnapshot currentSnapshot,
  required HomeScheduleSnapshot? semesterSnapshot,
}) {
  final hasCurrent = _hasAnyScheduleItems(currentSnapshot);
  final hasSemester =
      semesterSnapshot != null && _hasAnyScheduleItems(semesterSnapshot);

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
      final byCourse = _scheduleCourseSortKey(left).compareTo(
        _scheduleCourseSortKey(right),
      );
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
        location: current.location.isNotEmpty ? current.location : next.location,
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
  if (leftCourseId.isNotEmpty &&
      rightCourseId.isNotEmpty &&
      leftCourseId == rightCourseId) {
    return true;
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
