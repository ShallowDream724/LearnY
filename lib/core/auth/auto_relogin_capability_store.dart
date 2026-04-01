import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_preferences_provider.dart';
import 'auth_relogin_models.dart';
import 'auth_relogin_service.dart';
import 'credential_vault.dart';

class AutoReloginCapabilityStore {
  AutoReloginCapabilityStore({
    required AutoReloginPreferenceNotifier preferenceNotifier,
    required AutoReloginStatusNotifier statusNotifier,
    required AuthReloginService authReloginService,
    required void Function() invalidateStoredCredentialAvailability,
  }) : _preferenceNotifier = preferenceNotifier,
       _statusNotifier = statusNotifier,
       _authReloginService = authReloginService,
       _invalidateStoredCredentialAvailability =
           invalidateStoredCredentialAvailability;

  final AutoReloginPreferenceNotifier _preferenceNotifier;
  final AutoReloginStatusNotifier _statusNotifier;
  final AuthReloginService _authReloginService;
  final void Function() _invalidateStoredCredentialAvailability;

  Future<void> markProbeStarted() {
    return _statusNotifier.recordProbeStarted();
  }

  Future<void> markReady({
    required bool trustedBrowserReady,
    AutoReloginProbeMethod probeMethod =
        AutoReloginProbeMethod.secureCredential,
  }) async {
    await _preferenceNotifier.setEnabled(true);
    await _statusNotifier.recordEnrollmentSuccess(
      probeMethod: probeMethod,
      trustedBrowserReady: trustedBrowserReady,
    );
    _invalidateStoredCredentialAvailability();
  }

  Future<void> recordRecoverySuccess(SessionRecoveryMethod method) {
    return _statusNotifier.recordRecoverySuccess(method);
  }

  Future<void> recordFailure(
    AuthReloginResult result, {
    required AutoReloginFailureSource source,
  }) async {
    await _statusNotifier.recordFailureResult(result, source: source);
    _invalidateStoredCredentialAvailability();
  }

  Future<void> disable() async {
    await _authReloginService.clearStoredCredential();
    await _preferenceNotifier.setEnabled(false);
    await _statusNotifier.recordDisabled();
    _invalidateStoredCredentialAvailability();
  }

  Future<void> reset() async {
    await _authReloginService.clearStoredCredential();
    await _preferenceNotifier.setEnabled(false);
    await _statusNotifier.reset();
    _invalidateStoredCredentialAvailability();
  }
}

final autoReloginCapabilityStoreProvider = Provider<AutoReloginCapabilityStore>(
  (ref) {
    return AutoReloginCapabilityStore(
      preferenceNotifier: ref.read(autoReloginEnabledProvider.notifier),
      statusNotifier: ref.read(autoReloginStatusProvider.notifier),
      authReloginService: ref.watch(authReloginServiceProvider),
      invalidateStoredCredentialAvailability: () {
        ref.invalidate(storedCredentialAvailabilityProvider);
      },
    );
  },
);
