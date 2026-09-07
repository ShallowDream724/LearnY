import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/schedule/semester_schedule_cache.dart';

void main() {
  group('semester schedule cache', () {
    test(
      'preserves unassigned and unrecognized entries without inventing times',
      () {
        const raw = ['第1-16周星期 第0节，各实验单元实验室', '另行通知', '第1-16周星期二第2、待定节，'];
        final result = parseCourseSchedule(jsonEncode(raw));
        expect(result.meetings, isEmpty);
        expect(result.unresolved, raw);
      },
    );

    test(
      'recognizes bounded ranges, enumerated odd weeks and even filters',
      () {
        final result = parseCourseSchedule(
          jsonEncode([
            '第9-16周星期三第6节，',
            '第1、3、5、7、9、11、13、15周星期二第3、4节，',
            '第1-12周（双周）星期四第2节，六教',
          ]),
        );
        expect(result.unresolved, isEmpty);
        expect(result.meetings[0].activeWeeks, {9, 10, 11, 12, 13, 14, 15, 16});
        expect(result.meetings[1].activeWeeks, {1, 3, 5, 7, 9, 11, 13, 15});
        expect(result.meetings[1].periods, [3, 4]);
        expect(result.meetings[2].activeWeeks, {2, 4, 6, 8, 10, 12});
      },
    );

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
      final morning = itemsByDateKey['2026-04-21']!.last;
      expect(morning.endTime, '11:25');
      expect(morning.endTimeInferred, isTrue);
      expect(morning.periodLabel, '第2大节');
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
