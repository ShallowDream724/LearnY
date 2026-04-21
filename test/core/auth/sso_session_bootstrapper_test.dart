import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/api.dart';
import 'package:learn_y/core/auth/sso_cookie_bridge.dart';
import 'package:learn_y/core/auth/sso_fallback_page_parser.dart';
import 'package:learn_y/core/auth/sso_session_bootstrapper.dart';

void main() {
  group('SsoSessionBootstrapper', () {
    test('fallback bootstrap verifies session via getUserInfo', () async {
      final api = _FakeLearnApi(
        userInfo: const UserInfo(name: '接口用户名', department: '行健书院'),
      );
      final cookieBridge = _RecordingCookieBridge();
      final bootstrapper = SsoSessionBootstrapper(api, cookieBridge);

      final username = await bootstrapper.establishFallbackSession(
        pageSnapshot: const SsoFallbackPageSnapshot(
          csrfToken: 'csrf-token',
          username: '页面用户名',
        ),
        cookieString: 'SESSION=abc123',
      );

      expect(username, '接口用户名');
      expect(api.csrfToken, 'csrf-token');
      expect(api.getUserInfoCallCount, 1);
      expect(cookieBridge.cookieHeaders, ['SESSION=abc123']);
    });

    test(
      'fallback bootstrap fails when no cookie header is available',
      () async {
        final api = _FakeLearnApi(
          userInfo: const UserInfo(name: '接口用户名', department: '行健书院'),
        );
        final bootstrapper = SsoSessionBootstrapper(
          api,
          _RecordingCookieBridge(),
        );

        expect(
          () => bootstrapper.establishFallbackSession(
            pageSnapshot: const SsoFallbackPageSnapshot(
              csrfToken: 'csrf-token',
              username: '页面用户名',
            ),
            cookieString: '   ',
          ),
          throwsA(
            isA<ApiError>().having(
              (error) => error.reason,
              'reason',
              FailReason.notLoggedIn,
            ),
          ),
        );
      },
    );
  });
}

class _FakeLearnApi extends Learn2018Helper {
  _FakeLearnApi({required this.userInfo});

  final UserInfo userInfo;
  String csrfToken = '';
  int getUserInfoCallCount = 0;

  @override
  void setCSRFToken(String token) {
    csrfToken = token;
  }

  @override
  Future<UserInfo> getUserInfo([
    CourseType courseType = CourseType.student,
  ]) async {
    getUserInfoCallCount++;
    return userInfo;
  }
}

class _RecordingCookieBridge extends SsoCookieBridge {
  _RecordingCookieBridge() : super(Learn2018Helper());

  final List<String> cookieHeaders = <String>[];

  @override
  Future<void> transferWebViewCookiesToDio(String cookieString) async {
    cookieHeaders.add(cookieString);
  }
}
