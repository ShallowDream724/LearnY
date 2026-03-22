import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/api_client_provider.dart';
import '../providers/sync_provider.dart';
import 'auth_controller.dart';
import 'session_recovery_coordinator.dart';

typedef DelayedTaskScheduler =
    Future<void> Function(Duration delay, Future<void> Function() task);

abstract class AppSessionCoordinatorDelegate {
  AuthState get authState;

  void markSessionHealthy();
  void markSessionExpired(String? message);
  Future<bool> recoverSession();
  Future<void> syncAll();
}

class RiverpodAppSessionCoordinatorDelegate
    implements AppSessionCoordinatorDelegate {
  RiverpodAppSessionCoordinatorDelegate(this._ref);

  final Ref _ref;

  @override
  AuthState get authState => _ref.read(authProvider);

  @override
  void markSessionExpired(String? message) {
    _ref.read(authProvider.notifier).markSessionExpired(message);
  }

  @override
  void markSessionHealthy() {
    _ref.read(authProvider.notifier).markSessionHealthy();
  }

  @override
  Future<bool> recoverSession() async {
    final result = await _ref
        .read(sessionRecoveryCoordinatorProvider)
        .recoverSession(apiClient: _ref.read(apiClientProvider));
    return result.recovered;
  }

  @override
  Future<void> syncAll() {
    return _ref.read(syncStateProvider.notifier).syncAll();
  }
}

class AppSessionCoordinator {
  AppSessionCoordinator(
    this._delegate, {
    DateTime Function()? now,
    DelayedTaskScheduler? scheduleTask,
    this.resumeSyncThreshold = const Duration(minutes: 10),
    Duration postAuthSyncDelay = const Duration(milliseconds: 300),
  }) : _now = now ?? DateTime.now,
       _scheduleTask = scheduleTask ?? _defaultScheduleTask,
       _postAuthSyncDelay = postAuthSyncDelay;

  final AppSessionCoordinatorDelegate _delegate;
  final DateTime Function() _now;
  final DelayedTaskScheduler _scheduleTask;
  final Duration resumeSyncThreshold;
  final Duration _postAuthSyncDelay;

  DateTime? _pausedAt;
  bool _postAuthSyncScheduled = false;
  Future<void>? _recoveryTask;

  static Future<void> _defaultScheduleTask(
    Duration delay,
    Future<void> Function() task,
  ) async {
    await Future<void>.delayed(delay);
    await task();
  }

  void handleLifecycleStateChanged(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _pausedAt = _now();
        break;
      case AppLifecycleState.resumed:
        _syncOnResumeIfNeeded();
        break;
    }
  }

  void handleAuthStateChanged(AuthState? previous, AuthState next) {
    if (_sameAuthLifecycle(previous, next)) {
      return;
    }

    if (!_shouldScheduleForegroundSync(previous, next)) {
      _postAuthSyncScheduled = false;
      return;
    }

    if (_postAuthSyncScheduled) {
      return;
    }

    _postAuthSyncScheduled = true;
    _scheduleTask(_postAuthSyncDelay, () async {
      _postAuthSyncScheduled = false;
      await _runForegroundSyncIfEligible();
    });
  }

  void handleSyncStateChanged(SyncState? previous, SyncState next) {
    if (next.status == SyncStatus.success &&
        previous?.status != SyncStatus.success) {
      _delegate.markSessionHealthy();
      return;
    }

    if (next.status != SyncStatus.sessionExpired ||
        previous?.status == SyncStatus.sessionExpired) {
      return;
    }

    _triggerRecoveryAfterSyncFailure(next.errorMessage);
  }

  Future<void> _syncOnResumeIfNeeded() async {
    final pausedAt = _pausedAt;
    if (pausedAt == null) {
      return;
    }

    if (_now().difference(pausedAt) < resumeSyncThreshold) {
      return;
    }

    final auth = _delegate.authState;
    if (auth.requiresReauthentication) {
      await _recoverSession(resyncOnSuccess: true);
      return;
    }

    await _runForegroundSyncIfEligible();
  }

  Future<void> _runForegroundSyncIfEligible() async {
    final auth = _delegate.authState;
    if (!auth.canAccessCachedData || auth.requiresReauthentication) {
      return;
    }

    await _delegate.syncAll();
  }

  void _triggerRecoveryAfterSyncFailure(String? message) {
    _recoveryTask ??= _recoverSession(
      errorMessage: message,
      resyncOnSuccess: true,
    ).whenComplete(() {
      _recoveryTask = null;
    });
  }

  Future<void> _recoverSession({
    String? errorMessage,
    required bool resyncOnSuccess,
  }) async {
    final recovered = await _delegate.recoverSession();
    if (!recovered) {
      _delegate.markSessionExpired(errorMessage);
      return;
    }

    _delegate.markSessionHealthy();
    if (resyncOnSuccess) {
      await _delegate.syncAll();
    }
  }

  bool _shouldScheduleForegroundSync(AuthState? previous, AuthState next) {
    if (!next.canAccessCachedData || next.requiresReauthentication) {
      return false;
    }

    final hadCachedIdentity = previous?.canAccessCachedData ?? false;
    final wasRestoring = previous?.isRestoring ?? false;
    final wasExpired = previous?.requiresReauthentication ?? false;

    return !hadCachedIdentity || wasRestoring || wasExpired;
  }

  bool _sameAuthLifecycle(AuthState? previous, AuthState next) {
    if (previous == null) {
      return false;
    }

    return previous.restoreState == next.restoreState &&
        previous.username == next.username &&
        previous.sessionHealth == next.sessionHealth &&
        previous.errorMessage == next.errorMessage;
  }
}

final appSessionCoordinatorProvider = Provider<AppSessionCoordinator>((ref) {
  final delegate = RiverpodAppSessionCoordinatorDelegate(ref);
  final coordinator = AppSessionCoordinator(delegate);

  ref.listen<AuthState>(authProvider, coordinator.handleAuthStateChanged);
  ref.listen<SyncState>(syncStateProvider, coordinator.handleSyncStateChanged);

  return coordinator;
});
