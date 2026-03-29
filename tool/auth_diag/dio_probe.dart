import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/urls.dart' as urls;

Future<void> main() async {
  await _probeRawDio();
  await _probeCookieManagedDio();
  await _probeLearnHelper();
}

Future<void> _probeRawDio() async {
  final dio = Dio(
    BaseOptions(
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      responseType: ResponseType.plain,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  await _runProbe('raw_dio', dio);
}

Future<void> _probeCookieManagedDio() async {
  final jar = CookieJar();
  final dio = Dio(
    BaseOptions(
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      responseType: ResponseType.plain,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
  dio.interceptors.add(CookieManager(jar));

  await _runProbe('cookie_manager_dio', dio, jar: jar);
}

Future<void> _probeLearnHelper() async {
  final helper = Learn2018Helper();
  await _runProbe('learn_helper_dio', helper.dio, jar: helper.cookieJar);
}

Future<void> _runProbe(String label, Dio dio, {CookieJar? jar}) async {
  final uri = Uri.parse(urls.idLogin());
  try {
    final beforeCookies = jar == null
        ? const <dynamic>[]
        : await jar.loadForRequest(uri);
    final response = await dio.get<String>(urls.idLogin());
    final afterCookies = jar == null
        ? const <dynamic>[]
        : await jar.loadForRequest(uri);
    final body = response.data ?? '';

    _log('[$label] status=${response.statusCode}');
    _log('[$label] realUri=${response.realUri}');
    _log(
      '[$label] requestHeaders=${(response.requestOptions.headers.keys.toList()..sort()).join(',')}',
    );
    _log('[$label] beforeCookies=${beforeCookies.length}');
    _log('[$label] afterCookies=${afterCookies.length}');
    if (afterCookies.isNotEmpty) {
      _log(
        '[$label] cookieNames=${afterCookies.map((cookie) => cookie.name).join(',')}',
      );
    }
    _log(
      '[$label] bodyPreview=${body.replaceAll(RegExp(r'\s+'), ' ').substring(0, body.length.clamp(0, 160))}',
    );
  } catch (error, stackTrace) {
    _log('[$label] error=$error');
    if (error is DioException) {
      _log('[$label] requestUri=${error.requestOptions.uri}');
      _log(
        '[$label] requestHeaders=${(error.requestOptions.headers.keys.toList()..sort()).join(',')}',
      );
      _log('[$label] contentType=${error.requestOptions.contentType}');
      _log('[$label] responseStatus=${error.response?.statusCode}');
      _log('[$label] responseUri=${error.response?.realUri}');
      final body = error.response?.data?.toString() ?? '';
      _log(
        '[$label] bodyPreview=${body.replaceAll(RegExp(r'\s+'), ' ').substring(0, body.length.clamp(0, 160))}',
      );
    }
    _log('[$label] stack=$stackTrace');
  }
}

void _log(String message) {
  stdout.writeln(message);
}
