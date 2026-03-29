import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_relogin_models.dart';
import '../database/app_state_keys.dart';
import '../database/database.dart';
import 'app_providers.dart';

class AutoReloginPreferenceNotifier extends StateNotifier<bool> {
  AutoReloginPreferenceNotifier(this._db, {required bool initialEnabled})
    : super(initialEnabled);

  final AppDatabase _db;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    if (enabled) {
      await _db.setState(AppStateKeys.autoReloginEnabled, 'true');
      return;
    }
    await _db.deleteState(AppStateKeys.autoReloginEnabled);
  }
}

final autoReloginEnabledProvider =
    StateNotifierProvider<AutoReloginPreferenceNotifier, bool>((ref) {
      return AutoReloginPreferenceNotifier(
        ref.watch(databaseProvider),
        initialEnabled: ref.watch(initialAutoReloginEnabledProvider),
      );
    });

class AutoReloginStatusNotifier
    extends StateNotifier<AutoReloginStatusSnapshot> {
  AutoReloginStatusNotifier(this._db)
    : super(const AutoReloginStatusSnapshot.loading()) {
    _loadFuture = _load();
  }

  final AppDatabase _db;
  late final Future<void> _loadFuture;

  Future<void> _load() async {
    try {
      final raw = await _db.getState(AppStateKeys.autoReloginStatus);
      state = AutoReloginStatusSnapshot.fromJsonString(raw);
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Failed to load auto relogin status: $error');
      debugPrint('$stackTrace');
      state = const AutoReloginStatusSnapshot.disabled();
    }
  }

  Future<void> recordVerified() async {
    await _awaitLoaded();
    return _persist(state.markVerified(DateTime.now()));
  }

  Future<void> recordRecoverySuccess(SessionRecoveryMethod method) async {
    await _awaitLoaded();
    return _persist(state.markRecoverySuccess(method, DateTime.now()));
  }

  Future<void> recordFailureResult(
    AuthReloginResult result, {
    required AutoReloginFailureSource source,
  }) async {
    if (result.succeeded) {
      return Future<void>.value();
    }
    await _awaitLoaded();
    return _persist(
      state.markFailure(
        stage: result.failureStage ?? AuthReloginFailureStage.unknown,
        source: source,
        reason: result.reason,
        at: DateTime.now(),
      ),
    );
  }

  Future<void> recordDisabled() async {
    await _awaitLoaded();
    return _persist(state.markDisabled());
  }

  Future<void> reset() async {
    await _awaitLoaded();
    return _persist(state.reset());
  }

  Future<void> _awaitLoaded() async {
    try {
      await _loadFuture;
    } catch (_) {
      // _load() already logged and downgraded state to disabled.
    }
  }

  Future<void> _persist(AutoReloginStatusSnapshot next) async {
    state = next;
    try {
      await _db.setState(AppStateKeys.autoReloginStatus, next.toJsonString());
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Failed to persist auto relogin status: $error');
      debugPrint('$stackTrace');
    }
  }
}

final autoReloginStatusProvider =
    StateNotifierProvider<AutoReloginStatusNotifier, AutoReloginStatusSnapshot>(
      (ref) {
        return AutoReloginStatusNotifier(ref.watch(databaseProvider));
      },
    );
