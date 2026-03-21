import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';

void main() {
  group('buildHomeScheduleSnapshotFromCachedCourses', () {
    test('maps cached teaching blocks to the correct clock times', () {
      final days = buildHomeScheduleDays(DateTime(2026, 3, 16), length: 1);
      final snapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: days,
        courses: [
          _course(
            name: '土力学',
            timeAndLocation: ['星期一第3节(全周)，六教6A414', '星期一第4节(全周)，六教6A414'],
          ),
        ],
        semesterStartDate: '2026-03-16',
      );

      final items = snapshot.itemsFor(days.first);
      expect(items, hasLength(1));
      expect(items.first.courseName, '土力学');
      expect(items.first.startTime, '13:30');
      expect(items.first.endTime, '16:55');
      expect(items.first.location, '六教6A414');
    });

    test('respects odd and even week filters', () {
      final oddWeekDay = buildHomeScheduleDays(
        DateTime(2026, 3, 16),
        length: 1,
      );
      final evenWeekDay = buildHomeScheduleDays(
        DateTime(2026, 3, 23),
        length: 1,
      );

      final course = _course(
        name: '信号处理',
        timeAndLocation: ['星期一第1-2节(单周)，一教101'],
      );

      final oddWeekSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: oddWeekDay,
        courses: [course],
        semesterStartDate: '2026-03-16',
      );
      final evenWeekSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: evenWeekDay,
        courses: [course],
        semesterStartDate: '2026-03-16',
      );

      expect(oddWeekSnapshot.itemsFor(oddWeekDay.first), hasLength(1));
      expect(evenWeekSnapshot.itemsFor(evenWeekDay.first), isEmpty);
    });

    test(
      'matches the observed slot mapping from learn course time strings',
      () {
        final monday = buildHomeScheduleDays(DateTime(2026, 3, 23), length: 1);
        final tuesday = buildHomeScheduleDays(DateTime(2026, 3, 24), length: 1);
        final wednesday = buildHomeScheduleDays(
          DateTime(2026, 3, 25),
          length: 1,
        );

        final mondaySnapshot = buildHomeScheduleSnapshotFromCachedCourses(
          days: monday,
          courses: [
            _course(name: '游泳', timeAndLocation: ['星期一第2节(全周)，游泳馆']),
            _course(name: '西方音乐剧史', timeAndLocation: ['星期一第4节(全周)，蒙楼(艺教)多功能厅']),
          ],
          semesterStartDate: '2026-03-16',
        );
        final tuesdaySnapshot = buildHomeScheduleSnapshotFromCachedCourses(
          days: tuesday,
          courses: [
            _course(name: '分子生物学', timeAndLocation: ['星期二第1节(全周)，六教6B207']),
            _course(
              name: '工业系统概论',
              timeAndLocation: ['星期二第2节(全周)，李兆基科技大楼B148'],
            ),
            _course(name: '法律与神话传说', timeAndLocation: ['星期二第6节(全周)，六教6A214']),
          ],
          semesterStartDate: '2026-03-16',
        );
        final wednesdaySnapshot = buildHomeScheduleSnapshotFromCachedCourses(
          days: wednesday,
          courses: [
            _course(
              name: '分子生物学基础实验',
              timeAndLocation: ['星期三第3节(全周)，', '星期三第4节(全周)，'],
            ),
            _course(name: '医学细胞生物学实验', timeAndLocation: ['星期三第6节(全周)，']),
          ],
          semesterStartDate: '2026-03-16',
        );

        expect(
          mondaySnapshot.itemsFor(monday.first).map((item) => item.startTime),
          ['09:50', '15:20'],
        );
        expect(
          tuesdaySnapshot.itemsFor(tuesday.first).map((item) => item.startTime),
          ['08:00', '09:50', '19:20'],
        );
        expect(
          wednesdaySnapshot
              .itemsFor(wednesday.first)
              .map((item) => item.startTime),
          ['13:30', '19:20'],
        );
      },
    );
  });

  group('buildHomeScheduleSnapshotFromCalendarEvents', () {
    test('accepts compact registrar dates', () {
      final days = buildHomeScheduleDays(DateTime(2026, 3, 21), length: 1);
      final snapshot = buildHomeScheduleSnapshotFromCalendarEvents(
        days: days,
        events: const [
          api.CalendarEvent(
            location: '三教3204',
            status: '',
            startTime: '08:00',
            endTime: '09:35',
            date: '20260321',
            courseName: '工程数学',
          ),
        ],
      );

      final items = snapshot.itemsFor(days.first);
      expect(items, hasLength(1));
      expect(items.first.courseName, '工程数学');
      expect(items.first.location, '三教3204');
    });
  });

  group('home schedule cache payload', () {
    test(
      'round-trips a cached remote snapshot for the same semester and days',
      () {
        final days = buildHomeScheduleDays(DateTime(2026, 3, 21), length: 2);
        final snapshot = buildHomeScheduleSnapshotFromCalendarEvents(
          days: days,
          events: const [
            api.CalendarEvent(
              location: '六教6B207',
              status: '',
              startTime: '08:00',
              endTime: '08:45',
              date: '20260321',
              courseName: '分子生物学',
            ),
          ],
        );

        final payload = encodeHomeScheduleSnapshotCachePayload(
          semesterId: 'semester-1',
          snapshot: snapshot,
        );
        final decoded = decodeHomeScheduleSnapshotCachePayload(
          semesterId: 'semester-1',
          days: days,
          raw: payload,
        );

        expect(decoded, isNotNull);
        expect(decoded!.itemsFor(days.first), hasLength(1));
        expect(decoded.itemsFor(days.first).first.courseName, '分子生物学');
        expect(decoded.itemsFor(days.first).first.startTime, '08:00');
      },
    );
  });
}

db.Course _course({
  required String name,
  required List<String> timeAndLocation,
}) {
  return db.Course(
    id: '${name}_id',
    name: name,
    chineseName: name,
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
