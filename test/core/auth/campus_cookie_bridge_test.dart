import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/campus_cookie_bridge.dart';

void main() {
  test('missing browser identity cannot erase an existing session', () async {
    final jar = CookieJar();
    final identity = Uri.https('id.tsinghua.edu.cn');
    await jar.saveFromResponse(identity, [Cookie('identity', 'current')]);
    expect(await CampusCookieBridge(jar).importIdentitySession(''), isFalse);
    expect((await jar.loadForRequest(identity)).single.value, 'current');
  });

  test(
    'normal login carries identity and removes previous service sessions',
    () async {
      final jar = CookieJar();
      final learn = Uri.https('learn.tsinghua.edu.cn');
      final identity = Uri.https('id.tsinghua.edu.cn');
      final gateway = Uri.https('webvpn.tsinghua.edu.cn');
      await jar.saveFromResponse(learn, [Cookie('learn', 'current')]);
      await jar.saveFromResponse(identity, [Cookie('identity', 'previous')]);
      await jar.saveFromResponse(gateway, [Cookie('gateway', 'previous')]);

      await CampusCookieBridge(
        jar,
      ).importIdentitySession('identity=current; token=a=b');

      expect((await jar.loadForRequest(learn)).single.value, 'current');
      expect(await jar.loadForRequest(gateway), isEmpty);
      expect(
        {
          for (final cookie in await jar.loadForRequest(identity))
            cookie.name: cookie.value,
        },
        {'identity': 'current', 'token': 'a=b'},
      );
    },
  );

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
