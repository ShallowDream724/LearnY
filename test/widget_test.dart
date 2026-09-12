import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learn_y/app/app.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/connectivity_provider.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/sync_provider.dart';
import 'package:learn_y/core/router/router.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/shell/app_shell.dart';
import 'package:learn_y/features/auth/login_screen.dart';
import 'package:learn_y/features/assignments/providers/assignments_providers.dart';
import 'package:learn_y/features/home/home_screen.dart';
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> pumpApp(
    WidgetTester tester, {
    String? username,
    Size size = const Size(1000, 900),
    HomeRefreshActions? homeRefreshActions,
    List<Homework>? assignments,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const build = AppBuildInfo(
      version: '1.0.0',
      buildNumber: '1',
      packageName: 'test.learn_y',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          didBootstrapAppSessionProvider.overrideWithValue(true),
          initialAuthUsernameProvider.overrideWithValue(username),
          authSessionRepositoryProvider.overrideWithValue(
            _UnusedAuthSessionRepository(),
          ),
          apiClientProvider.overrideWith((ref) {
            throw StateError(
              'App route tests must not create a network client',
            );
          }),
          secureStorageProvider.overrideWith((ref) {
            throw StateError('App route tests must not access credentials');
          }),
          appBuildInfoProvider.overrideWith((ref) async => build),
          appUpdateInfoProvider.overrideWith(
            (ref) async => AppUpdateInfo(
              currentBuild: build,
              checkedAt: DateTime(2026, 1, 1),
            ),
          ),
          appSessionCoordinatorProvider.overrideWith(
            (ref) => AppSessionCoordinator(
              RiverpodAppSessionCoordinatorDelegate(ref),
              scheduleTask: (_, _) async {},
            ),
          ),
          connectivityProvider.overrideWith((ref) => _OfflineConnectivity()),
          syncStateProvider.overrideWith((ref) => _IdleSync()),
          minuteTickProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 1, 1)),
          ),
          homeDataProvider.overrideWith(
            (ref) => Stream.value(const HomeData()),
          ),
          homeScheduleProvider.overrideWith(
            (ref) => AsyncValue.data(
              ScheduleState(
                snapshot: HomeScheduleSnapshot(
                  days: buildHomeScheduleDays(DateTime(2026, 1, 1)),
                  itemsByDateKey: const {},
                ),
              ),
            ),
          ),
          if (homeRefreshActions != null)
            homeRefreshActionsProvider.overrideWithValue(homeRefreshActions),
          if (assignments != null)
            assignmentHomeworksProvider.overrideWith(
              (ref) => Stream.value(assignments),
            ),
        ],
        child: const LearnYApp(),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
    await _pumpRouteTransition(tester);
  }

  testWidgets('opening assignment filter keeps the selected branch', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await pumpApp(
      tester,
      username: 'cached-student',
      size: const Size(390, 844),
      assignments: [
        Homework(
          id: 'filter-regression',
          courseId: 'course',
          baseId: 'base',
          title: '待交作业',
          deadline: DateTime(2026, 1, 3).millisecondsSinceEpoch.toString(),
          description: null,
          lateSubmissionDeadline: null,
          submitTime: null,
          submitted: false,
          graded: false,
          grade: null,
          gradeLevel: null,
          graderName: null,
          gradeContent: null,
          gradeTime: null,
          isLateSubmission: false,
          completionType: null,
          submissionType: null,
          isFavorite: false,
          comment: null,
          attachmentJson: null,
          answerContent: null,
          answerAttachmentJson: null,
          submittedContent: null,
          submittedAttachmentJson: null,
          gradeAttachmentJson: null,
        ),
      ],
    );
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    router.go(Routes.assignments);
    await _pumpRouteTransition(tester);
    final pager = tester
        .widget<PageView>(find.byType(PageView).first)
        .controller!;
    final page = pager.page!;
    await tester.tap(find.byTooltip('筛选作业'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.assignments);
    expect(pager.page, closeTo(page, .001));
    // Menus reveal their selected item; that must not move the main pager.
    await Scrollable.ensureVisible(
      tester.element(find.byType(CheckedPopupMenuItem<HomeworkFilter>).last),
    );
    await tester.pumpAndSettle();
    expect(pager.page, closeTo(page, .001));
    await tester.tap(find.byType(CheckedPopupMenuItem<HomeworkFilter>).at(3));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, Routes.assignments);
    expect(find.text('没有符合条件的作业'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    debugDefaultTargetPlatformOverride = null;
  });

  test('home refresh coalesces requests and rejects a stale scope', () async {
    final contentGate = Completer<SyncState>();
    var contentRefreshes = 0;
    var scheduleRefreshes = 0;
    final actions = HomeRefreshActions(
      refreshContent: () {
        contentRefreshes++;
        return contentGate.future;
      },
      refreshSchedule: () async {
        scheduleRefreshes++;
        return true;
      },
    );

    final first = actions.refresh();
    final second = actions.refresh();
    expect(identical(first, second), isTrue);
    contentGate.complete(const SyncState(status: SyncStatus.success));
    await Future.wait([first, second]);
    expect(contentRefreshes, 1);
    expect(scheduleRefreshes, 1);

    final staleGate = Completer<SyncState>();
    var current = true;
    final staleActions = HomeRefreshActions(
      refreshContent: () => staleGate.future,
      refreshSchedule: () async {
        scheduleRefreshes++;
        return true;
      },
      isCurrent: () => current,
    );
    final staleRefresh = staleActions.refresh();
    current = false;
    staleGate.complete(const SyncState(status: SyncStatus.cancelled));
    final staleResult = await staleRefresh;
    expect(staleResult.isCurrent, isFalse);
    expect(scheduleRefreshes, 1);
  });

  testWidgets('signed-out startup exposes usable login controls', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    final loginButton = find.widgetWithText(FilledButton, '统一身份认证登录');
    expect(tester.widget<FilledButton>(loginButton).onPressed, isNotNull);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.widget<FilledButton>(loginButton).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(TextButton, '了解详情'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'cached identity opens home and expired session permits re-login',
    (tester) async {
      await pumpApp(tester, username: 'cached-student');

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(AppShell), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.textContaining('cached-student'), findsOneWidget);

      final homeContext = tester.element(find.byType(HomeScreen));
      final router = GoRouter.of(homeContext);
      router.go(Routes.login);
      await _pumpRouteTransition(tester);
      expect(router.routeInformationProvider.value.uri.path, Routes.home);
      expect(find.byType(LoginScreen), findsNothing);

      ProviderScope.containerOf(
        homeContext,
      ).read(authProvider.notifier).markSessionExpired();
      await _pumpRouteTransition(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      router.go(Routes.loginWithReturnTo(Routes.home));
      await _pumpRouteTransition(tester);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, Routes.login);
      expect(
        tester.widget<LoginScreen>(find.byType(LoginScreen)).returnTo,
        Routes.home,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'home toolbar pull gesture and desktop rail share complete refresh',
    (tester) async {
      var contentRefreshes = 0;
      var scheduleRefreshes = 0;
      final refreshActions = HomeRefreshActions(
        refreshContent: () async {
          contentRefreshes++;
          return const SyncState(status: SyncStatus.success, updatedCount: 3);
        },
        refreshSchedule: () async {
          scheduleRefreshes++;
          return false;
        },
      );
      await pumpApp(
        tester,
        username: 'cached-student',
        size: const Size(390, 844),
        homeRefreshActions: refreshActions,
      );

      await tester.tap(find.byTooltip('刷新全部内容和课表'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(contentRefreshes, 1);
      expect(scheduleRefreshes, 1);
      expect(find.text('已更新 3 项；课表刷新失败'), findsOneWidget);
      expect(find.textContaining('同步完成'), findsNothing);

      await tester.drag(
        find.byKey(const PageStorageKey('home_scroll_view')),
        const Offset(0, 320),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(contentRefreshes, 2);
      expect(scheduleRefreshes, 2);

      tester.view.physicalSize = const Size(1000, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('刷新全部内容和课表'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(contentRefreshes, 3);
      expect(scheduleRefreshes, 3);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

Future<void> _pumpRouteTransition(WidgetTester tester) async {
  // The home screen can keep animating while cache-backed streams initialize.
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
  await tester.pump();
}

class _UnusedAuthSessionRepository implements AuthSessionRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Bootstrapped routes must not restore or mutate a session',
  );
}

class _OfflineConnectivity extends StateNotifier<ConnectivityState>
    implements ConnectivityNotifier {
  _OfflineConnectivity()
    : super(const ConnectivityState(status: NetworkStatus.offline));
}

class _IdleSync extends StateNotifier<SyncState> implements SyncNotifier {
  _IdleSync() : super(const SyncState());

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('App route tests must not perform synchronization');
}
