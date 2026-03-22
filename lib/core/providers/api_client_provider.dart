import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
import '../auth/session_recovery_coordinator.dart';
import 'app_providers.dart';

/// Session-aware API client backed by the persisted cookie jar.
///
/// The client first tries the current session cookies. When a request detects
/// an expired learn session, it delegates recovery to the centralized session
/// recovery coordinator, which may attempt cookie-based SSO recovery and then
/// opt-in secure re-login.
final apiClientProvider = Provider<Learn2018Helper>((ref) {
  final jar = ref.watch(cookieJarProvider);
  final coordinator = ref.watch(sessionRecoveryCoordinatorProvider);

  late final Learn2018Helper helper;
  helper = Learn2018Helper(
    config: HelperConfig(
      cookieJar: jar,
      sessionRecoveryHandler: () async {
        final result = await coordinator.recoverSession(apiClient: helper);
        return result.recovered;
      },
    ),
  );
  return helper;
});
