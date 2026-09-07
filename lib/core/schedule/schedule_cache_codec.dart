import 'dart:convert';

import 'package:flutter/foundation.dart' show listEquals;

import 'schedule_models.dart';

const int _homeScheduleCacheVersion = 2;
const int _homeScheduleRemoteRefreshStateVersion = 1;
String encodeHomeScheduleRemoteRefreshPayload(
  HomeScheduleRemoteRefreshState state,
) {
  return jsonEncode({
    'version': _homeScheduleRemoteRefreshStateVersion,
    'semesterId': state.semesterId,
    'lastAttemptAt': state.lastAttemptAt.millisecondsSinceEpoch,
    'hasSuccessfulRefresh': state.hasSuccessfulRefresh,
    'failure': state.failure?.name,
  });
}

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
      failure: ScheduleFailure.values
          .where((value) => value.name == decoded['failure'])
          .firstOrNull,
    );
  } catch (_) {
    return null;
  }
}

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
                'source': item.source.name,
                'endTimeInferred': item.endTimeInferred,
                'periodLabel': item.periodLabel,
              },
            )
            .toList(growable: false),
    },
  });
}

HomeScheduleSnapshot? decodeHomeScheduleSnapshotCachePayload({
  String? semesterId,
  required List<HomeScheduleDayOption> days,
  required String raw,
}) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    if ((decoded['version'] != 1 &&
            decoded['version'] != _homeScheduleCacheVersion) ||
        (semesterId != null && decoded['semesterId'] != semesterId)) {
      return null;
    }

    final cachedDays = (decoded['days'] as List?)?.whereType<String>().toList();
    final dayKeys = days.map((day) => day.dateKey).toList(growable: false);
    if (cachedDays == null ||
        cachedDays.length != dayKeys.length ||
        !listEquals(cachedDays, dayKeys)) {
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
              source:
                  ScheduleItemSource.values
                      .where((source) => source.name == item['source'])
                      .firstOrNull ??
                  ScheduleItemSource.legacy,
              endTimeInferred: item['endTimeInferred'] == true,
              periodLabel: item['periodLabel']?.toString() ?? '',
            ),
          )
          .toList(growable: false);
    }

    return HomeScheduleSnapshot(days: days, itemsByDateKey: itemsByDateKey);
  } catch (_) {
    return null;
  }
}
