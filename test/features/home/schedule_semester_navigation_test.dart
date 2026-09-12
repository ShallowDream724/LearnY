import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/enums.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/auth/auth_controller.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/api_client_provider.dart';
import 'package:learn_y/core/providers/app_providers.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/semester/semester_repository.dart';
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';
import 'package:learn_y/features/home/widgets/home_schedule_section.dart';
import 'package:learn_y/features/home/widgets/weekly_timetable.dart';

import '../../support/academic_calendar_fixture.dart';

const summer = '2025-2026-3';
const autumn = '2026-2027-1';
const spring = '2025-2026-2';
const unknownSpring = '2024-2025-2';
final today = DateTime(2026, 9, 12);
final _clock = StateProvider<DateTime>((ref) => today);

void main() {
  Future<_Fixture> setup(WidgetTester tester, {double width = 390}) async {
    final fixture = (await tester.runAsync(_Fixture.create))!;
    addTearDown(fixture.dispose);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: fixture.container,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: HomeTodayScheduleSection(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'weekly boundary never leaves the last week before confirmation; cancel stays and accept is local',
    (tester) async {
      final fixture = await setup(tester);
      await tap(tester, find.byTooltip('查看整周课表'));
      expect(find.text('2026年 9/7 - 9/13'), findsOneWidget);
      await tester.dragFrom(
        tester.getCenter(find.byType(WeeklyTimetable)),
        const Offset(-400, 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('切换课表学期？'), findsOneWidget);
      expect(find.text('2026年 9/7 - 9/13'), findsOneWidget);
      expect(find.text('2026年 9/14 - 9/20'), findsNothing);
      await tap(tester, find.text('留在当前学期'));
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('2026年 9/7 - 9/13'), findsOneWidget);
      await tap(tester, find.byTooltip('下一周'));
      await tap(tester, find.text('切换学期'));
      expect(find.text('2026年 9/14 - 9/20'), findsOneWidget);
      expect(fixture.container.read(currentSemesterIdProvider), summer);
      expect(
        await fixture.database.getState(AppStateKeys.currentSemesterId),
        summer,
      );
      await tap(tester, find.byTooltip('关闭课表'));
      expect(fixture.container.read(homeScheduleBrowseDateProvider), today);
    },
  );

  testWidgets(
    'home boundary switches persisted learning semester after consent, without waiting for content sync',
    (tester) async {
      final fixture = await setup(tester, width: 1280);
      fixture.container.read(homeScheduleSelectedDateProvider.notifier).state =
          DateTime(2026, 9, 13);
      await tester.pumpAndSettle();
      expect(
        fixture.container.read(homeScheduleBrowseDateProvider),
        DateTime(2026, 9, 13),
      );
      await tap(tester, find.byTooltip('后一天'));
      expect(find.text('切换首页学期？'), findsOneWidget);
      expect(fixture.container.read(currentSemesterIdProvider), summer);
      expect(
        fixture.container.read(homeScheduleBrowseDateProvider),
        DateTime(2026, 9, 13),
      );
      await tap(tester, find.text('留在当前学期'));
      expect(
        fixture.container.read(homeScheduleBrowseDateProvider),
        DateTime(2026, 9, 13),
      );
      fixture.client.pendingCourses = Completer();
      await tap(tester, find.byTooltip('后一天'));
      await tap(tester, find.text('切换学期'));
      await tester.runAsync(() => fixture.container.pump());
      await tester.pumpAndSettle();
      expect(fixture.container.read(currentSemesterIdProvider), autumn);
      expect(
        await fixture.database.getState(AppStateKeys.currentSemesterId),
        autumn,
      );
      expect(
        fixture.container.read(homeScheduleBrowseDateProvider),
        DateTime(2026, 9, 14),
      );
      expect(fixture.client.pendingCourses!.isCompleted, isFalse);
      fixture.client.pendingCourses!.complete([]);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'weekly semester picker jumps to a term start or the current week, and never writes the home semester',
    (tester) async {
      final fixture = await setup(tester);
      fixture.container.read(homeScheduleSelectedDateProvider.notifier).state =
          DateTime(2026, 8, 10);
      await tester.pumpAndSettle();
      await tap(tester, find.byTooltip('查看整周课表'));
      expect(find.text('2026年 9/7 - 9/13'), findsOneWidget);
      await tap(tester, find.byTooltip('切换课表学期'));
      await tap(tester, find.text('2026-2027 秋季学期'));
      expect(find.text('2026年 9/14 - 9/20'), findsOneWidget);
      await tap(tester, find.byTooltip('下一周'));
      expect(find.text('2026年 9/21 - 9/27'), findsOneWidget);
      await tap(tester, find.byTooltip('切换课表学期'));
      await tap(tester, find.text('2025-2026 夏季学期'));
      expect(find.text('2026年 9/7 - 9/13'), findsOneWidget);
      expect(fixture.container.read(currentSemesterIdProvider), summer);
      await tap(tester, find.byTooltip('关闭课表'));
      expect(
        fixture.container.read(homeScheduleBrowseDateProvider),
        DateTime(2026, 8, 10),
      );
    },
  );

  testWidgets(
    'home touch paging stops at the last day and a single drag opens only one confirmation',
    (tester) async {
      final fixture = await setup(tester);
      fixture.container.read(homeScheduleSelectedDateProvider.notifier).state =
          DateTime(2026, 9, 13);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(find.text('切换首页学期？'), findsOneWidget);
      expect(
        fixture.container.read(homeScheduleBrowseDateProvider),
        DateTime(2026, 9, 13),
      );
      await tap(tester, find.text('留在当前学期'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(AlertDialog), findsNothing);
      expect(fixture.container.read(currentSemesterIdProvider), summer);
    },
  );

  testWidgets('unknown term dates cannot silently navigate to a guessed date', (
    tester,
  ) async {
    final fixture = await setup(tester);
    await tap(tester, find.byTooltip('查看整周课表'));
    await tap(tester, find.byTooltip('切换课表学期'));
    final tile = find.ancestor(
      of: find.text('2024-2025 春季学期'),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
    expect(find.text('学期起止日期待确认'), findsOneWidget);
    expect(fixture.container.read(currentSemesterIdProvider), summer);
    expect(tester.takeException(), isNull);
  });

  testWidgets('midnight at the end of a semester stays on its last day', (
    tester,
  ) async {
    final fixture = await setup(tester);
    fixture.container.read(_clock.notifier).state = DateTime(2026, 9, 13);
    await tester.pumpAndSettle();
    expect(
      fixture.container.read(homeScheduleBrowseDateProvider),
      DateTime(2026, 9, 13),
    );
    fixture.container.read(_clock.notifier).state = DateTime(2026, 9, 14);
    await tester.pumpAndSettle();
    expect(
      fixture.container.read(homeScheduleBrowseDateProvider),
      DateTime(2026, 9, 13),
    );
    expect(fixture.container.read(currentSemesterIdProvider), summer);
  });
}

class _Fixture {
  final database = AppDatabase(NativeDatabase.memory());
  final client = _Api();
  late final ProviderContainer container;
  static Future<_Fixture> create() async {
    final fixture = _Fixture();
    final academicCalendar = await loadUndergraduateAcademicCalendarFixture();
    await SemesterRepository(
      database: fixture.database,
      apiClient: fixture.client,
    ).refreshCatalog();
    await fixture.database.setState(AppStateKeys.currentSemesterId, summer);
    fixture.container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(fixture.database),
        apiClientProvider.overrideWithValue(fixture.client),
        authProvider.overrideWith((ref) => _Auth()),
        initialCurrentSemesterIdProvider.overrideWithValue(summer),
        academicCalendarProvider.overrideWithValue(academicCalendar),
        homeScheduleTodayProvider.overrideWith((ref) => ref.watch(_clock)),
        scheduleWeekProvider.overrideWith(
          (ref, week) => Stream.value(
            ScheduleState(
              snapshot: emptyScheduleSnapshot(
                buildHomeScheduleDays(week, today: today),
              ),
              hasCalendarData: true,
            ),
          ),
        ),
      ],
    );
    await fixture.container.read(semesterCatalogProvider.future);
    return fixture;
  }

  Future<void> dispose() async {
    container.dispose();
    final pending = client.pendingCourses;
    if (pending != null && !pending.isCompleted) pending.complete([]);
    await Future<void>.delayed(Duration.zero);
    await database.close();
    client.dio.close(force: true);
  }
}

class _Auth extends StateNotifier<AuthState> implements AuthController {
  _Auth() : super(const AuthState.authenticated(username: 'test-student'));
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected authentication operation');
}

class _Api extends Learn2018Helper {
  Completer<List<api.CourseInfo>>? pendingCourses;
  @override
  Future<List<String>> getSemesterIdList() async => [
    autumn,
    summer,
    spring,
    unknownSpring,
  ];
  @override
  Future<api.SemesterInfo> getCurrentSemester() async => const api.SemesterInfo(
    id: summer,
    startDate: '2026-06-29',
    endDate: '2026-09-13',
    startYear: 2025,
    endYear: 2026,
    type: SemesterType.summer,
  );
  @override
  Future<List<api.CourseInfo>> getCourseList(
    String semesterID, {
    CourseType courseType = CourseType.student,
    Language? lang,
  }) async => pendingCourses?.future ?? [];
}
