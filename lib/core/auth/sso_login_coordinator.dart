import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';
import 'sso_fallback_page_parser.dart';
import 'sso_session_bootstrapper.dart';

class SsoLoginCoordinator {
  final SsoSessionBootstrapper _sessionBootstrapper;
  final AuthController _authController;

  const SsoLoginCoordinator(this._sessionBootstrapper, this._authController);

  Future<void> consumeTicket(String ticket) async {
    final username = await _sessionBootstrapper.establishSessionFromTicket(
      ticket,
    );
    await _authController.onLoginSuccess(username);
  }

  Future<void> completeFallbackLogin({
    required SsoFallbackPageSnapshot pageSnapshot,
    required String cookieString,
  }) async {
    final username = await _sessionBootstrapper.establishFallbackSession(
      pageSnapshot: pageSnapshot,
      cookieString: cookieString,
    );
    await _authController.onLoginSuccess(username);
  }
}

final ssoLoginCoordinatorProvider = Provider<SsoLoginCoordinator>((ref) {
  return SsoLoginCoordinator(
    ref.watch(ssoSessionBootstrapperProvider),
    ref.read(authProvider.notifier),
  );
});
