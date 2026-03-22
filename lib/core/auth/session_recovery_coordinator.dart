import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
import '../providers/auth_preferences_provider.dart';
import 'auth_relogin_service.dart';
import 'sso_session_recovery_service.dart';

enum SessionRecoveryMethod { ssoCookie, secureCredential }

class SessionRecoveryResult {
  const SessionRecoveryResult._({
    required this.recovered,
    this.method,
  });

  const SessionRecoveryResult.success(SessionRecoveryMethod method)
    : this._(recovered: true, method: method);

  const SessionRecoveryResult.failed() : this._(recovered: false);

  final bool recovered;
  final SessionRecoveryMethod? method;
}

class SessionRecoveryCoordinator {
  SessionRecoveryCoordinator({
    required SsoSessionRecoveryService ssoRecoveryService,
    required AuthReloginService authReloginService,
    required bool Function() isAutoReloginEnabled,
  }) : _ssoRecoveryService = ssoRecoveryService,
       _authReloginService = authReloginService,
       _isAutoReloginEnabled = isAutoReloginEnabled;

  final SsoSessionRecoveryService _ssoRecoveryService;
  final AuthReloginService _authReloginService;
  final bool Function() _isAutoReloginEnabled;

  Future<SessionRecoveryResult>? _inFlightRecovery;

  Future<SessionRecoveryResult> recoverSession({
    required Learn2018Helper apiClient,
  }) {
    final inFlight = _inFlightRecovery;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _runRecovery(apiClient);
    _inFlightRecovery = future;
    future.whenComplete(() {
      if (identical(_inFlightRecovery, future)) {
        _inFlightRecovery = null;
      }
    });
    return future;
  }

  Future<SessionRecoveryResult> _runRecovery(Learn2018Helper apiClient) async {
    try {
      if (await _ssoRecoveryService.tryRecover(apiClient)) {
        return const SessionRecoveryResult.success(
          SessionRecoveryMethod.ssoCookie,
        );
      }

      if (!_isAutoReloginEnabled()) {
        return const SessionRecoveryResult.failed();
      }

      if (await _authReloginService.tryRelogin(apiClient)) {
        return const SessionRecoveryResult.success(
          SessionRecoveryMethod.secureCredential,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Session recovery failed: $error');
      debugPrint('$stackTrace');
    }

    return const SessionRecoveryResult.failed();
  }
}

final sessionRecoveryCoordinatorProvider =
    Provider<SessionRecoveryCoordinator>((ref) {
      return SessionRecoveryCoordinator(
        ssoRecoveryService: ref.watch(ssoSessionRecoveryServiceProvider),
        authReloginService: ref.watch(authReloginServiceProvider),
        isAutoReloginEnabled: () => ref.read(autoReloginEnabledProvider),
      );
    });
