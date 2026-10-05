import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/identity_auth_api.dart'
    show IdentityAuthApi, IdentityAuthDeferredException;
import 'package:learn_y/core/api/registrar_calendar_api.dart';
import 'package:learn_y/core/api/utils.dart';

void main() {
  test(
    'single-login second factor preserves identity cookies without another password',
    () async {
      var formLoads = 0;
      var shortcutPosts = 0;
      var passwordPosts = 0;
      final jar = CookieJar();
      final identityUri = Uri.parse('https://id.tsinghua.edu.cn/');
      await jar.saveFromResponse(identityUri, [
        Cookie('identity-session', 'existing'),
      ]);
      final helper = Learn2018Helper(
        config: HelperConfig(
          cookieJar: jar,
          campusCredentialProvider: () async => const Credential(
            username: 'student',
            password: 'password',
            fingerPrint: 'browser',
            fingerGenPrint: 'trusted',
          ),
        ),
      )..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      helper.dio.httpClientAdapter = _Adapter((options, _) {
        final uri = options.uri;
        if (uri.host == 'learn.tsinghua.edu.cn') return _response('ticket');
        if (uri.path == '/j_acegi_login.do') {
          return _redirect(
            'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
          );
        }
        if (uri.path.contains('/login/form/')) {
          formLoads++;
          return _response(
            formLoads > 2
                ? _passwordForm
                : '<form action="/do/off/ui/auth/login/checkSingle"></form>',
          );
        }
        if (uri.path.endsWith('/checkSingle')) {
          shortcutPosts++;
          return _response(
            '<title>二次认证</title><script>const retry="/do/off/ui/auth/login/checkSingle";</script>',
          );
        }
        if (uri.path.endsWith('/check')) {
          passwordPosts++;
          return _response('<title>二次认证</title>');
        }
        return _response('unexpected');
      });
      await expectLater(
        helper.getCalendar('2026-09-14', '2026-09-20'),
        throwsA(
          isA<RegistrarException>().having(
            (error) => error.failure,
            'failure',
            RegistrarFailure.identityVerification,
          ),
        ),
      );
      expect(shortcutPosts, 1);
      expect(passwordPosts, 0);
      expect(formLoads, 2);
      expect((await jar.loadForRequest(identityUri)).single.value, 'existing');
    },
  );
  for (final failurePage in ['sso_fail.jsp', 'timeout.jsp']) {
    test('HTTP 200 $failurePage renews the registrar ticket once', () async {
      final dio = Dio();
      addTearDown(() => dio.close());
      var tickets = 0;
      dio.httpClientAdapter = _Adapter((options, _) {
        final path = options.uri.path;
        if (path == '/j_acegi_login.do') {
          return tickets == 1
              ? _redirect('/$failurePage')
              : _response('authorized');
        }
        if (path == '/$failurePage') {
          return _response('<html>service error</html>');
        }
        return _response(
          '$jsonpExtractorName([{ "nq":"20261231", "nr":"Course" }])',
        );
      });
      final api = RegistrarCalendarApi(
        dio: dio,
        fetchTicket: () async => 'ticket-${++tickets}',
        authenticateIdentity: (_) async =>
            fail('ticket renewal must reuse identity'),
      );
      final events = await api.getCalendar('2026-09-14', '2027-01-17');
      expect(tickets, 2);
      expect(events.single.date, '20261231');
    });
  }
  test(
    'campus challenge preserves WebVPN entry for browser OAuth state',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close());
      dio.httpClientAdapter = _Adapter((options, _) {
        if (options.uri.host == 'zhjw.cic.tsinghua.edu.cn') {
          return _redirect('https://webvpn.tsinghua.edu.cn/login');
        }
        if (options.uri.host == 'webvpn.tsinghua.edu.cn') {
          return _redirect('https://oauth.tsinghua.edu.cn/thu-oauth/auth');
        }
        if (options.uri.host == 'oauth.tsinghua.edu.cn') {
          return _redirect(
            'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
          );
        }
        return _response(_passwordForm);
      });
      final api = RegistrarCalendarApi(
        dio: dio,
        fetchTicket: () async => 'ticket',
      );
      await expectLater(
        api.establishSession(),
        throwsA(
          isA<RegistrarException>().having(
            (error) => error.browserEntryUri.toString(),
            'browser entry',
            'https://webvpn.tsinghua.edu.cn/login',
          ),
        ),
      );
    },
  );

  test(
    'Learn and campus password submissions share the same rate limit',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close());
      var passwordPosts = 0;
      dio.httpClientAdapter = _Adapter((options, _) {
        if (options.method == 'GET') return _response(_passwordForm);
        passwordPosts++;
        return _redirect('https://learn.tsinghua.edu.cn/');
      });
      final identity = IdentityAuthApi(dio, CookieJar());
      const credential = Credential(username: 'student', password: 'password');
      await identity.authenticate(
        Uri.parse(
          'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/learn/0',
        ),
        credential,
      );
      await expectLater(
        identity.authenticate(
          Uri.parse(
            'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
          ),
          credential,
        ),
        throwsA(isA<IdentityAuthDeferredException>()),
      );
      expect(passwordPosts, 1);
    },
  );

  test(
    'campus service login reuses identity without expiring a healthy Learn session',
    () async {
      var credentialReads = 0;
      var learnRecoveries = 0;
      var gatewayReady = false;
      final helper = Learn2018Helper(
        config: HelperConfig(
          campusCredentialProvider: () async {
            credentialReads++;
            return const Credential(
              username: 'student',
              password: 'password',
              fingerPrint: 'browser',
              fingerGenPrint: 'trusted',
            );
          },
          sessionRecoveryHandler: () async {
            learnRecoveries++;
            return false;
          },
        ),
      )..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      helper.dio.httpClientAdapter = _Adapter((options, body) {
        final uri = options.uri;
        if (uri.host == 'learn.tsinghua.edu.cn') return _response('ticket');
        if (uri.host == 'zhjw.cic.tsinghua.edu.cn') {
          return _redirect(
            'https://webvpn.tsinghua.edu.cn/https/gateway-id/j_acegi_login.do',
          );
        }
        if (uri.path.endsWith('/j_acegi_login.do')) {
          return gatewayReady
              ? _response('authorized')
              : _redirect(
                  'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
                );
        }
        if (uri.path.contains('/login/form/')) {
          return _response(
            '<form action="/do/off/ui/auth/login/checkSingle"></form>',
          );
        }
        if (uri.path.endsWith('/checkSingle')) {
          expect(body, contains('fingerGenPrint=trusted'));
          expect(options.headers['Referer'], endsWith('/form/campus/0'));
          return _response(
            '<a href="https://oauth.tsinghua.edu.cn/thu-oauth/callback?ticket=campus">Continue</a>',
          );
        }
        if (uri.path == '/thu-oauth/callback') {
          gatewayReady = true;
          return _response('', 302, {
            'location': [
              'https://webvpn.tsinghua.edu.cn/https/gateway-id/j_acegi_login.do',
            ],
          });
        }
        return _response(
          '$jsonpExtractorName([{ "nq":"20260914", "nr":"Course" }])',
        );
      });

      expect(
        (await helper.getCalendar(
          '2026-09-14',
          '2026-09-20',
        )).single.courseName,
        'Course',
      );
      expect(credentialReads, 1);
      expect(learnRecoveries, 0);
      await Future.wait([
        helper.getCalendar('2026-09-21', '2026-09-27'),
        helper.getCalendar('2026-09-28', '2026-10-04'),
      ]);
      expect(
        credentialReads,
        1,
        reason: 'date changes reuse the campus session',
      );
    },
  );

  test(
    'rejected trusted-browser shortcut falls back to one password submission',
    () async {
      var shortcutPosts = 0;
      var passwordPosts = 0;
      var tickets = 0;
      var ready = false;
      final helper = Learn2018Helper(
        config: HelperConfig(
          campusCredentialProvider: () async => const Credential(
            username: 'student',
            password: 'correct-password',
            fingerPrint: 'browser',
            fingerGenPrint: 'trusted',
          ),
        ),
      )..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      helper.dio.httpClientAdapter = _Adapter((options, body) {
        final uri = options.uri;
        if (uri.host == 'learn.tsinghua.edu.cn') {
          tickets++;
          return _response('ticket');
        }
        if (uri.path == '/j_acegi_login.do') {
          return ready
              ? _response('authorized')
              : _redirect(
                  'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
                );
        }
        if (uri.path.contains('/login/form/')) {
          return _response(
            '<form action="/do/off/ui/auth/login/checkSingle"></form>',
          );
        }
        if (uri.path.endsWith('/checkSingle')) {
          shortcutPosts++;
          return _response(_passwordForm);
        }
        if (uri.path.endsWith('/check')) {
          passwordPosts++;
          expect(body, contains('i_user=student'));
          expect(body, contains('i_pass=04'));
          ready = true;
          return _redirect('https://zhjw.cic.tsinghua.edu.cn/j_acegi_login.do');
        }
        return _response('$jsonpExtractorName([])');
      });
      await Future.wait([
        helper.getCalendar('2026-09-07', '2026-09-13'),
        helper.getCalendar('2026-09-14', '2026-09-20'),
      ]);
      expect(shortcutPosts, 1);
      expect(passwordPosts, 1);
      expect(tickets, 1);
    },
  );

  test(
    'an obsolete identity failure cannot overwrite a later recovered date',
    () async {
      var credentialReads = 0;
      var ready = false;
      final flags = <bool>[];
      final helper = Learn2018Helper(
        config: HelperConfig(
          onCampusVerificationChanged: flags.add,
          campusCredentialProvider: () async {
            credentialReads++;
            return const Credential(username: 'student', password: 'password');
          },
        ),
      )..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      helper.dio.httpClientAdapter = _Adapter((options, _) {
        if (options.uri.host == 'learn.tsinghua.edu.cn') {
          return _response('ticket');
        }
        if (options.uri.host == 'zhjw.cic.tsinghua.edu.cn') {
          if (ready) {
            return options.uri.path == '/j_acegi_login.do'
                ? _response('authorized')
                : _response('$jsonpExtractorName([])');
          }
          return _redirect(
            'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
          );
        }
        if (options.uri.path.endsWith('/check')) ready = true;
        return _response(_passwordForm);
      });
      final first = helper.getCalendar('2026-09-07', '2026-09-13');
      final next = helper.getCalendar('2026-09-14', '2026-09-20');
      await expectLater(
        first,
        throwsA(
          isA<RegistrarException>().having(
            (error) => error.failure,
            'failure',
            RegistrarFailure.identityVerification,
          ),
        ),
      );
      expect(await next, isEmpty);
      expect(credentialReads, 1);
      expect(flags, [
        false,
      ], reason: 'obsolete failure must not overwrite the current request');
    },
  );

  test(
    'a paced campus recovery waits once then finishes without manual login',
    () async {
      final dio = Dio();
      addTearDown(() => dio.close());
      var attempts = 0;
      var ready = false;
      dio.httpClientAdapter = _Adapter((options, _) {
        if (options.uri.path == '/j_acegi_login.do') {
          return ready
              ? _response('authorized')
              : _redirect(
                  'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
                );
        }
        if (options.uri.host == 'id.tsinghua.edu.cn') {
          return _response(_passwordForm);
        }
        return _response('$jsonpExtractorName([])');
      });
      final registrar = RegistrarCalendarApi(
        dio: dio,
        fetchTicket: () async => 'ticket',
        authenticateIdentity: (uri) async {
          attempts++;
          if (attempts == 1) {
            throw const RegistrarException(
              RegistrarFailure.recoveryDeferred,
              retryAfter: Duration(milliseconds: 1),
            );
          }
          ready = true;
          return Response<String>(
            requestOptions: RequestOptions(path: uri.toString()),
            statusCode: 302,
            headers: Headers.fromMap({
              'location': ['https://zhjw.cic.tsinghua.edu.cn/j_acegi_login.do'],
            }),
          );
        },
      );
      expect(await registrar.getCalendar('20260907', '20260913'), isEmpty);
      expect(attempts, 2);
    },
  );

  test(
    'identity cookies alone complete the campus redirect without credentials',
    () async {
      final helper = Learn2018Helper()..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      await helper.cookieJar.saveFromResponse(Uri.https('id.tsinghua.edu.cn'), [
        Cookie('identity', 'current'),
      ]);
      helper.dio.httpClientAdapter = _Adapter((options, _) {
        final uri = options.uri;
        if (uri.host == 'learn.tsinghua.edu.cn') return _response('ticket');
        if (uri.host == 'zhjw.cic.tsinghua.edu.cn') {
          return _redirect(
            'https://id.tsinghua.edu.cn/do/off/ui/auth/login/form/campus/0',
          );
        }
        if (uri.host == 'id.tsinghua.edu.cn') {
          expect(options.headers['cookie'], contains('identity=current'));
          return _redirect(
            'https://webvpn.tsinghua.edu.cn/https/gateway-id/j_acegi_login.do',
          );
        }
        if (uri.path.endsWith('/j_acegi_login.do')) {
          return _response('authorized');
        }
        return _response('$jsonpExtractorName([])');
      });
      expect(await helper.getCalendar('2026-09-14', '2026-09-20'), isEmpty);
    },
  );

  test(
    'course metadata network failure remains distinct from an empty schedule',
    () async {
      final helper = Learn2018Helper()..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      var fail = true;
      helper.dio.httpClientAdapter = _Adapter((options, _) {
        if (options.uri.path.contains('loadCourseBySemesterId')) {
          return _response(
            '{"message":"success","resultList":[{"wlkcid":"course","kcm":"Course"}]}',
          );
        }
        if (fail) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return _response('[]');
      });
      expect(
        (await helper.getCourseList('term')).single.timeAndLocationLoaded,
        isFalse,
      );
      fail = false;
      final empty = (await helper.getCourseList('term')).single;
      expect(empty.timeAndLocationLoaded, isTrue);
      expect(empty.timeAndLocation, isEmpty);
    },
  );
  test(
    'Learn 403 retries a fresh multipart ticket body and updated CSRF',
    () async {
      var recovery = 0;
      late Learn2018Helper helper;
      helper = Learn2018Helper(
        config: HelperConfig(
          sessionRecoveryHandler: () async {
            recovery++;
            helper.setCSRFToken('fresh-token');
            return true;
          },
        ),
      )..setCSRFToken('old-token');
      addTearDown(() => helper.dio.close());
      final ticketBodies = <String>[];
      final csrf = <String?>[];
      helper.dio.httpClientAdapter = _Adapter((options, body) {
        if (options.uri.host == 'learn.tsinghua.edu.cn') {
          csrf.add(options.uri.queryParameters['_csrf']);
          ticketBodies.add(body);
          return ticketBodies.length == 1
              ? _response('', 403)
              : _response('"ticket+encoded&value"');
        }
        expect(options.uri.queryParameters.containsKey('_csrf'), isFalse);
        if (options.uri.path == '/j_acegi_login.do') {
          expect(
            options.uri.queryParameters.values,
            contains('ticket+encoded&value'),
          );
          return _response('authorized');
        }
        expect(options.uri.queryParameters['p_start_date'], '20260914');
        return _response('$jsonpExtractorName([])');
      });
      expect(await helper.getCalendar('2026-09-14', '2026-09-20'), isEmpty);
      expect(recovery, 1);
      expect(csrf, ['old-token', 'fresh-token']);
      expect(ticketBodies, hasLength(2));
      for (final body in ticketBodies) {
        expect(body, contains('ALL_ZHJW'));
      }
    },
  );

  test(
    'registrar authorization retries its ticket without invalidating Learn',
    () async {
      var recoveries = 0;
      var tickets = 0;
      var auth = 0;
      var calendarExpired = false;
      final helper = Learn2018Helper(
        config: HelperConfig(
          sessionRecoveryHandler: () async {
            recoveries++;
            return true;
          },
        ),
      )..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      helper.dio.httpClientAdapter = _Adapter((options, _) {
        if (options.uri.host == 'learn.tsinghua.edu.cn') {
          tickets++;
          return _response('ticket-$tickets');
        }
        if (options.uri.path == '/j_acegi_login.do') {
          auth++;
          return auth == 1 ? _response('', 403) : _response('authorized');
        }
        if (calendarExpired) {
          calendarExpired = false;
          return _response('', 403);
        }
        return _response('$jsonpExtractorName([])');
      });
      expect(await helper.getCalendar('2026-09-07', '2026-09-13'), isEmpty);
      expect(tickets, 2);
      expect(recoveries, 0);
      calendarExpired = true;
      expect(await helper.getCalendar('2026-09-14', '2026-09-20'), isEmpty);
      expect(
        tickets,
        3,
        reason: 'only real authorization loss renews the cached service',
      );
      expect(recoveries, 0);
    },
  );

  test(
    'captures redirect cookies and queries the authenticated registrar gateway',
    () async {
      final helper = Learn2018Helper()..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      const prefix = '/https/gateway-id';
      helper.dio.httpClientAdapter = _Adapter((options, _) {
        final uri = options.uri;
        if (uri.host == 'learn.tsinghua.edu.cn') return _response('ticket');
        if (uri.host == 'zhjw.cic.tsinghua.edu.cn') {
          return _redirect('https://oauth.tsinghua.edu.cn/lb-auth/lbredirect');
        }
        if (uri.host == 'oauth.tsinghua.edu.cn') {
          return _redirect(
            'https://webvpn.tsinghua.edu.cn$prefix/j_acegi_login.do',
          );
        }
        if (uri.path.endsWith('/j_acegi_login.do')) {
          return _response('', 302, {
            'location': ['/http/gateway-id/index.do'],
            'set-cookie': ['registrar=valid; Path=/; Secure; HttpOnly'],
          });
        }
        expect(options.headers['cookie'], contains('registrar=valid'));
        if (uri.path.endsWith('/index.do')) return _response('authorized');
        expect(uri.path, '/http/gateway-id/jxmh_out.do');
        expect(uri.queryParameters.containsKey('_csrf'), isFalse);
        return _response(
          '$jsonpExtractorName([{"nq":"20260914","nr":"Algorithms","kssj":"08:00","jssj":"09:35","dd":"101"}])',
        );
      });
      final events = await helper.getCalendar('2026-09-14', '2026-09-20');
      expect(events.single.courseName, 'Algorithms');
    },
  );

  test(
    'gateway login requirement is distinct and is not retried as Learn expiry',
    () async {
      final helper = Learn2018Helper()..setCSRFToken('learn-token');
      addTearDown(() => helper.dio.close());
      var tickets = 0;
      helper.dio.httpClientAdapter = _Adapter((options, _) {
        if (options.uri.host == 'learn.tsinghua.edu.cn') {
          tickets++;
          return _response('ticket');
        }
        if (options.uri.host == 'zhjw.cic.tsinghua.edu.cn') {
          return _redirect(
            'https://webvpn.tsinghua.edu.cn/https/gateway-id/j_acegi_login.do',
          );
        }
        if (options.uri.host == 'webvpn.tsinghua.edu.cn') {
          return _redirect('https://id.tsinghua.edu.cn/login');
        }
        return _response('<input type="password">');
      });
      await expectLater(
        helper.getCalendar('2026-09-14', '2026-09-20'),
        throwsA(
          isA<RegistrarException>().having(
            (error) => error.failure,
            'failure',
            RegistrarFailure.campusAccess,
          ),
        ),
      );
      expect(tickets, 1);
    },
  );

  test(
    'empty data malformed data and server outages remain distinct',
    () async {
      for (final sample in [
        ('$jsonpExtractorName([])', 200, null),
        ('<html>maintenance</html>', 200, RegistrarFailure.invalidCalendar),
        ('', 503, RegistrarFailure.unavailable),
        ('<input type="password">', 200, RegistrarFailure.authorization),
      ]) {
        final dio = Dio();
        addTearDown(() => dio.close());
        dio.httpClientAdapter = _Adapter(
          (options, _) => options.uri.path == '/j_acegi_login.do'
              ? _response('authorized')
              : _response(sample.$1, sample.$2),
        );
        final request = RegistrarCalendarApi(
          dio: dio,
          fetchTicket: () async => 'ticket',
        ).getCalendar('20260914', '20260920');
        if (sample.$3 == null) {
          expect(await request, isEmpty);
        } else {
          await expectLater(
            request,
            throwsA(
              isA<RegistrarException>().having(
                (error) => error.failure,
                'failure',
                sample.$3,
              ),
            ),
          );
        }
      }
    },
  );

  test('untrusted redirect never receives a request', () async {
    final dio = Dio();
    addTearDown(() => dio.close());
    dio.httpClientAdapter = _Adapter((options, _) {
      expect(options.uri.host, 'zhjw.cic.tsinghua.edu.cn');
      return _redirect('https://example.com/untrusted');
    });
    await expectLater(
      RegistrarCalendarApi(
        dio: dio,
        fetchTicket: () async => 'ticket',
      ).getCalendar('20260914', '20260920'),
      throwsA(
        isA<RegistrarException>().having(
          (error) => error.failure,
          'failure',
          RegistrarFailure.authorization,
        ),
      ),
    );
  });

  test('a CSRF network error never invokes credential recovery', () async {
    var recovery = 0;
    final helper = Learn2018Helper(
      config: HelperConfig(
        sessionRecoveryHandler: () async {
          recovery++;
          return true;
        },
      ),
    );
    addTearDown(() => helper.dio.close());
    helper.dio.httpClientAdapter = _Adapter(
      (options, _) => throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionTimeout,
      ),
    );
    await expectLater(
      helper.getCalendar('2026-09-14', '2026-09-20'),
      throwsA(isA<DioException>()),
    );
    expect(recovery, 0);
  });
}

const _passwordForm =
    '<html><input type="password" name="i_pass">'
    '<div id="sm2publicKey">'
    '0432C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7'
    'BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0'
    '</div></html>';

ResponseBody _response(
  String body, [
  int status = 200,
  Map<String, List<String>> headers = const {},
]) => ResponseBody.fromString(body, status, headers: headers);
ResponseBody _redirect(String target) => _response('', 307, {
  'location': [target],
});

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final ResponseBody Function(RequestOptions, String) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    return respond(options, utf8.decode(bytes));
  }

  @override
  void close({bool force = false}) {}
}
