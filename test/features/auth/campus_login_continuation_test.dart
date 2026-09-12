import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/registrar_calendar_api.dart';
import 'package:learn_y/features/auth/widgets/campus_login_continuation.dart';
import 'package:learn_y/features/auth/widgets/identity_auth_web_surface.dart';

void main() {
  test(
    'school verification continues in the login browser and returns automatically',
    () async {
      final api = _CampusApi();
      addTearDown(() => api.dio.close());
      final surface = _Surface();
      var requestedInteraction = false;
      final flow = CampusLoginContinuation(
        api: api,
        surface: surface,
        onInteractionRequired: () => requestedInteraction = true,
      );
      final login = flow.prepare();
      await surface.navigation.future;
      expect(requestedInteraction, isTrue);
      expect(flow.isActive, isTrue);
      expect(surface.destination, 'https://webvpn.tsinghua.edu.cn/login');
      expect(api.recoveryModes, [true]);
      api.verified = true;
      await flow.onPageFinished('https://webvpn.tsinghua.edu.cn/');
      await login;
      expect(flow.isActive, isFalse);
      final cookies = await api.cookieJar.loadForRequest(
        Uri.https('webvpn.tsinghua.edu.cn'),
      );
      expect(cookies.single.value, 'verified');
      expect(api.recoveryModes, [true, false]);
      final oauthCookies = await api.cookieJar.loadForRequest(
        Uri.https('oauth.tsinghua.edu.cn'),
      );
      expect(oauthCookies.single.value, 'verified');
      flow.dispose();
    },
  );

  test('closing login during school verification cancels completion', () async {
    final api = _CampusApi();
    addTearDown(() => api.dio.close());
    final surface = _Surface();
    final flow = CampusLoginContinuation(
      api: api,
      surface: surface,
      onInteractionRequired: () {},
    );
    final login = flow.prepare();
    await surface.navigation.future;
    final cancelled = expectLater(login, throwsStateError);
    flow.dispose();
    await cancelled;
  });
}

class _CampusApi extends Learn2018Helper {
  bool verified = false;
  final recoveryModes = <bool>[];
  @override
  Future<void> establishCampusSession({
    bool allowCredentialRecovery = true,
  }) async {
    recoveryModes.add(allowCredentialRecovery);
    if (!verified) {
      throw RegistrarException(
        RegistrarFailure.identityVerification,
        loginUri: Uri.parse(
          'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
        ),
        browserEntryUri: Uri.https('webvpn.tsinghua.edu.cn', '/login'),
      );
    }
  }
}

class _Surface implements IdentityAuthWebSurfaceController {
  final navigation = Completer<void>();
  String? destination;
  @override
  Future<void> loadUrl(String url) async {
    destination = url;
    navigation.complete();
  }

  @override
  Future<String?> getCookieHeaderForUrl(String url) async => 'session=verified';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
