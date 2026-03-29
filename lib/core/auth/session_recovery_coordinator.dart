import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
import '../providers/auth_preferences_provider.dart';
import 'auth_relogin_models.dart';
import 'auth_relogin_service.dart';
import 'sso_session_recovery_service.dart';

enum SessionRecoveryFailureStage {
  ssoCookieRecovery,
  autoReloginDisabled,
  secureCredentialRecovery,
}

class SessionRecoveryResult {
  const SessionRecoveryResult._({
    required this.recovered,
    this.method,
    this.failureStage,
    this.reloginResult,
  });

  const SessionRecoveryResult.success(SessionRecoveryMethod method)
    : this._(recovered: true, method: method);

  const SessionRecoveryResult.failed({
    SessionRecoveryFailureStage? failureStage,
    AuthReloginResult? reloginResult,
  }) : this._(
         recovered: false,
         failureStage: failureStage,
         reloginResult: reloginResult,
       );

  final bool recovered;
  final SessionRecoveryMethod? method;
  final SessionRecoveryFailureStage? failureStage;
  final AuthReloginResult? reloginResult;

  String sessionExpiredMessage({String? fallbackMessage}) {
    if (recovered) {
      return '会话已恢复';
    }
    if (reloginResult != null) {
      return reloginResult!.sessionExpiredMessage;
    }
    if (failureStage == SessionRecoveryFailureStage.autoReloginDisabled) {
      return '会话已过期，可继续查看缓存数据';
    }
    return fallbackMessage ?? '会话已过期，可继续查看缓存数据';
  }
}

class SessionRecoveryCoordinator {
  SessionRecoveryCoordinator({
    required SsoSessionRecoveryService ssoRecoveryService,
    required AuthReloginService authReloginService,
    required bool Function() isAutoReloginEnabled,
    required Future<void> Function(SessionRecoveryMethod method) onRecoverySuccess,
    required Future<void> Function(AuthReloginResult result)
    onSecureReloginFailure,
  }) : _ssoRecoveryService = ssoRecoveryService,
       _authReloginService = authReloginService,
       _isAutoReloginEnabled = isAutoReloginEnabled,
       _onRecoverySuccess = onRecoverySuccess,
       _onSecureReloginFailure = onSecureReloginFailure;

  final SsoSessionRecoveryService _ssoRecoveryService;
  final AuthReloginService _authReloginService;
  final bool Function() _isAutoReloginEnabled;
  final Future<void> Function(SessionRecoveryMethod method) _onRecoverySuccess;
  final Future<void> Function(AuthReloginResult result) _onSecureReloginFailure;

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
        debugPrint('[LearnY] Session recovery succeeded via SSO cookie');
        await _onRecoverySuccess(SessionRecoveryMethod.ssoCookie);
        return const SessionRecoveryResult.success(
          SessionRecoveryMethod.ssoCookie,
        );
      }
      debugPrint('[LearnY] Session recovery via SSO cookie did not restore session');
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Session recovery via SSO cookie failed: $error');
      debugPrint('$stackTrace');
    }

    if (!_isAutoReloginEnabled()) {
      debugPrint(
        '[LearnY] Session recovery skipped secure relogin: feature disabled',
      );
      return const SessionRecoveryResult.failed(
        failureStage: SessionRecoveryFailureStage.autoReloginDisabled,
      );
    }

    try {
      final reloginResult = await _authReloginService.tryRelogin(apiClient);
      if (reloginResult.succeeded) {
        debugPrint(
          '[LearnY] Session recovery succeeded via secure credential relogin',
        );
        await _onRecoverySuccess(SessionRecoveryMethod.secureCredential);
        return const SessionRecoveryResult.success(
          SessionRecoveryMethod.secureCredential,
        );
      }
      await _onSecureReloginFailure(reloginResult);
      return SessionRecoveryResult.failed(
        failureStage: SessionRecoveryFailureStage.secureCredentialRecovery,
        reloginResult: reloginResult,
      );
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Session recovery failed: $error');
      debugPrint('$stackTrace');
      final reloginResult = AuthReloginResult.fromError(error);
      await _onSecureReloginFailure(reloginResult);
      return SessionRecoveryResult.failed(
        failureStage: SessionRecoveryFailureStage.secureCredentialRecovery,
        reloginResult: reloginResult,
      );
    }
  }
}

final sessionRecoveryCoordinatorProvider = Provider<SessionRecoveryCoordinator>(
  (ref) {
    return SessionRecoveryCoordinator(
      ssoRecoveryService: ref.watch(ssoSessionRecoveryServiceProvider),
      authReloginService: ref.watch(authReloginServiceProvider),
      isAutoReloginEnabled: () => ref.read(autoReloginEnabledProvider),
      onRecoverySuccess: (method) {
        return ref
            .read(autoReloginStatusProvider.notifier)
            .recordRecoverySuccess(method);
      },
      onSecureReloginFailure: (result) {
        return ref
            .read(autoReloginStatusProvider.notifier)
            .recordFailureResult(
              result,
              source: AutoReloginFailureSource.sessionRecovery,
            );
      },
    );
  },
);
