import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:charset/charset.dart';
import 'package:html/parser.dart' as html;

import 'models.dart';
import 'urls.dart' as urls;
import 'utils.dart';

enum RegistrarFailure {
  ticket,
  authorization,
  campusAccess,
  identityVerification,
  unavailable,
  invalidCalendar,
}

class RegistrarException implements Exception {
  const RegistrarException(this.failure, {this.loginUri});
  final RegistrarFailure failure;
  final Uri? loginUri;
  @override
  String toString() => 'RegistrarException(${failure.name})';
}

/// Service sessions share campus identity, but a registrar failure must not
/// invalidate an otherwise healthy Learn session.
class RegistrarCalendarApi {
  RegistrarCalendarApi({
    required this.dio,
    required this.fetchTicket,
    this.authenticateIdentity,
  });
  final Dio dio;
  final Future<String> Function() fetchTicket;
  final Future<Response<String>?> Function(Uri loginUri)? authenticateIdentity;
  String? _gatewayPrefix;
  bool _didAuthenticateIdentity = false;
  Uri? _identityLoginUri;

  Future<void> establishSession() async {
    final ticket = parseRegistrarTicket(await fetchTicket());
    _verify(
      await _follow(_throughGateway(urls.registrarAuth(ticket))),
      landingPage: true,
    );
  }

  Future<List<CalendarEvent>> getCalendar(
    String start,
    String end, {
    bool graduate = false,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await establishSession();
        final calendarUrl = urls.registrarCalendar(
          start,
          end,
          graduate: graduate,
          callbackName: jsonpExtractorName,
        );
        final response = await _follow(_throughGateway(calendarUrl));
        _verify(response);
        return parseRegistrarCalendar(response.data.toString());
      } on RegistrarException catch (error) {
        if (error.failure != RegistrarFailure.authorization || attempt == 1) {
          rethrow;
        }
      }
    }
    throw const RegistrarException(RegistrarFailure.authorization);
  }

  String _throughGateway(String url) {
    final direct = Uri.parse(url);
    return _gatewayPrefix == null
        ? url
        : direct
              .replace(
                host: 'webvpn.tsinghua.edu.cn',
                path: '$_gatewayPrefix${direct.path}',
              )
              .toString();
  }

  Future<Response<String>> _follow(String url) async {
    var uri = Uri.parse(url);
    final registrarHost = Uri.parse(urls.registrarPrefix).host;
    final allowedHosts = {
      registrarHost,
      Uri.parse(urls.idPrefix).host,
      'oauth.tsinghua.edu.cn',
      'webvpn.tsinghua.edu.cn',
    };
    for (var hop = 0; hop < 10; hop++) {
      // The campus gateway may authenticate via OAuth before entering registrar.
      if (!allowedHosts.contains(uri.host) || uri.scheme != 'https') {
        throw const RegistrarException(RegistrarFailure.authorization);
      }
      var response = await dio.get<String>(
        uri.toString(),
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
          responseDecoder: (bytes, options, body) {
            final contentType =
                body.headers[Headers.contentTypeHeader]
                    ?.join(';')
                    .toLowerCase() ??
                '';
            return contentType.contains('gbk') || contentType.contains('gb2312')
                ? gbk.decode(bytes, allowMalformed: true)
                : utf8.decode(bytes, allowMalformed: true);
          },
        ),
      );
      if (uri.host == Uri.parse(urls.idPrefix).host &&
          uri.path.startsWith('/do/off/ui/auth/login/form/')) {
        _identityLoginUri = uri;
      }
      if (_identityLoginUri == uri &&
          response.statusCode == 200 &&
          !_didAuthenticateIdentity &&
          _isIdentityChallenge(response.data ?? '')) {
        _didAuthenticateIdentity = true;
        final authenticated = await authenticateIdentity?.call(uri);
        if (authenticated != null) {
          response = authenticated;
          uri = response.requestOptions.uri;
        }
      }
      final status = response.statusCode ?? 0;
      if (status >= 500 || status == 429) {
        throw const RegistrarException(RegistrarFailure.unavailable);
      }
      if (status >= 300 && status < 400) {
        final location = response.headers.value('location');
        if (location == null) {
          throw const RegistrarException(RegistrarFailure.invalidCalendar);
        }
        final next = uri.resolve(location);
        _rememberGateway(next);
        uri = next;
        continue;
      }
      if (status == 200 &&
          {
            Uri.parse(urls.idPrefix).host,
            'oauth.tsinghua.edu.cn',
          }.contains(uri.host)) {
        final continuation = _identityContinuation(uri, response.data ?? '');
        if (continuation != null) {
          _rememberGateway(continuation);
          uri = continuation;
          continue;
        }
      }
      final gatewayContent =
          uri.host == 'webvpn.tsinghua.edu.cn' &&
          _gatewayPrefix != null &&
          uri.path.startsWith('$_gatewayPrefix/');
      if (uri.host != registrarHost && !gatewayContent) {
        if (uri.host == Uri.parse(urls.idPrefix).host &&
            _identityLoginUri != null &&
            status == 200) {
          throw RegistrarException(
            RegistrarFailure.identityVerification,
            loginUri: _identityLoginUri,
          );
        }
        throw RegistrarException(
          _gatewayPrefix != null
              ? RegistrarFailure.campusAccess
              : RegistrarFailure.authorization,
        );
      }
      return response;
    }
    throw const RegistrarException(RegistrarFailure.authorization);
  }

  void _rememberGateway(Uri uri) {
    if (uri.host != 'webvpn.tsinghua.edu.cn') return;
    final match = RegExp(
      r'^(/(?:http|https)/[^/]+)/j_acegi_login\.do$',
    ).firstMatch(uri.path);
    if (match != null) _gatewayPrefix = match[1];
    final gateway = RegExp(r'^(/(?:http|https)/([^/]+))/').firstMatch(uri.path);
    if (gateway != null && _gatewayPrefix?.split('/').last == gateway[2]) {
      _gatewayPrefix = gateway[1];
    }
  }

  bool _isIdentityChallenge(String source) =>
      html
              .parse(source)
              .querySelector(
                r'input[type="password"], #sm2publicKey, form[action$="checkSingle"]',
              ) !=
          null ||
      source.contains('checkSingle');

  Uri? _identityContinuation(Uri uri, String source) {
    final page = html.parse(source);
    if (page.querySelector('input[type="password"]') != null) return null;
    final destinations = <Uri>{};
    for (final anchor in page.querySelectorAll('a[href]')) {
      final target = uri.resolve(anchor.attributes['href']!);
      if (target.scheme != 'https') continue;
      final identityCallback =
          target.host == Uri.parse(urls.idPrefix).host &&
          target.path == '/thu-oauth/callback';
      final oauthCallback =
          target.host == 'oauth.tsinghua.edu.cn' &&
          target.path.startsWith('/lb-auth/');
      if (identityCallback || oauthCallback) destinations.add(target);
    }
    // The SSO success page uses a callback anchor instead of an HTTP redirect.
    // Do not follow unrelated links or execute scripts from the login page.
    return destinations.length == 1 ? destinations.single : null;
  }

  void _verify(Response<String> response, {bool landingPage = false}) {
    final status = response.statusCode ?? 0;
    if (status == 401 || status == 403) {
      throw const RegistrarException(RegistrarFailure.authorization);
    }
    if (status >= 500 || status == 429) {
      throw const RegistrarException(RegistrarFailure.unavailable);
    }
    if (status != 200) {
      throw const RegistrarException(RegistrarFailure.invalidCalendar);
    }
    final body = response.data?.trimLeft() ?? '';
    if (body.startsWith('<')) {
      final page = html.parse(body);
      final text = page.body?.text ?? '';
      if ((text.contains('用户登陆超时') || text.contains('用户登录超时')) &&
          !(landingPage && text.contains('或访问内容不存在'))) {
        throw const RegistrarException(RegistrarFailure.authorization);
      }
      if (page.querySelector(
            'input[type="password"], input[name="j_password"], #i_pass',
          ) !=
          null) {
        throw const RegistrarException(RegistrarFailure.authorization);
      }
    }
  }
}

String parseRegistrarTicket(String raw) {
  var ticket = raw.trim();
  try {
    final decoded = jsonDecode(ticket);
    if (decoded is! String) {
      throw const RegistrarException(RegistrarFailure.ticket);
    }
    ticket = decoded.trim();
  } on FormatException {
    // The service also supports an unquoted opaque ticket.
    if (ticket.startsWith("'") && ticket.endsWith("'") && ticket.length > 2) {
      ticket = ticket.substring(1, ticket.length - 1);
    }
  }
  if (ticket.isEmpty ||
      RegExp(r'[\s<>"{}\[\]]').hasMatch(ticket) ||
      ticket == 'null') {
    throw const RegistrarException(RegistrarFailure.ticket);
  }
  return ticket;
}

List<CalendarEvent> parseRegistrarCalendar(String raw) {
  try {
    final decoded = extractJSONPResult(raw);
    if (decoded is! List) {
      throw const RegistrarException(RegistrarFailure.invalidCalendar);
    }
    return decoded.map((value) {
      if (value is! Map || value['nq'] == null || value['nr'] == null) {
        throw const RegistrarException(RegistrarFailure.invalidCalendar);
      }
      return CalendarEvent(
        location: value['dd']?.toString() ?? '',
        status: value['fl']?.toString() ?? '',
        startTime: value['kssj']?.toString() ?? '',
        endTime: value['jssj']?.toString() ?? '',
        date: value['nq'].toString(),
        courseName: value['nr'].toString(),
      );
    }).toList();
  } on RegistrarException {
    rethrow;
  } catch (_) {
    throw const RegistrarException(RegistrarFailure.invalidCalendar);
  }
}
