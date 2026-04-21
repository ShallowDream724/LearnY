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

    test('parses front-half week descriptors like 前八周', () {
      final firstHalfDay = buildHomeScheduleDays(
        DateTime(2026, 3, 16),
        length: 1,
      );
      final laterDay = buildHomeScheduleDays(DateTime(2026, 5, 18), length: 1);

      final course = _course(
        name: '临床早接',
        timeAndLocation: ['星期一第3节(前八周)，医学楼101'],
      );

      final firstHalfSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: firstHalfDay,
        courses: [course],
        semesterStartDate: '2026-03-16',
      );
      final laterSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: laterDay,
        courses: [course],
        semesterStartDate: '2026-03-16',
      );

      expect(firstHalfSnapshot.itemsFor(firstHalfDay.first), hasLength(1));
      expect(laterSnapshot.itemsFor(laterDay.first), isEmpty);
    });

    test('parses english cached course strings from english learn mode', () {
      final days = buildHomeScheduleDays(DateTime(2026, 4, 21), length: 1);
      final snapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: days,
        courses: [
          _course(
            name: 'Molecular Biology',
            chineseName: '分子生物学',
            timeAndLocation: ['Section 1 of Tues (Week all ), 六教6B207'],
          ),
          _course(
            name: 'An Introduction to Industrial System',
            chineseName: '工业系统概论',
            timeAndLocation: ['Section 2 of Tues (Week 1-12), 李兆基科技大楼B148'],
          ),
        ],
        semesterStartDate: '2026-02-24',
      );

      final items = snapshot.itemsFor(days.first);
      expect(items.map((item) => item.courseName), ['分子生物学', '工业系统概论']);
      expect(items.map((item) => item.startTime), ['08:00', '09:50']);
      expect(items.map((item) => item.location), ['六教6B207', '李兆基科技大楼B148']);
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

    test('merges adjacent registrar events for the same course block', () {
      final days = buildHomeScheduleDays(DateTime(2026, 3, 24), length: 1);
      final snapshot = buildHomeScheduleSnapshotFromCalendarEvents(
        days: days,
        events: const [
          api.CalendarEvent(
            location: '六教6A414',
            status: '',
            startTime: '13:30',
            endTime: '15:05',
            date: '20260324',
            courseName: '土力学',
          ),
          api.CalendarEvent(
            location: '六教6A414',
            status: '',
            startTime: '15:20',
            endTime: '16:55',
            date: '20260324',
            courseName: '土力学',
          ),
        ],
      );

      final items = snapshot.itemsFor(days.first);
      expect(items, hasLength(1));
      expect(items.first.courseName, '土力学');
      expect(items.first.startTime, '13:30');
      expect(items.first.endTime, '16:55');
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

  group('home schedule remote refresh policy', () {
    test('uses cached data immediately but refreshes again when stale', () {
      final days = buildHomeScheduleDays(DateTime(2026, 3, 21), length: 2);
      final localSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: days,
        courses: [
          _course(name: '分子生物学', timeAndLocation: ['星期六第1节(全周)，六教6B207']),
        ],
        semesterStartDate: '2026-03-16',
      );

      final successfulState = HomeScheduleRemoteRefreshState(
        semesterId: 'semester-1',
        lastAttemptAt: DateTime(2026, 3, 21, 8, 0),
        hasSuccessfulRefresh: true,
      );

      expect(
        shouldFetchHomeScheduleRemoteSnapshot(
          semesterId: 'semester-1',
          cachedSnapshot: null,
          localSnapshot: localSnapshot,
          refreshState: null,
          now: DateTime(2026, 3, 21, 9, 0),
        ),
        isTrue,
      );

      expect(
        shouldFetchHomeScheduleRemoteSnapshot(
          semesterId: 'semester-1',
          cachedSnapshot: null,
          localSnapshot: localSnapshot,
          refreshState: successfulState,
          now: DateTime(2026, 3, 21, 16, 0),
        ),
        isFalse,
      );

      expect(
        shouldFetchHomeScheduleRemoteSnapshot(
          semesterId: 'semester-1',
          cachedSnapshot: null,
          localSnapshot: localSnapshot,
          refreshState: successfulState,
          now: DateTime(2026, 3, 21, 21, 0),
        ),
        isTrue,
      );
    });

    test('backs off repeated automatic retries after a failed pull', () {
      final days = buildHomeScheduleDays(DateTime(2026, 3, 21), length: 1);
      final localSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
        days: days,
        courses: [
          _course(name: '工程数学', timeAndLocation: ['星期六第1节(全周)，三教3204']),
        ],
        semesterStartDate: '2026-03-16',
      );
      final failedState = HomeScheduleRemoteRefreshState(
        semesterId: 'semester-1',
        lastAttemptAt: DateTime(2026, 3, 21, 8, 0),
        hasSuccessfulRefresh: false,
      );

      expect(
        shouldFetchHomeScheduleRemoteSnapshot(
          semesterId: 'semester-1',
          cachedSnapshot: null,
          localSnapshot: localSnapshot,
          refreshState: failedState,
          now: DateTime(2026, 3, 21, 9, 0),
        ),
        isFalse,
      );

      expect(
        shouldFetchHomeScheduleRemoteSnapshot(
          semesterId: 'semester-1',
          cachedSnapshot: null,
          localSnapshot: localSnapshot,
          refreshState: failedState,
          now: DateTime(2026, 3, 21, 10, 30),
        ),
        isTrue,
      );
    });
  });

  group('mergeHomeScheduleSnapshots', () {
    test('keeps local items when registrar snapshot is missing a course', () {
      final days = buildHomeScheduleDays(DateTime(2026, 3, 16), length: 1);
      final remote = buildHomeScheduleSnapshotFromCalendarEvents(
        days: days,
        events: const [
          api.CalendarEvent(
            location: '六教6A414',
            status: '',
            startTime: '13:30',
            endTime: '15:05',
            date: '20260316',
            courseName: '土力学',
          ),
        ],
      );
      final local = buildHomeScheduleSnapshotFromCachedCourses(
        days: days,
        courses: [
          _course(name: '土力学', timeAndLocation: ['星期一第3节(全周)，六教6A414']),
          _course(name: '临床早接', timeAndLocation: ['星期一第4节(前八周)，医学楼101']),
        ],
        semesterStartDate: '2026-03-16',
      );

      final merged = mergeHomeScheduleSnapshots(
        primary: remote,
        fallback: local,
      );

      expect(
        merged.itemsFor(days.first).map((item) => item.courseName).toList(),
        ['土力学', '临床早接'],
      );
    });

    test('merges adjacent items after combining remote and local snapshots', () {
      final days = buildHomeScheduleDays(DateTime(2026, 3, 24), length: 1);
      final remote = buildHomeScheduleSnapshotFromCalendarEvents(
        days: days,
        events: const [
          api.CalendarEvent(
            location: '六教6A414',
            status: '',
            startTime: '13:30',
            endTime: '15:05',
            date: '20260324',
            courseName: '土力学',
          ),
        ],
      );
      final local = HomeScheduleSnapshot(
        days: days,
        itemsByDateKey: {
          days.first.dateKey: const [
            TodayScheduleItem(
              courseId: 'course-1',
              courseName: '土力学',
              startTime: '15:20',
              endTime: '16:55',
              location: '六教6A414',
            ),
          ],
        },
      );

      final merged = mergeHomeScheduleSnapshots(
        primary: remote,
        fallback: local,
      );

      final items = merged.itemsFor(days.first);
      expect(items, hasLength(1));
      expect(items.first.startTime, '13:30');
      expect(items.first.endTime, '16:55');
    });
  });
}

db.Course _course({
  required String name,
  String? chineseName,
  required List<String> timeAndLocation,
}) {
  return db.Course(
    id: '${name}_id',
    name: name,
    chineseName: chineseName ?? name,
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
