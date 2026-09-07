import 'package:cookie_jar/cookie_jar.dart';
import 'package:dart_sm/dart_sm.dart';
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;

import 'urls.dart' as urls;

class Credential {
  const Credential({
    this.username,
    this.password,
    this.fingerPrint,
    this.fingerGenPrint,
    this.fingerGenPrint3,
    this.deviceName,
    this.singleLoginEnabled = false,
  });

  final String? username;
  final String? password;
  final String? fingerPrint;
  final String? fingerGenPrint;
  final String? fingerGenPrint3;
  final String? deviceName;
  final bool singleLoginEnabled;
}

typedef CredentialProvider = Future<Credential> Function();

/// The identity server keeps the destination service in its login session.
/// Serialize form loading and submission so parallel services cannot replace it.
class IdentityAuthApi {
  IdentityAuthApi(this._dio, this._cookies);

  final Dio _dio;
  final CookieJar _cookies;
  Future<void> _tail = Future.value();

  Future<Response<String>> authenticate(
    Uri loginUri,
    Credential credential, {
    bool resetSession = false,
  }) {
    final task = _tail.then((_) async {
      if (loginUri.scheme != 'https' ||
          loginUri.host != Uri.parse(urls.idPrefix).host ||
          !loginUri.path.startsWith('/do/off/ui/auth/login/form/')) {
        throw ArgumentError('Unsupported identity login endpoint');
      }
      if (resetSession) await _cookies.delete(Uri.parse(urls.idPrefix));
      final page = await _dio.get<String>(
        loginUri.toString(),
        options: Options(
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
        ),
      );
      if (page.statusCode != 200) return page;
      final source = page.data ?? '';
      final document = html.parse(source);
      final singleLogin = supportsSingleLoginShortcut(source);
      if (!singleLogin && document.getElementById('sm2publicKey') == null) {
        return page;
      }
      final payload = singleLogin
          ? <String, String>{
              'i_rememberme': 'on',
              'fingerPrint': credential.fingerPrint ?? '',
              'fingerGenPrint': credential.fingerGenPrint ?? '',
            }
          : buildIdentityCheckFormData(
              username: credential.username ?? '',
              encryptedPassword: encryptIdentityPassword(
                credential.password ?? '',
                document.getElementById('sm2publicKey')!.text.trim(),
              ),
              fingerPrint: credential.fingerPrint ?? '',
              fingerGenPrint: credential.fingerGenPrint ?? '',
              fingerGenPrint3: credential.fingerGenPrint3 ?? '',
              deviceName: credential.deviceName ?? '',
              includeSingleLogin: credential.singleLoginEnabled,
            );
      return _dio.post<String>(
        singleLogin ? urls.idLoginCheckSingle() : urls.idLoginCheck(),
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          headers: buildIdentityCheckHeaders(referer: loginUri.toString()),
          followRedirects: false,
          validateStatus: (_) => true,
          responseType: ResponseType.plain,
        ),
      );
    });
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }
}

bool supportsSingleLoginShortcut(String source) =>
    source.contains('checkSingle');

Map<String, String> buildIdentityCheckFormData({
  required String username,
  required String encryptedPassword,
  required String fingerPrint,
  String fingerGenPrint = '',
  String fingerGenPrint3 = '',
  String deviceName = '',
  bool includeSingleLogin = false,
}) => {
  'i_user': username,
  'i_pass': encryptedPassword,
  if (includeSingleLogin) 'singleLogin': 'on',
  'fingerPrint': fingerPrint,
  'fingerGenPrint': fingerGenPrint,
  'fingerGenPrint3': fingerGenPrint3,
  'i_captcha': '',
  if (deviceName.trim().isNotEmpty) 'deviceName': deviceName.trim(),
};

Map<String, String> buildIdentityCheckHeaders({required String referer}) => {
  'Origin': urls.idPrefix,
  'Referer': referer,
};

String encryptIdentityPassword(String password, String publicKey) {
  final encrypted = SM2.encrypt(password, publicKey);
  return encrypted.startsWith('04') ? encrypted : '04$encrypted';
}
