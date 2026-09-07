import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/enums.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/sync_provider.dart';
import 'package:learn_y/core/semester/semester_switcher.dart';
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';

const oldTerm = '2025-2026-2';
const currentTerm = '2026-2027-1';

void main() {
  test(
    'rapid selections persist and display the last requested semester',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      final first = fixture.sync.selectSemester(oldTerm);
      final second = fixture.sync.selectSemester(currentTerm);
      await Future.wait([first, second]);
      expect(fixture.container.read(currentSemesterIdProvider), currentTerm);
      expect(
        await fixture.db.getState(AppStateKeys.currentSemesterId),
        currentTerm,
      );
      expect(fixture.client.requestedTerms.last, currentTerm);
    },
  );

  testWidgets('semester toolbar fits phone, tablet and desktop widths', (
    tester,
  ) async {
    final fixture = Fixture();
    addTearDown(fixture.dispose);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    for (final width in [320.0, 600.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: fixture.container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.5)),
              child: child!,
            ),
            home: const Scaffold(body: Column(children: [SemesterToolbar()])),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('2025-2026 春季学期'), findsOneWidget);
    }
    await tester.pumpWidget(const SizedBox());
  });

  test(
    'account invalidation rejects outstanding responses before cleanup',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      final gate = Completer<List<api.CourseInfo>>();
      fixture.client.courseGate = gate;
      final pending = fixture.sync.syncAll();
      await fixture.client.courseStarted.future;
      fixture.container.read(dataSessionEpochProvider.notifier).state++;
      await fixture.db.clearUserScopedData();
      gate.complete([course('former-owner-course')]);
      expect((await pending).status, SyncStatus.cancelled);
      expect(await fixture.db.getAllCourses(), isEmpty);
    },
  );

  test(
    'a forced refresh queues separately behind an existing forced request',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      final gate = Completer<List<api.CourseInfo>>();
      fixture.client.courseGate = gate;
      final first = fixture.sync.syncAll(force: true);
      await fixture.client.courseStarted.future;
      final second = fixture.sync.syncAll(force: true);
      expect(identical(first, second), isFalse);
      fixture.client.courseGate = null;
      gate.complete([course('course-$oldTerm')]);
      expect((await first).status, SyncStatus.success);
      expect((await second).status, SyncStatus.success);
      expect(fixture.client.requestedTerms, [oldTerm, oldTerm]);
    },
  );

  test(
    'full sync preserves selection and stores official semester separately',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      expect((await fixture.sync.syncAll()).status, SyncStatus.success);
      expect(fixture.client.requestedTerms, [oldTerm]);
      expect(fixture.container.read(currentSemesterIdProvider), oldTerm);
      expect(
        await fixture.db.getState(AppStateKeys.serverCurrentSemesterId),
        currentTerm,
      );
      expect((await fixture.db.getMostRecentSemester())?.id, currentTerm);
      expect((await fixture.db.getAllSemesters()).length, 2);
    },
  );

  test('switch persists selection and has independent cooldown', () async {
    final fixture = Fixture();
    addTearDown(fixture.dispose);
    await fixture.sync.syncAll();
    expect((await fixture.sync.syncAll()).status, SyncStatus.cooldown);
    expect(
      (await fixture.sync.selectSemester(currentTerm)).status,
      SyncStatus.success,
    );
    expect(
      await fixture.db.getState(AppStateKeys.currentSemesterId),
      currentTerm,
    );
    expect(fixture.client.requestedTerms, [oldTerm, currentTerm]);
    expect((await fixture.db.getCoursesBySemester(oldTerm)).length, 1);
    expect((await fixture.db.getCoursesBySemester(currentTerm)).length, 1);
  });

  test(
    'a late response after switching cannot write old course data',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      final gate = Completer<List<api.CourseInfo>>();
      fixture.client.courseGate = gate;
      final first = fixture.sync.syncAll();
      await fixture.client.courseStarted.future;
      fixture.client.courseGate = null;
      expect(
        (await fixture.sync.selectSemester(currentTerm)).status,
        SyncStatus.success,
      );
      gate.complete([course('late-old-course')]);
      expect((await first).status, SyncStatus.cancelled);
      expect(await fixture.db.getCourseById('late-old-course'), isNull);
      expect(fixture.container.read(currentSemesterIdProvider), currentTerm);
    },
  );

  test(
    'timeout ends loading, prevents late writes, and permits retry',
    () async {
      final fixture = Fixture(timeout: const Duration(milliseconds: 100));
      addTearDown(fixture.dispose);
      final gate = Completer<List<api.CourseInfo>>();
      fixture.client.courseGate = gate;
      final task = fixture.sync.syncAll();
      await fixture.client.courseStarted.future;
      expect((await task).status, SyncStatus.error);
      fixture.client.courseGate = null;
      expect((await fixture.sync.syncAll()).status, SyncStatus.success);
      gate.complete([course('timed-out-course')]);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await fixture.db.getCourseById('timed-out-course'), isNull);
      expect(
        fixture.container.read(syncStateProvider).status,
        SyncStatus.success,
      );
    },
  );

  test(
    'all content failures are errors; partial failures remain retryable',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      fixture.client.failHomework = true;
      fixture.client.failOtherContent = true;
      expect((await fixture.sync.syncAll()).status, SyncStatus.error);
      fixture.client.failOtherContent = false;
      final partial = await fixture.sync.syncAll();
      expect(partial.status, SyncStatus.success);
      expect(partial.syncWarnings, hasLength(1));
      fixture.client.failHomework = false;
      expect((await fixture.sync.syncAll()).status, SyncStatus.success);
    },
  );

  test(
    'catalog partial failure is surfaced and historical dates are preserved',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      await fixture.db.upsertSemester(
        SemestersCompanion.insert(
          id: oldTerm,
          startDate: '2026-02-23',
          endDate: '2026-06-28',
          startYear: 2025,
          endYear: 2026,
          type: 'spring',
        ),
      );
      fixture.client.failCurrent = true;
      final result = await fixture.sync.syncAll();
      expect(result.status, SyncStatus.success);
      expect(result.syncWarnings, isNotEmpty);
      expect(
        (await fixture.db.getSemesterById(oldTerm))?.startDate,
        '2026-02-23',
      );
      fixture.client.failCurrent = false;
      expect((await fixture.sync.syncAll()).status, SyncStatus.success);
    },
  );

  test(
    'forced post-submit refresh bypasses cooldown and removes withdrawn homework',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      fixture.client.homeworks = [homework('homework-1')];
      await fixture.sync.syncAll();
      final saved = (await fixture.db.getHomeworksBySemester(oldTerm)).single;
      expect(saved.completionType, HomeworkCompletionType.individual.value);
      expect(saved.submissionType, HomeworkSubmissionType.webLearning.value);
      fixture.client.homeworks = [];
      expect(
        (await fixture.sync.syncHomeworksOnly()).status,
        SyncStatus.cooldown,
      );
      expect(
        (await fixture.sync.syncHomeworksOnly(force: true)).status,
        SyncStatus.success,
      );
      expect(await fixture.db.getHomeworksBySemester(oldTerm), isEmpty);
    },
  );

  test(
    'duplicate requests share a completion and historical schedule emits empty',
    () async {
      final fixture = Fixture();
      addTearDown(fixture.dispose);
      final first = fixture.sync.syncAll();
      final second = fixture.sync.syncAll();
      expect(identical(first, second), isTrue);
      await first;
      final schedule = await fixture.container.read(
        homeScheduleSnapshotProvider.future,
      );
      expect(schedule.itemsByDateKey.values.expand((items) => items), isEmpty);
      expect(fixture.client.calendarCalls, 0);
    },
  );

  test(
    'first sync chooses official semester when selection is absent',
    () async {
      final fixture = Fixture(selected: null);
      addTearDown(fixture.dispose);
      expect((await fixture.sync.syncAll()).status, SyncStatus.success);
      expect(fixture.container.read(currentSemesterIdProvider), currentTerm);
      expect(
        await fixture.db.getState(AppStateKeys.currentSemesterId),
        currentTerm,
      );
      expect(fixture.client.requestedTerms, [currentTerm]);
    },
  );
}

class Fixture {
  Fixture({
    String? selected = oldTerm,
    Duration timeout = const Duration(seconds: 5),
  }) {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        apiClientProvider.overrideWithValue(client),
        initialAuthUsernameProvider.overrideWithValue('test-owner'),
        didBootstrapAppSessionProvider.overrideWithValue(true),
        initialCurrentSemesterIdProvider.overrideWithValue(selected),
        syncTimeoutProvider.overrideWithValue(timeout),
      ],
    );
  }

  final db = AppDatabase(NativeDatabase.memory());
  final client = FakeApi();
  late final ProviderContainer container;
  SyncNotifier get sync => container.read(syncStateProvider.notifier);
  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

class FakeApi extends Learn2018Helper {
  Completer<List<api.CourseInfo>>? courseGate;
  final courseStarted = Completer<void>();
  final requestedTerms = <String>[];
  var homeworks = <api.Homework>[];
  bool failHomework = false;
  bool failOtherContent = false;
  bool failCurrent = false;
  int calendarCalls = 0;

  @override
  Future<List<String>> getSemesterIdList() async => [oldTerm, currentTerm];
  @override
  Future<api.SemesterInfo> getCurrentSemester() async {
    if (failCurrent) throw StateError('offline');
    return const api.SemesterInfo(
      id: currentTerm,
      startDate: '2026-09-07',
      endDate: '2027-01-15',
      startYear: 2026,
      endYear: 2027,
      type: SemesterType.fall,
    );
  }

  @override
  Future<List<api.CourseInfo>> getCourseList(
    String semesterID, {
    CourseType courseType = CourseType.student,
    Language? lang,
  }) async {
    requestedTerms.add(semesterID);
    if (!courseStarted.isCompleted) courseStarted.complete();
    return courseGate?.future ?? [course('course-$semesterID')];
  }

  @override
  Future<List<api.Homework>> getHomeworkList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    if (failHomework) throw StateError('offline');
    return homeworks;
  }

  @override
  Future<List<api.Notification>> getNotificationList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    if (failOtherContent) throw StateError('offline');
    return [];
  }

  @override
  Future<List<api.CourseFile>> getFileList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    if (failOtherContent) throw StateError('offline');
    return [];
  }

  @override
  Future<List<api.CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) async {
    calendarCalls++;
    return [];
  }
}

api.CourseInfo course(String id) => api.CourseInfo(
  id: id,
  name: 'Course',
  chineseName: 'Course',
  englishName: '',
  timeAndLocation: [],
  url: '',
  teacherName: '',
  teacherNumber: '',
  courseNumber: '',
  courseIndex: 0,
  courseType: CourseType.student,
);
api.Homework homework(String id) => api.Homework(
  id: id,
  studentHomeworkId: id,
  baseId: id,
  title: 'Homework',
  deadline: '2026-10-01',
  url: '',
  submitUrl: '',
  isLateSubmission: false,
  submitted: false,
  graded: false,
  isFavorite: false,
  completionType: HomeworkCompletionType.individual,
  submissionType: HomeworkSubmissionType.webLearning,
);
