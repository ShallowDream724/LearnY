import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
import '../api/urls.dart' as urls;
import '../providers/app_providers.dart';

class SsoCookieBridge {
  const SsoCookieBridge(this._api);

  final Learn2018Helper _api;

  Future<void> transferWebViewCookiesToDio(String cookieString) async {
    final normalized = cookieString.trim();
    if (normalized.isEmpty) {
      return;
    }

    final cookies = normalized.split(';').map((pair) {
      final parts = pair.trim().split('=');
      if (parts.length < 2) {
        return null;
      }
      return Cookie(parts[0].trim(), parts.sublist(1).join('=').trim());
    }).whereType<Cookie>();

    final learnUri = Uri.parse(urls.learnPrefix);
    final idUri = Uri.parse(urls.idPrefix);

    for (final cookie in cookies) {
      await _api.cookieJar.saveFromResponse(learnUri, [cookie]);
      await _api.cookieJar.saveFromResponse(idUri, [cookie]);
    }
  }
}

final ssoCookieBridgeProvider = Provider<SsoCookieBridge>((ref) {
  return SsoCookieBridge(ref.watch(apiClientProvider));
});
