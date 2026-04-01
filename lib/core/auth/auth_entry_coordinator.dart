import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'auth_entry_models.dart';
import 'auth_relogin_models.dart';
import 'auth_relogin_service.dart';
import 'auto_relogin_capability_store.dart';
import 'sso_fallback_page_parser.dart';
import 'sso_session_bootstrapper.dart';

class AuthEntryCoordinator {
  AuthEntryCoordinator({
    required SsoSessionBootstrapper sessionBootstrapper,
    required AuthReloginService authReloginService,
    required AutoReloginCapabilityStore autoReloginCapabilityStore,
    required Future<void> Function(String username) onLoginSuccess,
  }) : _sessionBootstrapper = sessionBootstrapper,
       _authReloginService = authReloginService,
       _autoReloginCapabilityStore = autoReloginCapabilityStore,
       _onLoginSuccess = onLoginSuccess;

  final SsoSessionBootstrapper _sessionBootstrapper;
  final AuthReloginService _authReloginService;
  final AutoReloginCapabilityStore _autoReloginCapabilityStore;
  final Future<void> Function(String username) _onLoginSuccess;

  Future<AuthEntryResult> consumeTicket({
    required AuthEntryRequest request,
    required String ticket,
    AutoReloginEnrollmentPayload? enrollmentPayload,
  }) async {
    final username = await _sessionBootstrapper.establishSessionFromTicket(
      ticket,
    );
    return _finishRequest(
      request: request,
      username: username,
      enrollmentPayload: enrollmentPayload,
    );
  }

  Future<AuthEntryResult> completeFallback({
    required AuthEntryRequest request,
    required SsoFallbackPageSnapshot pageSnapshot,
    required String cookieString,
    AutoReloginEnrollmentPayload? enrollmentPayload,
  }) async {
    final username = await _sessionBootstrapper.establishFallbackSession(
      pageSnapshot: pageSnapshot,
      cookieString: cookieString,
    );
    return _finishRequest(
      request: request,
      username: username,
      enrollmentPayload: enrollmentPayload,
    );
  }

  Future<AuthEntryResult> configureAutoReloginForExistingSession({
    required String username,
    AutoReloginEnrollmentPayload? enrollmentPayload,
  }) async {
    final outcome = await _configureAutoRelogin(enrollmentPayload);
    return AuthEntryResult(
      username: username,
      autoReloginConfigured: outcome.configured,
      noticeMessage: outcome.noticeMessage,
    );
  }

  Future<AuthEntryResult> _finishRequest({
    required AuthEntryRequest request,
    required String username,
    AutoReloginEnrollmentPayload? enrollmentPayload,
  }) async {
    String? noticeMessage;
    var autoReloginConfigured = false;

    if (request.requiresAutoRelogin) {
      final outcome = await _configureAutoRelogin(enrollmentPayload);
      autoReloginConfigured = outcome.configured;
      noticeMessage = outcome.noticeMessage;
    }

    await _onLoginSuccess(username);

    return AuthEntryResult(
      username: username,
      autoReloginConfigured: autoReloginConfigured,
      noticeMessage: noticeMessage,
    );
  }

  Future<_AutoReloginEnrollmentOutcome> _configureAutoRelogin(
    AutoReloginEnrollmentPayload? payload,
  ) async {
    await _autoReloginCapabilityStore.markProbeStarted();

    if (payload == null || !payload.hasReusableTrustedBrowserState) {
      const result = AuthReloginResult.failure(
        stage: AuthReloginFailureStage.trustedBrowserState,
      );
      await _autoReloginCapabilityStore.recordFailure(
        result,
        source: AutoReloginFailureSource.enrollment,
      );
      return _AutoReloginEnrollmentOutcome.failure(
        result.enrollmentFailureMessage,
      );
    }

    final result = await _authReloginService.saveEnrolledCredential(
      username: payload.username,
      password: payload.password,
      fingerPrint: payload.fingerPrint,
      fingerGenPrint: payload.resolvedFingerGenPrint,
      fingerGenPrint3: payload.resolvedFingerGenPrint3,
      deviceName: payload.deviceName,
      singleLoginEnabled: payload.singleLoginEnabled,
    );

    if (!result.succeeded) {
      await _autoReloginCapabilityStore.recordFailure(
        result,
        source: AutoReloginFailureSource.enrollment,
      );
      return _AutoReloginEnrollmentOutcome.failure(
        result.enrollmentFailureMessage,
      );
    }

    await _autoReloginCapabilityStore.markReady(
      trustedBrowserReady: payload.hasReusableTrustedBrowserState,
    );
    return const _AutoReloginEnrollmentOutcome.success();
  }
}

class _AutoReloginEnrollmentOutcome {
  const _AutoReloginEnrollmentOutcome._({
    required this.configured,
    this.noticeMessage,
  });

  const _AutoReloginEnrollmentOutcome.success() : this._(configured: true);

  const _AutoReloginEnrollmentOutcome.failure(String message)
    : this._(configured: false, noticeMessage: message);

  final bool configured;
  final String? noticeMessage;
}

final authEntryCoordinatorProvider = Provider<AuthEntryCoordinator>((ref) {
  return AuthEntryCoordinator(
    sessionBootstrapper: ref.watch(ssoSessionBootstrapperProvider),
    authReloginService: ref.watch(authReloginServiceProvider),
    autoReloginCapabilityStore: ref.watch(autoReloginCapabilityStoreProvider),
    onLoginSuccess: ref.read(authProvider.notifier).onLoginSuccess,
  );
});
