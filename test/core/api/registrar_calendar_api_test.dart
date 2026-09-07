import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/registrar_calendar_api.dart';
import 'package:learn_y/core/api/utils.dart';

void main() {
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
            '<a href="/thu-oauth/callback?ticket=campus">Continue</a>',
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
        return _response('$jsonpExtractorName([])');
      });
      expect(await helper.getCalendar('2026-09-07', '2026-09-13'), isEmpty);
      expect(tickets, 2);
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
