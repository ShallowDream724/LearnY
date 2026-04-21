import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../providers/api_client_provider.dart';
import 'sso_cookie_bridge.dart';
import 'sso_fallback_page_parser.dart';

class SsoSessionBootstrapper {
  const SsoSessionBootstrapper(this._api, this._cookieBridge);

  final Learn2018Helper _api;
  final SsoCookieBridge _cookieBridge;

  Future<String> establishSessionFromTicket(String ticket) async {
    await _api.loginWithTicket(ticket);
    final userInfo = await _api.getUserInfo();
    return userInfo.name;
  }

  Future<String> establishFallbackSession({
    required SsoFallbackPageSnapshot pageSnapshot,
    required String cookieString,
  }) async {
    final normalizedCookieString = cookieString.trim();
    if (normalizedCookieString.isEmpty) {
      throw const ApiError(reason: FailReason.notLoggedIn);
    }

    _api.setCSRFToken(pageSnapshot.csrfToken);
    await _cookieBridge.transferWebViewCookiesToDio(normalizedCookieString);

    final userInfo = await _api.getUserInfo();
    final resolvedUsername = userInfo.name.trim();
    if (resolvedUsername.isNotEmpty) {
      return resolvedUsername;
    }

    final fallbackUsername = pageSnapshot.username.trim();
    if (fallbackUsername.isEmpty) {
      throw const ApiError(reason: FailReason.invalidResponse);
    }

    return fallbackUsername;
  }
}

final ssoSessionBootstrapperProvider = Provider<SsoSessionBootstrapper>((ref) {
  return SsoSessionBootstrapper(
    ref.watch(apiClientProvider),
    ref.watch(ssoCookieBridgeProvider),
  );
});
