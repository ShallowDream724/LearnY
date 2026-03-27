// ignore_for_file: avoid_print

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/urls.dart' as urls;

void main() {
  test('probe identity login form fetch', () async {
    await _probeRawDio();
    await _probeCookieManagedDio();
    await _probeLearnHelper();
  });

  test('probe getRoamingTicket with fake credentials', () async {
    final helper = Learn2018Helper();
    try {
      await helper.getRoamingTicket(
        'fake-user',
        'fake-password',
        '8164fc4a66e072a944c2e0f5d0aef34d',
        deviceName: 'windows,Edge/146',
      );
      print('[get_roaming_fake] unexpected success');
    } catch (error, stackTrace) {
      print('[get_roaming_fake] error=$error');
      print('[get_roaming_fake] stack=$stackTrace');
    }
  });

  test('probe helper GET after cookie delete', () async {
    final helper = Learn2018Helper();
    final loginUri = Uri.parse(urls.idLogin());
    await helper.cookieJar.delete(loginUri);
    await _runProbe('learn_helper_after_delete', helper.dio, jar: helper.cookieJar);
  });

  test('probe getRoamingTicket under widget binding', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final helper = Learn2018Helper();
    try {
      await helper.getRoamingTicket(
        'fake-user',
        'fake-password',
        '8164fc4a66e072a944c2e0f5d0aef34d',
        deviceName: 'windows,Edge/146',
      );
      print('[get_roaming_widget_binding] unexpected success');
    } catch (error, stackTrace) {
      print('[get_roaming_widget_binding] error=$error');
      print('[get_roaming_widget_binding] stack=$stackTrace');
    }
  });
}

Future<void> _probeRawDio() async {
  final dio = _newDio();
  await _runProbe('raw_dio', dio);
}

Future<void> _probeCookieManagedDio() async {
  final jar = CookieJar();
  final dio = _newDio();
  dio.interceptors.add(CookieManager(jar));
  await _runProbe('cookie_manager_dio', dio, jar: jar);
}

Future<void> _probeLearnHelper() async {
  final helper = Learn2018Helper();
  await _runProbe('learn_helper_dio', helper.dio, jar: helper.cookieJar);
}

Dio _newDio() {
  return Dio(
    BaseOptions(
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) => status != null && status < 500,
      responseType: ResponseType.plain,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
}

Future<void> _runProbe(
  String label,
  Dio dio, {
  CookieJar? jar,
}) async {
  final uri = Uri.parse(urls.idLogin());
  final beforeCookies =
      jar == null ? const <dynamic>[] : await jar.loadForRequest(uri);

  try {
    final response = await dio.get<String>(urls.idLogin());
    final afterCookies =
        jar == null ? const <dynamic>[] : await jar.loadForRequest(uri);
    final body = response.data ?? '';

    print('[$label] status=${response.statusCode}');
    print('[$label] realUri=${response.realUri}');
    print(
      '[$label] requestHeaders=${(response.requestOptions.headers.keys.toList()..sort()).join(',')}',
    );
    print('[$label] beforeCookies=${beforeCookies.length}');
    print('[$label] afterCookies=${afterCookies.length}');
    if (afterCookies.isNotEmpty) {
      print(
        '[$label] cookieNames=${afterCookies.map((cookie) => cookie.name).join(',')}',
      );
    }
    print(
      '[$label] bodyPreview=${body.replaceAll(RegExp(r'\s+'), ' ').substring(0, body.length.clamp(0, 160))}',
    );
  } catch (error, stackTrace) {
    print('[$label] error=$error');
    if (error is DioException) {
      print('[$label] requestUri=${error.requestOptions.uri}');
      print(
        '[$label] requestHeaders=${(error.requestOptions.headers.keys.toList()..sort()).join(',')}',
      );
      print('[$label] contentType=${error.requestOptions.contentType}');
      print('[$label] responseStatus=${error.response?.statusCode}');
      print('[$label] responseUri=${error.response?.realUri}');
      final body = error.response?.data?.toString() ?? '';
      print(
        '[$label] bodyPreview=${body.replaceAll(RegExp(r'\s+'), ' ').substring(0, body.length.clamp(0, 160))}',
      );
    }
    print('[$label] stack=$stackTrace');
  }
}
