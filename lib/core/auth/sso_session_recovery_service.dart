import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';

class SsoSessionRecoveryService {
  const SsoSessionRecoveryService();

  Future<bool> tryRecover(Learn2018Helper apiClient) {
    return apiClient.attemptSilentSessionRecovery();
  }
}

final ssoSessionRecoveryServiceProvider = Provider<SsoSessionRecoveryService>((
  ref,
) {
  return const SsoSessionRecoveryService();
});
