import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
import '../api/learning_read_api.dart';
import '../auth/session_recovery_coordinator.dart';
import '../auth/credential_vault.dart';
import '../auth/auth_controller.dart';
import '../api/enums.dart';
import '../api/models.dart';
import 'app_providers.dart';
import 'auth_preferences_provider.dart';

/// Session-aware API client backed by the persisted cookie jar.
///
/// The client first tries the current session cookies. When a request detects
/// an expired learn session, it delegates recovery to the centralized session
/// recovery coordinator, which may attempt cookie-based SSO recovery and then
/// opt-in secure re-login.
final Provider<Learn2018Helper> apiClientProvider = Provider<Learn2018Helper>((ref) {
  final jar = ref.watch(cookieJarProvider);
  final coordinator = ref.watch(sessionRecoveryCoordinatorProvider);

  late final Learn2018Helper helper;
  helper = Learn2018Helper(
    config: HelperConfig(
      cookieJar: jar,
      onCampusVerificationChanged: (required) {
        if (ref.read(authProvider).canAccessCachedData) {
          ref.read(campusIdentityVerificationRequiredProvider.notifier).state =
              required;
        }
      },
      campusCredentialProvider: () async {
        if (!ref.read(autoReloginEnabledProvider)) {
          throw const ApiError(reason: FailReason.noCredential);
        }
        final credential = await ref.read(credentialVaultProvider).read();
        if (credential == null) {
          throw const ApiError(reason: FailReason.noCredential);
        }
        return Credential(
          username: credential.username,
          password: credential.password,
          fingerPrint: credential.fingerPrint,
          fingerGenPrint: credential.fingerGenPrint,
          fingerGenPrint3: credential.fingerGenPrint3,
          deviceName: credential.deviceName,
          singleLoginEnabled: credential.singleLoginEnabled,
        );
      },
      sessionRecoveryHandler: () async {
        final result = await coordinator.recoverSession(apiClient: helper);
        return result.recovered;
      },
    ),
  );
  return helper;
});

final learningReadApiProvider = Provider<LearningReadApi>((ref) {
  return ref.watch(apiClientProvider);
});
