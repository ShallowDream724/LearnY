import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/app_session_coordinator.dart';
import 'package:learn_y/core/auth/auth_controller.dart';
import 'package:learn_y/core/providers/sync_models.dart';

void main() {
  group('AppSessionCoordinator', () {
    test(
      'schedules a foreground sync when restore yields cached identity',
      () async {
        final delegate = _FakeCoordinatorDelegate(
          authState: const AuthState.cached(username: 'demo'),
        );

        final coordinator = AppSessionCoordinator(
          delegate,
          postAuthSyncDelay: Duration.zero,
          scheduleTask: (delay, task) async => task(),
        );

        coordinator.handleAuthStateChanged(
          const AuthState.restoring(),
          const AuthState.cached(username: 'demo'),
        );

        expect(delegate.syncCalls, 1);
      },
    );

    test('does not foreground sync when cached session is expired', () async {
      final delegate = _FakeCoordinatorDelegate(
        authState: const AuthState.sessionExpired(username: 'demo'),
      );

      final coordinator = AppSessionCoordinator(
        delegate,
        postAuthSyncDelay: Duration.zero,
        scheduleTask: (delay, task) async => task(),
      );

      coordinator.handleAuthStateChanged(
        const AuthState.restoring(),
        const AuthState.sessionExpired(username: 'demo'),
      );

      expect(delegate.syncCalls, 0);
    });

    test('marks session healthy after successful sync', () {
      final delegate = _FakeCoordinatorDelegate(
        authState: const AuthState.cached(username: 'demo'),
      );
      final coordinator = AppSessionCoordinator(delegate);

      coordinator.handleSyncStateChanged(
        const SyncState(status: SyncStatus.syncing),
        const SyncState(status: SyncStatus.success),
      );

      expect(delegate.markHealthyCalls, 1);
      expect(delegate.markExpiredMessages, isEmpty);
    });

    test('marks session expired after sync reports expiry', () async {
      final delegate = _FakeCoordinatorDelegate(
        authState: const AuthState.authenticated(username: 'demo'),
      );
      final coordinator = AppSessionCoordinator(delegate);

      coordinator.handleSyncStateChanged(
        const SyncState(status: SyncStatus.syncing),
        const SyncState(
          status: SyncStatus.sessionExpired,
          errorMessage: 'cookie expired',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(delegate.recoveryCalls, 1);
      expect(delegate.markExpiredMessages, ['cookie expired']);
    });

    test(
      'syncs on resume only after threshold and only for healthy sessions',
      () async {
        var now = DateTime(2026, 3, 21, 12);
        final delegate = _FakeCoordinatorDelegate(
          authState: const AuthState.cached(username: 'demo'),
        );
        final coordinator = AppSessionCoordinator(
          delegate,
          now: () => now,
          resumeSyncThreshold: const Duration(minutes: 10),
        );

        coordinator.handleLifecycleStateChanged(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 9));
        coordinator.handleLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(delegate.syncCalls, 0);

        coordinator.handleLifecycleStateChanged(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 11));
        coordinator.handleLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(delegate.syncCalls, 1);

        delegate.authState = const AuthState.sessionExpired(username: 'demo');
        coordinator.handleLifecycleStateChanged(AppLifecycleState.paused);
        now = now.add(const Duration(minutes: 11));
        coordinator.handleLifecycleStateChanged(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(delegate.syncCalls, 1);
        expect(delegate.recoveryCalls, 1);
      },
    );

    test('recovers and re-syncs after session expiry when recovery succeeds', () async {
      final delegate = _FakeCoordinatorDelegate(
        authState: const AuthState.authenticated(username: 'demo'),
        recoveryResult: true,
      );
      final coordinator = AppSessionCoordinator(delegate);

      coordinator.handleSyncStateChanged(
        const SyncState(status: SyncStatus.syncing),
        const SyncState(
          status: SyncStatus.sessionExpired,
          errorMessage: 'cookie expired',
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(delegate.recoveryCalls, 1);
      expect(delegate.markHealthyCalls, 1);
      expect(delegate.syncCalls, 1);
      expect(delegate.markExpiredMessages, isEmpty);
    });
  });
}

class _FakeCoordinatorDelegate implements AppSessionCoordinatorDelegate {
  _FakeCoordinatorDelegate({
    required this.authState,
    this.recoveryResult = false,
  });

  @override
  AuthState authState;

  final bool recoveryResult;
  int syncCalls = 0;
  int markHealthyCalls = 0;
  int recoveryCalls = 0;
  final List<String?> markExpiredMessages = <String?>[];

  @override
  void markSessionExpired(String? message) {
    markExpiredMessages.add(message);
    authState = AuthState.sessionExpired(
      username: authState.username ?? 'demo',
      errorMessage: message,
    );
  }

  @override
  void markSessionHealthy() {
    markHealthyCalls++;
    authState = AuthState.authenticated(username: authState.username ?? 'demo');
  }

  @override
  Future<bool> recoverSession() async {
    recoveryCalls++;
    if (recoveryResult) {
      authState = AuthState.authenticated(username: authState.username ?? 'demo');
    }
    return recoveryResult;
  }

  @override
  Future<void> syncAll() async {
    syncCalls++;
  }
}
