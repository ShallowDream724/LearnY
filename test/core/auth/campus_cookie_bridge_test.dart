import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/campus_cookie_bridge.dart';

void main() {
  test(
    'imports gateway cookies on the correct host without replacing Learn credentials',
    () async {
      final jar = CookieJar();
      final learn = Uri.https('learn.tsinghua.edu.cn');
      final gateway = Uri.https('webvpn.tsinghua.edu.cn');
      await jar.saveFromResponse(learn, [Cookie('session', 'learn')]);
      await jar.saveFromResponse(gateway, [Cookie('stale', 'old')]);
      await jar.saveFromResponse(gateway, [
        Cookie('session', 'old-domain')
          ..domain = '.webvpn.tsinghua.edu.cn'
          ..path = '/',
      ]);
      await CampusCookieBridge(jar).importHeaders({
        gateway: 'session=campus; opaque=a=b',
        Uri.https('example.com'): 'unexpected=secret',
        Uri.http('oauth.tsinghua.edu.cn'): 'insecure=ignored',
      });
      expect((await jar.loadForRequest(learn)).single.value, 'learn');
      final cookies = await jar.loadForRequest(gateway);
      expect(
        {for (final cookie in cookies) cookie.name: cookie.value},
        {'session': 'campus', 'opaque': 'a=b'},
      );
      expect(await jar.loadForRequest(Uri.https('example.com')), isEmpty);
      expect(
        await jar.loadForRequest(Uri.https('oauth.tsinghua.edu.cn')),
        isEmpty,
      );
      expect(
        cookies.every((cookie) => cookie.secure && cookie.httpOnly),
        isTrue,
      );
    },
  );
}
