library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../database/database.dart' as db;

class SemesterScheduleCache {
  const SemesterScheduleCache({
    required this.semesterId,
    required this.semesterStartDate,
    required this.courses,
  });

  final String semesterId;
  final String semesterStartDate;
  final List<SemesterScheduleCourse> courses;

  bool get hasAnyMeetings => courses.isNotEmpty;
}

class SemesterScheduleCourse {
  const SemesterScheduleCourse({
    required this.courseId,
    required this.courseName,
    required this.meetings,
  });

  final String courseId;
  final String courseName;
  final List<SemesterScheduleMeeting> meetings;
}

class SemesterScheduleMeeting {
  const SemesterScheduleMeeting({
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

class ResolvedSemesterScheduleItem {
  const ResolvedSemesterScheduleItem({
    required this.courseId,
    required this.courseName,
    required this.startTime,
    required this.endTime,
    required this.location,
  });

  final String courseId;
  final String courseName;
  final String startTime;
  final String endTime;
  final String location;
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

const int _semesterScheduleCacheVersion = 1;
const int _fullWeekCount = 30;

SemesterScheduleCache buildSemesterScheduleCacheFromCourses({
  required String semesterId,
  required String semesterStartDate,
  required List<db.Course> courses,
}) {
  final cachedCourses = <SemesterScheduleCourse>[];
  for (final course in courses) {
    final meetings = _decodeCourseMeetings(course.timeAndLocationJson);
    if (meetings.isEmpty) {
      continue;
    }
    cachedCourses.add(
      SemesterScheduleCourse(
        courseId: course.id,
        courseName: preferredScheduleCourseName(course),
        meetings: meetings,
      ),
    );
  }

  return SemesterScheduleCache(
    semesterId: semesterId,
    semesterStartDate: semesterStartDate,
    courses: cachedCourses,
  );
}

@visibleForTesting
List<SemesterScheduleMeeting> decodeSemesterScheduleMeetingsForTesting(
  String rawJson,
) {
  return _decodeCourseMeetings(rawJson);
}

String encodeSemesterScheduleCachePayload(SemesterScheduleCache cache) {
  return jsonEncode({
    'version': _semesterScheduleCacheVersion,
    'semesterId': cache.semesterId,
    'semesterStartDate': cache.semesterStartDate,
    'courses': [
      for (final course in cache.courses)
        {
          'courseId': course.courseId,
          'courseName': course.courseName,
          'meetings': [
            for (final meeting in course.meetings)
              {
                'dayOfWeek': meeting.dayOfWeek,
                'periods': meeting.periods,
                'location': meeting.location,
                'activeWeeks': meeting.activeWeeks == null
                    ? null
                    : (meeting.activeWeeks!.toList()..sort()),
                'usesTeachingBlockClock': meeting.usesTeachingBlockClock,
              },
          ],
        },
    ],
  });
}

SemesterScheduleCache? decodeSemesterScheduleCachePayload({
  required String semesterId,
  required String raw,
}) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    if (decoded['version'] != _semesterScheduleCacheVersion ||
        decoded['semesterId'] != semesterId) {
      return null;
    }

    final semesterStartDate = decoded['semesterStartDate']?.toString() ?? '';
    if (semesterStartDate.isEmpty) {
      return null;
    }

    final rawCourses = decoded['courses'];
    if (rawCourses is! List) {
      return null;
    }

    final courses = <SemesterScheduleCourse>[];
    for (final rawCourse in rawCourses.whereType<Map>()) {
      final courseId = rawCourse['courseId']?.toString() ?? '';
      final courseName = rawCourse['courseName']?.toString() ?? '';
      final rawMeetings = rawCourse['meetings'];
      if (courseId.isEmpty || courseName.isEmpty || rawMeetings is! List) {
        continue;
      }

      final meetings = <SemesterScheduleMeeting>[];
      for (final rawMeeting in rawMeetings.whereType<Map>()) {
        final dayOfWeek = rawMeeting['dayOfWeek'] as int?;
        final periods = (rawMeeting['periods'] as List?)
            ?.whereType<num>()
            .map((value) => value.toInt())
            .toList(growable: false);
        final rawActiveWeeks = rawMeeting['activeWeeks'] as List?;
        final activeWeeks = rawActiveWeeks
            ?.whereType<num>()
            .map((value) => value.toInt())
            .toSet();
        final location = rawMeeting['location']?.toString() ?? '';
        final usesTeachingBlockClock =
            rawMeeting['usesTeachingBlockClock'] == true;

        if (dayOfWeek == null || periods == null || periods.isEmpty) {
          continue;
        }

        meetings.add(
          SemesterScheduleMeeting(
            dayOfWeek: dayOfWeek,
            periods: periods,
            location: location,
            activeWeeks: activeWeeks,
            usesTeachingBlockClock: usesTeachingBlockClock,
          ),
        );
      }

      if (meetings.isEmpty) {
        continue;
      }

      courses.add(
        SemesterScheduleCourse(
          courseId: courseId,
          courseName: courseName,
          meetings: meetings,
        ),
      );
    }

    return SemesterScheduleCache(
      semesterId: semesterId,
      semesterStartDate: semesterStartDate,
      courses: courses,
    );
  } catch (_) {
    return null;
  }
}

Map<String, List<ResolvedSemesterScheduleItem>>
resolveSemesterScheduleItemsByDateKey({
  required SemesterScheduleCache cache,
  required List<DateTime> dates,
}) {
  final semesterStart = parseDateOnly(cache.semesterStartDate);
  if (semesterStart == null) {
    return {
      for (final date in dates)
        DateFormat('yyyy-MM-dd').format(date):
            const <ResolvedSemesterScheduleItem>[],
    };
  }

  final occurrencesByDateKey = <String, List<_ScheduledOccurrence>>{
    for (final date in dates)
      DateFormat('yyyy-MM-dd').format(date): <_ScheduledOccurrence>[],
  };

  for (final course in cache.courses) {
    for (final date in dates) {
      final dayOffset = date.difference(semesterStart).inDays;
      if (dayOffset < 0) {
        continue;
      }

      final weekNumber = (dayOffset ~/ 7) + 1;
      final dateKey = DateFormat('yyyy-MM-dd').format(date);
      final dayOccurrences = occurrencesByDateKey[dateKey]!;

      for (final meeting in course.meetings) {
        if (meeting.dayOfWeek != date.weekday ||
            !meeting.matchesWeek(weekNumber)) {
          continue;
        }

        for (final run in _collapseConsecutivePeriods(meeting.periods)) {
          dayOccurrences.add(
            _ScheduledOccurrence(
              courseId: course.courseId,
              courseName: course.courseName,
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

  final itemsByDateKey = <String, List<ResolvedSemesterScheduleItem>>{};
  for (final entry in occurrencesByDateKey.entries) {
    final merged = _mergeOccurrences(entry.value);
    itemsByDateKey[entry.key] = merged
        .map(_mapOccurrenceToResolvedItem)
        .toList(growable: false);
  }
  return itemsByDateKey;
}

String preferredScheduleCourseName(db.Course course) {
  final chineseName = course.chineseName.trim();
  if (chineseName.isNotEmpty) {
    return chineseName;
  }
  return course.name;
}

@visibleForTesting
DateTime? parseDateOnly(String raw) {
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

List<SemesterScheduleMeeting> _decodeCourseMeetings(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      return const <SemesterScheduleMeeting>[];
    }

    final meetings = <SemesterScheduleMeeting>[];
    for (final entry in decoded) {
      try {
        final parsed = _parseCourseMeeting(entry?.toString() ?? '');
        if (parsed != null) {
          meetings.add(parsed);
        }
      } catch (_) {
        // Ignore malformed entries and keep the remaining meetings.
      }
    }
    return meetings;
  } catch (_) {
    return const <SemesterScheduleMeeting>[];
  }
}

SemesterScheduleMeeting? _parseCourseMeeting(String raw) {
  final value = raw.replaceAll(RegExp(r'\s+'), '').trim();
  if (value.isEmpty) {
    return null;
  }

  final chineseMatch = RegExp(
    r'^星期([一二三四五六日天])第([^节]+)节\(([^)]*)\)(?:[，,](.*))?$',
  ).firstMatch(value);
  if (chineseMatch != null) {
    final dayOfWeek = _parseChineseWeekday(chineseMatch.group(1)!);
    final periods = _parsePeriods(chineseMatch.group(2)!);
    final weeks = _parseWeeks(chineseMatch.group(3)!);
    final location = (chineseMatch.group(4) ?? '').trim();

    if (dayOfWeek == null || periods.isEmpty || weeks.isEmpty) {
      return null;
    }

    return SemesterScheduleMeeting(
      dayOfWeek: dayOfWeek,
      periods: periods,
      location: location,
      activeWeeks: weeks.length >= _fullWeekCount ? null : weeks,
      usesTeachingBlockClock: true,
    );
  }

  final englishMatch = RegExp(
    r'^Section([^()]+)of([A-Za-z]+)\(Week([^)]*)\)(?:[，,](.*))?$',
    caseSensitive: false,
  ).firstMatch(value);
  if (englishMatch == null) {
    return null;
  }

  final dayOfWeek = _parseEnglishWeekday(englishMatch.group(2)!);
  final periods = _parsePeriods(englishMatch.group(1)!);
  final weeks = _parseWeeks(englishMatch.group(3)!);
  final location = (englishMatch.group(4) ?? '').trim();

  if (dayOfWeek == null || periods.isEmpty || weeks.isEmpty) {
    return null;
  }

  return SemesterScheduleMeeting(
    dayOfWeek: dayOfWeek,
    periods: periods,
    location: location,
    activeWeeks: weeks.length >= _fullWeekCount ? null : weeks,
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

int? _parseEnglishWeekday(String raw) {
  return switch (raw.trim().toLowerCase()) {
    'mon' || 'monday' => 1,
    'tue' || 'tues' || 'tuesday' => 2,
    'wed' || 'wednesday' => 3,
    'thu' || 'thur' || 'thurs' || 'thursday' => 4,
    'fri' || 'friday' => 5,
    'sat' || 'saturday' => 6,
    'sun' || 'sunday' => 7,
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
  final normalized = value.toLowerCase();
  final oddOnly = value.contains('单') || normalized.contains('odd');
  final evenOnly = value.contains('双') || normalized.contains('even');
  final isAllWeeks = value.contains('全周') || normalized.contains('all');

  final weeks = <int>{};
  if (isAllWeeks || (value.isEmpty && !oddOnly && !evenOnly)) {
    weeks.addAll(_fullWeekSet());
  }

  final frontHalfWeekCount = _parseChineseWeekCountDescriptor(
    value,
    prefix: '前',
  );
  if (frontHalfWeekCount != null) {
    weeks.addAll({
      for (var week = 1; week <= frontHalfWeekCount; week += 1) week,
    });
  }

  final trailingWeekStart = _parseChineseWeekCountDescriptor(
    value,
    prefix: '后',
  );
  if (trailingWeekStart != null) {
    weeks.addAll({
      for (var week = trailingWeekStart + 1; week <= _fullWeekCount; week += 1)
        week,
    });
  }

  for (final token
      in value
          .replaceAll('全周', '')
          .replaceAll('单周', '')
          .replaceAll('双周', '')
          .replaceAll(RegExp(r'前[一二三四五六七八九十两\d]+周'), '')
          .replaceAll(RegExp(r'后[一二三四五六七八九十两\d]+周'), '')
          .replaceAll(RegExp('all', caseSensitive: false), '')
          .replaceAll(RegExp('odd', caseSensitive: false), '')
          .replaceAll(RegExp('even', caseSensitive: false), '')
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

Set<int> _fullWeekSet() => {
  for (var week = 1; week <= _fullWeekCount; week += 1) week,
};

int? _parseChineseWeekCountDescriptor(String raw, {required String prefix}) {
  final match = RegExp('$prefix([一二三四五六七八九十两\\d]+)周').firstMatch(raw);
  if (match == null) {
    return null;
  }
  return _parseChineseInteger(match.group(1)!);
}

int? _parseChineseInteger(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    return null;
  }

  final arabic = int.tryParse(value);
  if (arabic != null) {
    return arabic;
  }

  const digits = <String, int>{
    '零': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };

  if (value == '十') {
    return 10;
  }
  if (value.startsWith('十')) {
    final suffix = digits[value.substring(1)];
    return suffix == null ? null : 10 + suffix;
  }
  if (value.endsWith('十')) {
    final prefixValue = digits[value.substring(0, value.length - 1)];
    return prefixValue == null ? null : prefixValue * 10;
  }

  final tenIndex = value.indexOf('十');
  if (tenIndex > 0 && tenIndex < value.length - 1) {
    final prefixValue = digits[value.substring(0, tenIndex)];
    final suffixValue = digits[value.substring(tenIndex + 1)];
    if (prefixValue == null || suffixValue == null) {
      return null;
    }
    return prefixValue * 10 + suffixValue;
  }

  return digits[value];
}

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
      final byCourse = left.courseId.compareTo(right.courseId);
      if (byCourse != 0) {
        return byCourse;
      }
      final byLocation = left.location.compareTo(right.location);
      if (byLocation != 0) {
        return byLocation;
      }
      return left.startPeriod.compareTo(right.startPeriod);
    });

  final merged = <_ScheduledOccurrence>[];
  for (final occurrence in sorted) {
    if (merged.isEmpty) {
      merged.add(occurrence);
      continue;
    }

    final last = merged.last;
    if (last.courseId == occurrence.courseId &&
        last.courseName == occurrence.courseName &&
        last.location == occurrence.location &&
        last.usesTeachingBlockClock == occurrence.usesTeachingBlockClock &&
        last.endPeriod + 1 >= occurrence.startPeriod) {
      merged[merged.length - 1] = _ScheduledOccurrence(
        courseId: last.courseId,
        courseName: last.courseName,
        location: last.location,
        startPeriod: last.startPeriod,
        endPeriod: occurrence.endPeriod > last.endPeriod
            ? occurrence.endPeriod
            : last.endPeriod,
        usesTeachingBlockClock: last.usesTeachingBlockClock,
      );
      continue;
    }

    merged.add(occurrence);
  }

  merged.sort((left, right) {
    final byStart = left.startPeriod.compareTo(right.startPeriod);
    if (byStart != 0) {
      return byStart;
    }
    final byCourse = left.courseName.compareTo(right.courseName);
    if (byCourse != 0) {
      return byCourse;
    }
    return left.location.compareTo(right.location);
  });
  return merged;
}

ResolvedSemesterScheduleItem _mapOccurrenceToResolvedItem(
  _ScheduledOccurrence occurrence,
) {
  return ResolvedSemesterScheduleItem(
    courseId: occurrence.courseId,
    courseName: occurrence.courseName,
    startTime: _startTimeForPeriod(
      occurrence.startPeriod,
      usesTeachingBlockClock: occurrence.usesTeachingBlockClock,
    ),
    endTime: _endTimeForPeriod(
      occurrence.endPeriod,
      usesTeachingBlockClock: occurrence.usesTeachingBlockClock,
    ),
    location: occurrence.location,
  );
}

String _startTimeForPeriod(int period, {required bool usesTeachingBlockClock}) {
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
    7: '14:25',
    8: '15:20',
    9: '16:10',
    10: '17:05',
    11: '17:55',
    12: '18:45',
    13: '19:20',
    14: '20:10',
  };
  return startTimes[period] ?? '';
}

String _endTimeForPeriod(int period, {required bool usesTeachingBlockClock}) {
  if (usesTeachingBlockClock) {
    const teachingBlockEndTimes = <int, String>{
      1: '09:35',
      2: '12:15',
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
