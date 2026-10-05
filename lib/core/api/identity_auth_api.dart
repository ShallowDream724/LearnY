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

class IdentityAuthDeferredException implements Exception {
  const IdentityAuthDeferredException(this.retryAfter);
  final Duration retryAfter;
  @override
  String toString() => 'Identity authentication is temporarily deferred';
}

/// The identity server keeps the destination service in its login session.
/// Serialize form loading and submission so parallel services cannot replace it.
class IdentityAuthApi {
  IdentityAuthApi(this._dio, this._cookies);

  final Dio _dio;
  final CookieJar _cookies;
  Future<void> _tail = Future.value();
  DateTime? _lastPasswordSubmission;
  String? _lastPasswordUsername;

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
      var page = await _loadForm(loginUri);
      if (page.statusCode != 200) return page;
      if (html.parse(page.data ?? '').getElementById('sm2publicKey') == null &&
          supportsSingleLoginShortcut(page.data ?? '')) {
        final shortcut =
            await _submit(urls.idLoginCheckSingle(), loginUri, <String, String>{
              'i_rememberme': 'on',
              'fingerPrint': credential.fingerPrint ?? '',
              'fingerGenPrint': credential.fingerGenPrint ?? '',
            });
        final source = shortcut.data ?? '';
        final target = shortcut.headers.value('location');
        final redirect = target == null ? null : loginUri.resolve(target);
        final backToForm =
            redirect?.host == loginUri.host &&
            redirect!.path.startsWith('/do/off/ui/auth/login/form/');
        final key = html.parse(source).getElementById('sm2publicKey');
        if (shortcut.statusCode == 200 && key != null) {
          page = shortcut;
        } else if (backToForm ||
            (shortcut.statusCode == 200 &&
                supportsSingleLoginShortcut(source))) {
          // A remembered-browser rejection is not a rejected password. Start
          // one fresh form for this service, then submit the saved password once.
          await _cookies.delete(Uri.parse(urls.idPrefix));
          page = await _loadForm(loginUri);
        } else {
          return shortcut;
        }
      }
      final document = html.parse(page.data ?? '');
      final publicKey = document.getElementById('sm2publicKey');
      if (page.statusCode != 200 || publicKey == null) return page;
      final now = DateTime.now();
      final previous = _lastPasswordSubmission;
      if (previous != null && _lastPasswordUsername == credential.username) {
        final remaining = const Duration(minutes: 1) - now.difference(previous);
        if (remaining > Duration.zero) {
          throw IdentityAuthDeferredException(remaining);
        }
      }
      _lastPasswordSubmission = now;
      _lastPasswordUsername = credential.username;
      return _submit(
        urls.idLoginCheck(),
        loginUri,
        buildIdentityCheckFormData(
          username: credential.username ?? '',
          encryptedPassword: encryptIdentityPassword(
            credential.password ?? '',
            publicKey.text.trim(),
          ),
          fingerPrint: credential.fingerPrint ?? '',
          fingerGenPrint: credential.fingerGenPrint ?? '',
          fingerGenPrint3: credential.fingerGenPrint3 ?? '',
          deviceName: credential.deviceName ?? '',
          includeSingleLogin: credential.singleLoginEnabled,
        ),
      );
    });
    _tail = task.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return task;
  }

  Future<Response<String>> _loadForm(Uri uri) => _dio.get<String>(
    uri.toString(),
    options: Options(
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.plain,
    ),
  );

  Future<Response<String>> _submit(
    String url,
    Uri referer,
    Map<String, String> payload,
  ) => _dio.post<String>(
    url,
    data: payload,
    options: Options(
      contentType: Headers.formUrlEncodedContentType,
      headers: buildIdentityCheckHeaders(referer: referer.toString()),
      followRedirects: false,
      validateStatus: (_) => true,
      responseType: ResponseType.plain,
    ),
  );
}

bool supportsSingleLoginShortcut(String source) {
  final endpoint = Uri.parse(urls.idLoginCheckSingle());
  return html.parse(source).querySelectorAll('form[action]').any((form) {
    final action = form.attributes['action']?.trim() ?? '';
    if (action.isEmpty || action.startsWith('#')) return false;
    final target = Uri.tryParse(action);
    if (target == null) return false;
    final resolved = endpoint.resolveUri(target);
    return resolved.scheme == endpoint.scheme &&
        resolved.host == endpoint.host &&
        resolved.path == endpoint.path;
  });
}

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
