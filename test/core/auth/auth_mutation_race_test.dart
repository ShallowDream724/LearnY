import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/providers.dart';

void main() {
  test(
    'account API replacement does not dispose login or logout owner',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          didBootstrapAppSessionProvider.overrideWithValue(true),
          initialAuthUsernameProvider.overrideWithValue('student'),
          autoReloginCapabilityStoreProvider.overrideWithValue(
            NoopCapabilityStore(),
          ),
          apiClientProvider.overrideWith((ref) {
            ref.watch(dataSessionEpochProvider);
            final api = _LogoutApi();
            ref.onDispose(() => api.dio.close());
            return api;
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final auth = container.read(authProvider.notifier);
      final firstApi = container.read(apiClientProvider);
      final login = auth.onLoginSuccess('student');
      expect(container.read(apiClientProvider), isNot(same(firstApi)));
      expect(container.read(authProvider.notifier), same(auth));
      await login;
      expect(container.read(authProvider).isLoggedIn, isTrue);
      expect(await db.getState(AppStateKeys.username), 'student');

      final logout = auth.logout();
      expect(container.read(authProvider.notifier), same(auth));
      await logout;
      expect(container.read(authProvider).isSignedOut, isTrue);
      expect(await db.getState(AppStateKeys.username), isNull);
    },
  );

  test(
    'logout queued during login wins in memory and persisted identity',
    () async {
      final fixture = AuthFixture();
      addTearDown(fixture.dispose);
      fixture.repository.loginGate = Completer<void>();
      final login = fixture.auth.onLoginSuccess('new-owner');
      await fixture.repository.loginStarted.future;
      final logout = fixture.auth.logout();
      fixture.repository.loginGate!.complete();
      await Future.wait([login, logout]);
      expect(fixture.container.read(authProvider).isSignedOut, isTrue);
      expect(await fixture.db.getState(AppStateKeys.username), isNull);
      expect(fixture.container.read(currentSemesterIdProvider), isNull);
    },
  );

  test('login queued during logout wins after cleanup completes', () async {
    final fixture = AuthFixture();
    addTearDown(fixture.dispose);
    fixture.repository.logoutGate = Completer<void>();
    final logout = fixture.auth.logout();
    await fixture.repository.logoutStarted.future;
    final login = fixture.auth.onLoginSuccess('new-owner');
    fixture.repository.logoutGate!.complete();
    await Future.wait([logout, login]);
    expect(fixture.container.read(authProvider).isLoggedIn, isTrue);
    expect(fixture.container.read(authProvider).username, 'new-owner');
    expect(await fixture.db.getState(AppStateKeys.username), 'new-owner');
  });
}

class AuthFixture {
  AuthFixture() {
    repository = DelayedSessionRepository(db);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        didBootstrapAppSessionProvider.overrideWithValue(true),
        initialAuthUsernameProvider.overrideWithValue('old-owner'),
        initialCurrentSemesterIdProvider.overrideWithValue('2026-2027-1'),
        authSessionRepositoryProvider.overrideWithValue(repository),
        autoReloginCapabilityStoreProvider.overrideWithValue(
          NoopCapabilityStore(),
        ),
      ],
    );
  }
  final db = AppDatabase(NativeDatabase.memory());
  late final DelayedSessionRepository repository;
  late final ProviderContainer container;
  AuthController get auth => container.read(authProvider.notifier);
  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

class DelayedSessionRepository implements AuthSessionRepository {
  DelayedSessionRepository(this.db);
  final AppDatabase db;
  Completer<void>? loginGate;
  Completer<void>? logoutGate;
  final loginStarted = Completer<void>();
  final logoutStarted = Completer<void>();
  @override
  Future<void> persistAuthenticatedUser(String username) async {
    loginStarted.complete();
    await loginGate?.future;
    await db.setState(AppStateKeys.username, username);
  }

  @override
  Future<void> logout() async {
    logoutStarted.complete();
    await logoutGate?.future;
    await db.deleteState(AppStateKeys.username);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class NoopCapabilityStore implements AutoReloginCapabilityStore {
  @override
  Future<void> reset() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _LogoutApi extends Learn2018Helper {
  @override
  Future<void> logout() async {}
}
