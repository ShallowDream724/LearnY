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
  unavailable,
  invalidCalendar,
}

class RegistrarException implements Exception {
  const RegistrarException(this.failure);
  final RegistrarFailure failure;
  @override
  String toString() => 'RegistrarException(${failure.name})';
}

/// Registrar cookies and authorization are independent of the Learn session.
/// The injected Dio retains CookieManager, but never invokes Learn recovery.
class RegistrarCalendarApi {
  RegistrarCalendarApi({required this.dio, required this.fetchTicket});
  final Dio dio;
  final Future<String> Function() fetchTicket;
  String? _gatewayPrefix;

  Future<List<CalendarEvent>> getCalendar(
    String start,
    String end, {
    bool graduate = false,
  }) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final ticket = parseRegistrarTicket(await fetchTicket());
        _verify(
          await _follow(_throughGateway(urls.registrarAuth(ticket))),
          landingPage: true,
        );
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
      final response = await dio.get<String>(
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
      final status = response.statusCode ?? 0;
      if (status >= 300 && status < 400) {
        final location = response.headers.value('location');
        if (location == null) {
          throw const RegistrarException(RegistrarFailure.invalidCalendar);
        }
        final next = uri.resolve(location);
        if (next.host == 'webvpn.tsinghua.edu.cn') {
          final match = RegExp(
            r'^(/https/[^/]+)/j_acegi_login\.do$',
          ).firstMatch(next.path);
          if (match != null) _gatewayPrefix = match[1];
          final gateway = RegExp(
            r'^(/(?:http|https)/([^/]+))/',
          ).firstMatch(next.path);
          if (gateway != null &&
              _gatewayPrefix?.split('/').last == gateway[2]) {
            _gatewayPrefix = gateway[1];
          }
        }
        uri = next;
        continue;
      }
      final gatewayContent =
          uri.host == 'webvpn.tsinghua.edu.cn' &&
          _gatewayPrefix != null &&
          uri.path.startsWith('$_gatewayPrefix/');
      if (uri.host != registrarHost && !gatewayContent) {
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
