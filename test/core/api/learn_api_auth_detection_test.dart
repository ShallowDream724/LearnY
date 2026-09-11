import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/enums.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart';
import 'package:learn_y/core/api/urls.dart' as urls;

void main() {
  group('learn auth page detection', () {
    test('recognizes the school HTTP 200 expiry and wrapped 403 pages', () {
      for (final page in [_expiredPage, _forbiddenPage]) {
        expect(looksLikeLearnSessionExpiredPage(page), isTrue);
        expect(
          isAuthenticatedLearnPage(
            pageUri: Uri.parse(urls.learnStudentCourseListPage()),
            pageSource: page,
          ),
          isFalse,
        );
      }
      expect(
        looksLikeLearnSessionExpiredPage(
          _forbiddenPage.replaceAll('403', '500'),
        ),
        isFalse,
      );
      expect(
        looksLikeLearnSessionExpiredPage(
          '{"title":"登录超时","content":"您未登录或登录失效"}',
        ),
        isFalse,
      );
    });

    test('treats identity login urls as unauthenticated session pages', () {
      expect(isIdentityLoginUri(Uri.parse(urls.idLogin())), isTrue);
      expect(
        isIdentityLoginUri(
          Uri.parse('${urls.learnStudentCourseListPage()}?login_timeout=1'),
        ),
        isTrue,
      );
      expect(
        isIdentityLoginUri(Uri.parse(urls.learnStudentCourseListPage())),
        isFalse,
      );
    });

    test('rejects identity login html even if it contains a csrf field', () {
      const loginHtml = '''
        <html>
          <body>
            <form id="theform">
              <input type="hidden" name="_csrf" value="id-csrf-token" />
              <input id="i_user" name="i_user" value="2023000000" />
              <input id="i_pass" name="i_pass" value="" />
              <div id="sm2publicKey">public-key</div>
            </form>
          </body>
        </html>
      ''';

      expect(looksLikeIdentityLoginPage(loginHtml), isTrue);
      expect(
        isAuthenticatedLearnPage(
          pageUri: Uri.parse(urls.idLogin()),
          pageSource: loginHtml,
        ),
        isFalse,
      );
      expect(
        isAuthenticatedLearnPage(
          pageUri: Uri.parse(urls.learnStudentCourseListPage()),
          pageSource: loginHtml,
        ),
        isFalse,
      );
    });

    test(
      'accepts authenticated learn course pages and extracts csrf token',
      () {
        const learnHtml = '''
        <html>
          <head>
            <script src="/f/wlxt/common/languagejs?lang=zh"></script>
          </head>
          <body>
            <a href="/f/wlxt/index/course/student/?_csrf=learn-csrf-token">课程</a>
          </body>
        </html>
      ''';

        expect(looksLikeIdentityLoginPage(learnHtml), isFalse);
        expect(
          isAuthenticatedLearnPage(
            pageUri: Uri.parse(urls.learnStudentCourseListPage()),
            pageSource: learnHtml,
          ),
          isTrue,
        );
        expect(extractCsrfTokenFromPage(learnHtml), 'learn-csrf-token');
      },
    );
  });

  for (final initialToken in ['', 'old-csrf']) {
    test(
      'HTTP 200 expiry restores login and resumes data with token "$initialToken"',
      () async {
        var recoveries = 0;
        var signedIn = false;
        var pageRequests = 0;
        late Learn2018Helper helper;
        helper = Learn2018Helper(
          config: HelperConfig(
            sessionRecoveryHandler: () async {
              recoveries++;
              await helper.login('demo', 'example', 'fp', '', '', 'test');
              return true;
            },
          ),
        );
        addTearDown(() => helper.dio.close());
        helper.setCSRFToken(initialToken);
        helper.dio.httpClientAdapter = _Adapter((request) async {
          if (request.uri.toString() == urls.idLogin()) {
            return ResponseBody.fromString('<html>checkSingle</html>', 200);
          }
          if (request.uri.toString() == urls.idLoginCheckSingle()) {
            return ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': [urls.learnAuthRoam('test-ticket')],
              },
            );
          }
          if (request.uri.path.contains('thauth_roaming_entry')) {
            signedIn = true;
            return ResponseBody.fromString(
              '',
              302,
              headers: {
                'location': ['/f/wlxt/index/course/student/'],
                'set-cookie': ['JSESSIONID=fresh-session; Path=/; HttpOnly'],
              },
            );
          }
          if (request.uri.path == '/f/wlxt/index/course/student/') {
            pageRequests++;
            if (signedIn) {
              expect(
                request.headers['cookie'],
                contains('JSESSIONID=fresh-session'),
              );
            }
            return ResponseBody.fromString(
              signedIn ? _authenticatedPage : _expiredPage,
              200,
            );
          }
          if (!signedIn) return ResponseBody.fromString(_forbiddenPage, 200);
          expect(request.uri.queryParameters['_csrf'], 'fresh-csrf');
          return ResponseBody.fromString('["2026-2027-1"]', 200);
        });
        expect(await helper.getSemesterIdList(), ['2026-2027-1']);
        expect(recoveries, 1);
        expect(pageRequests, initialToken.isEmpty ? 2 : 1);
      },
    );
  }

  test(
    'late expired responses reuse the recovered session without another login',
    () async {
      var recoveries = 0;
      var oldRequests = 0;
      final bothStarted = Completer<void>();
      final restored = Completer<void>();
      late Learn2018Helper helper;
      helper = Learn2018Helper(
        config: HelperConfig(
          sessionRecoveryHandler: () async {
            recoveries++;
            helper.setCSRFToken('fresh-csrf');
            restored.complete();
            return true;
          },
        ),
      );
      addTearDown(() => helper.dio.close());
      helper.setCSRFToken('old-csrf');
      helper.dio.httpClientAdapter = _Adapter((request) async {
        if (request.uri.queryParameters['_csrf'] == 'old-csrf') {
          final index = ++oldRequests;
          if (index == 2) bothStarted.complete();
          await bothStarted.future;
          if (index == 2) await restored.future;
          return ResponseBody.fromString(_expiredPage, 200);
        }
        return ResponseBody.fromString('["2026-2027-1"]', 200);
      });
      expect(
        await Future.wait([
          helper.getSemesterIdList(),
          helper.getSemesterIdList(),
        ]),
        [
          ['2026-2027-1'],
          ['2026-2027-1'],
        ],
      );
      expect(recoveries, 1);
    },
  );

  test(
    'a failed recovery stops after one attempt and remains retryable',
    () async {
      var recoveries = 0;
      final helper = Learn2018Helper(
        config: HelperConfig(
          sessionRecoveryHandler: () async {
            recoveries++;
            return false;
          },
        ),
      );
      addTearDown(() => helper.dio.close());
      helper.dio.httpClientAdapter = _Adapter(
        (_) async => ResponseBody.fromString(_expiredPage, 200),
      );
      for (var attempt = 1; attempt <= 2; attempt++) {
        await expectLater(
          helper.getSemesterIdList(),
          throwsA(
            isA<ApiError>().having(
              (e) => e.reason,
              'reason',
              FailReason.notLoggedIn,
            ),
          ),
        );
        expect(recoveries, attempt);
      }
    },
  );

  test('a transport timeout does not submit login credentials', () async {
    var recoveries = 0;
    final helper = Learn2018Helper(
      config: HelperConfig(
        sessionRecoveryHandler: () async {
          recoveries++;
          return true;
        },
      ),
    );
    addTearDown(() => helper.dio.close());
    helper.setCSRFToken('existing-csrf');
    helper.dio.httpClientAdapter = _Adapter(
      (request) async => throw DioException(
        requestOptions: request,
        type: DioExceptionType.receiveTimeout,
      ),
    );
    await expectLater(helper.getSemesterIdList(), throwsA(isA<DioException>()));
    expect(recoveries, 0);
  });
}

// Minimal, sanitized structures from the actual unauthenticated school pages.
const _expiredPage =
    '<html><head><title>登录超时</title></head><body>'
    '<div class="bground"><p class="infoo">您未登录或登录失效</p>'
    '<a class="chongxin">登录网络学堂</a></div></body></html>';
const _forbiddenPage =
    '<html><head><title>网络学堂</title></head><body>'
    '<div class="bground"><img src="/res/app/wlxt/img/log_fail.png">'
    '<p class="infoo">服务器内部错误</p><p>错误码为：403</p>'
    '<a class="chongxin">登录网络学堂</a></div></body></html>';
const _authenticatedPage =
    '<html><head><title>课程</title>'
    '<meta name="_csrf" content="fresh-csrf"></head></html>';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions request) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);

  @override
  void close({bool force = false}) {}
}
