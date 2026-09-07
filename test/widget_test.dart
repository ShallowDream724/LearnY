import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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

  Future<void> pumpApp(WidgetTester tester, {String? username}) async {
    await tester.binding.setSurfaceSize(const Size(1000, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
            (ref) => Stream.value(
              ScheduleState(
                semesterId: null,
                snapshot: HomeScheduleSnapshot(
                  days: buildHomeScheduleDays(DateTime(2026, 1, 1)),
                  itemsByDateKey: const {},
                ),
              ),
            ),
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

  testWidgets('signed-out startup exposes usable login controls', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(AppShell), findsNothing);
    final loginButton = find.widgetWithText(ElevatedButton, '统一身份认证登录');
    expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNotNull);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    expect(tester.widget<ElevatedButton>(loginButton).onPressed, isNotNull);

    await tester.tap(find.widgetWithText(TextButton, '了解详情'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
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
