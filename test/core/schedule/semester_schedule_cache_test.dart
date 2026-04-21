import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/schedule/semester_schedule_cache.dart';

void main() {
  group('semester schedule cache', () {
    test('round-trips a normalized semester schedule payload', () {
      final cache = buildSemesterScheduleCacheFromCourses(
        semesterId: 'semester-1',
        semesterStartDate: '2026-03-16',
        courses: [
          _course(
            name: 'Molecular Biology',
            chineseName: '分子生物学',
            timeAndLocation: ['Section 1 of Tues (Week all ), 六教6B207'],
          ),
          _course(
            name: '土力学',
            chineseName: '土力学',
            timeAndLocation: ['星期五第2节(全周)，三教3101'],
          ),
        ],
      );

      final payload = encodeSemesterScheduleCachePayload(cache);
      final decoded = decodeSemesterScheduleCachePayload(
        semesterId: 'semester-1',
        raw: payload,
      );

      expect(decoded, isNotNull);
      expect(decoded!.courses, hasLength(2));
      expect(decoded.courses.first.courseName, '分子生物学');
      expect(decoded.courses.first.meetings.first.periods, [1]);
    });

    test('resolves visible dates from cached semester schedule', () {
      final cache = buildSemesterScheduleCacheFromCourses(
        semesterId: 'semester-1',
        semesterStartDate: '2026-03-16',
        courses: [
          _course(
            name: 'Molecular Biology',
            chineseName: '分子生物学',
            timeAndLocation: ['Section 1 of Tues (Week all ), 六教6B207'],
          ),
          _course(
            name: '工业系统概论',
            chineseName: '工业系统概论',
            timeAndLocation: ['星期二第2节(1-12周)，李兆基科技大楼B148'],
          ),
        ],
      );

      final itemsByDateKey = resolveSemesterScheduleItemsByDateKey(
        cache: cache,
        dates: [DateTime(2026, 4, 21)],
      );

      expect(itemsByDateKey['2026-04-21'], hasLength(2));
      expect(
        itemsByDateKey['2026-04-21']!.map((item) => item.courseName).toList(),
        ['分子生物学', '工业系统概论'],
      );
      expect(
        itemsByDateKey['2026-04-21']!.map((item) => item.startTime).toList(),
        ['08:00', '09:50'],
      );
    });
  });
}

db.Course _course({
  required String name,
  required String chineseName,
  required List<String> timeAndLocation,
}) {
  return db.Course(
    id: '${name}_id',
    name: name,
    chineseName: chineseName,
    englishName: name,
    teacherName: '',
    teacherNumber: '',
    courseNumber: '',
    courseIndex: 0,
    courseType: 'student',
    semesterId: 'semester-1',
    timeAndLocationJson: jsonEncode(timeAndLocation),
    sortOrder: 0,
    lastSynced: null,
  );
}
