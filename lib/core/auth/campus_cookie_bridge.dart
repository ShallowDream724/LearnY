import 'package:cookie_jar/cookie_jar.dart';

/// Browser authorization remains scoped to its actual campus service host.
class CampusCookieBridge {
  CampusCookieBridge(this.jar);
  final CookieJar jar;
  static const hosts = {
    'webvpn.tsinghua.edu.cn',
    'oauth.tsinghua.edu.cn',
    'zhjw.cic.tsinghua.edu.cn',
  };

  Future<void> importHeaders(Map<Uri, String> headers) async {
    final byHost = <String, Map<String, Cookie>>{};
    for (final entry in headers.entries) {
      if (entry.key.scheme != 'https' || !hosts.contains(entry.key.host)) {
        continue;
      }
      final cookies = byHost.putIfAbsent(entry.key.host, () => {});
      for (final pair in entry.value.split(';')) {
        final separator = pair.indexOf('=');
        if (separator <= 0) continue;
        final name = pair.substring(0, separator).trim();
        final value = pair.substring(separator + 1).trim();
        if (name.isEmpty) continue;
        cookies[name] = Cookie(name, value)
          ..path = '/'
          ..secure = true
          ..httpOnly = true;
      }
    }
    if (byHost.values.every((cookies) => cookies.isEmpty)) return;
    for (final host in hosts) {
      final uri = Uri.https(host, '/');
      // Clear old host and service-domain variants without removing shared SSO.
      final shared = (await jar.loadForRequest(uri)).where((cookie) {
        final domain = cookie.domain?.replaceFirst(RegExp(r'^\.'), '');
        return domain != null && domain.isNotEmpty && domain != host;
      }).toList();
      await jar.delete(uri, true);
      if (shared.isNotEmpty) await jar.saveFromResponse(uri, shared);
    }
    for (final entry in byHost.entries) {
      if (entry.value.isEmpty) continue;
      final uri = Uri.https(entry.key, '/');
      await jar.saveFromResponse(uri, entry.value.values.toList());
    }
  }
}
