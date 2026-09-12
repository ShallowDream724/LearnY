import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/enums.dart';
import 'package:learn_y/core/api/learning_read_api.dart';
import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/courses/course_catalog_repository.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/schedule/schedule_repository.dart';
import 'package:learn_y/core/sync/sync_operation.dart';

import '../../support/academic_calendar_fixture.dart';

void main() {
  test(
    'failed schedule metadata preserves cached recurrence, a successful empty value clears it',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = _Api()..courses = [_course('course')];
      final catalog = CourseCatalogRepository(database: db, apiClient: client);
      await catalog.refresh('term', SyncOperation());
      final original = (await db.getCourseById('course'))!.timeAndLocationJson;
      client.courses = [_course('course', loaded: false)];
      await catalog.refresh('term', SyncOperation());
      expect((await db.getCourseById('course'))!.timeAndLocationJson, original);
      client.courses = [_course('course', empty: true)];
      await catalog.refresh('term', SyncOperation());
      expect((await db.getCourseById('course'))!.timeAndLocationJson, '[]');
    },
  );
  test(
    'date browsing fetches the next term, adds new courses and suppresses withdrawn calendar entries',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.upsertSemester(
        SemestersCompanion.insert(
          id: '2026-2027-1',
          startDate: '',
          endDate: '',
          startYear: 2026,
          endYear: 2027,
          type: 'fall',
        ),
      );
      final client = _Api()
        ..courses = [_course('old')]
        ..events = [_event('old', '2026-09-14')];
      final catalog = CourseCatalogRepository(database: db, apiClient: client);
      final academicCalendar = await loadUndergraduateAcademicCalendarFixture();
      final repository = ScheduleRepository(
        database: db,
        apiClient: client,
        courseCatalog: catalog,
        academicCalendar: academicCalendar,
        now: () => DateTime(2026, 9, 7),
      );
      final days = buildHomeScheduleDays(DateTime(2026, 9, 14));
      Future<ScheduleState> fetch() async {
        await repository.resetRemoteRefresh(days.first.dateKey);
        var refreshing = false;
        return repository
            .watch(days: days, fetchRemote: true, operation: SyncOperation())
            .firstWhere((state) {
              if (state.isRefreshing) {
                refreshing = true;
                return false;
              }
              return refreshing;
            });
      }

      final first = await fetch();
      expect(first.snapshot.itemsFor(days.first).single.courseId, 'old');
      client.courses = [_course('new'), _course('lab', unassigned: true)];
      client.events = [_event('old', '2026-09-14')];
      final updated = await fetch();
      expect(updated.snapshot.itemsFor(days.first), isEmpty);
      expect(updated.snapshot.unscheduledCourses.single.courseId, 'lab');
      expect(await db.getCourseById('old'), isNull);
      expect(client.rosters, ['2026-2027-1', '2026-2027-1']);
      // The same retained registrar occurrence is still history after its date.
      final history = await ScheduleRepository(
        database: db,
        apiClient: client,
        courseCatalog: catalog,
        academicCalendar: academicCalendar,
        now: () => DateTime(2026, 9, 21),
      ).watch(days: days, fetchRemote: false, operation: SyncOperation()).first;
      expect(
        history.snapshot.itemsFor(days.first).map((item) => item.courseName),
        contains('old'),
      );
    },
  );

  test(
    'registrar coverage suppresses routine courses missing from that date range',
    () {
      final days = buildHomeScheduleDays(DateTime(2026, 9, 14));
      final routine = HomeScheduleSnapshot(
        days: days,
        hasRoutineData: true,
        itemsByDateKey: {
          days[0].dateKey: [
            for (final id in ['moved', 'new'])
              TodayScheduleItem(
                courseId: id,
                courseName: id,
                startTime: '09:50',
                endTime: '11:25',
                location: '',
                source: ScheduleItemSource.routine,
                endTimeInferred: true,
              ),
          ],
        },
      );
      final actual = buildHomeScheduleSnapshotFromCalendarEvents(
        days: days,
        events: [_event('moved', days[5].dateKey)],
        courseIdsByName: {'moved': 'moved'},
      );
      final result = reconcileScheduleSources(
        calendar: actual,
        routine: routine,
        enrolledCourseIds: {'moved', 'new'},
        today: days.first.date,
      );
      expect(result.itemsFor(days[0]), isEmpty);
      expect(result.itemsFor(days[5]).single.courseId, 'moved');
      expect(
        result.itemsFor(days[5]).single.source,
        ScheduleItemSource.registrar,
      );
    },
  );

  test('routine remains available when registrar coverage is unknown', () {
    final days = buildHomeScheduleDays(DateTime(2026, 9, 14));
    final routine = HomeScheduleSnapshot(
      days: days,
      hasRoutineData: true,
      itemsByDateKey: {
        days.first.dateKey: const [
          TodayScheduleItem(
            courseId: 'course',
            courseName: 'course',
            startTime: '09:50',
            endTime: '11:25',
            location: '',
            source: ScheduleItemSource.routine,
          ),
        ],
      },
    );

    final result = reconcileScheduleSources(
      calendar: emptyScheduleSnapshot(days),
      routine: routine,
      enrolledCourseIds: {'course'},
      today: days.first.date,
    );

    expect(result.itemsFor(days.first).single.courseId, 'course');
  });

  test('term-edge coverage leaves dates outside the query untouched', () {
    final days = buildHomeScheduleDays(DateTime(2026, 9, 14));
    final routine = HomeScheduleSnapshot(
      days: days,
      hasRoutineData: true,
      itemsByDateKey: {
        days[0].dateKey: [_routineItem('monday')],
        days[2].dateKey: [_routineItem('wednesday')],
      },
    );
    final calendar = buildHomeScheduleSnapshotFromCalendarEvents(
      days: days,
      events: const [],
      authoritativeDates: days.skip(2).map((day) => day.date),
    );

    final result = reconcileScheduleSources(
      calendar: calendar,
      routine: routine,
      enrolledCourseIds: {'monday', 'wednesday'},
      today: days.first.date,
    );

    expect(result.itemsFor(days[0]).single.courseId, 'monday');
    expect(result.itemsFor(days[2]), isEmpty);
  });
}

TodayScheduleItem _routineItem(String courseId) => TodayScheduleItem(
  courseId: courseId,
  courseName: courseId,
  startTime: '09:50',
  endTime: '11:25',
  location: '',
  source: ScheduleItemSource.routine,
);

api.CourseInfo _course(
  String id, {
  bool unassigned = false,
  bool loaded = true,
  bool empty = false,
}) => api.CourseInfo(
  id: id,
  name: id,
  chineseName: id,
  englishName: '',
  timeAndLocationLoaded: loaded,
  timeAndLocation: empty || !loaded
      ? []
      : [unassigned ? '第1-16周星期 第0节，各实验单元实验室' : '第1-16周星期一第2节，六教'],
  url: '',
  teacherName: '',
  teacherNumber: '',
  courseNumber: '',
  courseIndex: 0,
  courseType: CourseType.student,
);

api.CalendarEvent _event(String name, String date) => api.CalendarEvent(
  location: '三教',
  status: '',
  startTime: '09:50',
  endTime: '12:15',
  date: date,
  courseName: name,
);

class _Api implements LearningReadApi {
  List<api.CourseInfo> courses = [];
  List<api.CalendarEvent> events = [];
  final rosters = <String>[];
  @override
  Future<List<api.CourseInfo>> getCourseList(
    String semesterId, {
    CourseType courseType = CourseType.student,
    Language? lang,
  }) async {
    rosters.add(semesterId);
    return courses;
  }

  @override
  Future<List<api.CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) async => events;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call');
}
