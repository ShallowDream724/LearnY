import 'package:html/parser.dart' as html;

import 'urls.dart' as urls;

bool isIdentityLoginUri(Uri? uri) {
  if (uri == null) return false;
  return uri.host == Uri.parse(urls.idPrefix).host ||
      uri.path.contains('login_timeout') ||
      uri.queryParameters.containsKey('login_timeout') ||
      uri.path.contains('/do/off/ui/auth/login/');
}

bool looksLikeIdentityLoginPage(String source) {
  if (!source.trimLeft().startsWith('<')) return false;
  final page = html.parse(source);
  return page.querySelector(
            '#sm2publicKey, input[name="i_user"], input[name="i_pass"]',
          ) !=
          null ||
      page.querySelector('title')?.text.contains('统一身份认证') == true;
}

/// Detect school error pages structurally, without interpreting course prose
/// or an ordinary HTML attachment as a request to submit credentials.
bool looksLikeLearnSessionExpiredPage(String source) {
  if (!source.trimLeft().startsWith('<')) return false;
  final page = html.parse(source);
  if (page.querySelector('title')?.text.trim() == '登录超时') return true;
  final panel = page.querySelector('.bground');
  if (panel == null) return false;
  if (panel.querySelector('.infoo')?.text.trim() == '您未登录或登录失效') return true;
  return panel.querySelector(r'img[src$="/log_fail.png"]') != null &&
      panel.querySelector('.chongxin')?.text.trim() == '登录网络学堂' &&
      RegExp(r'错误码为\s*[:：]\s*(401|403)\b').hasMatch(panel.text);
}

bool isLearnAssetUri(Uri uri) =>
    uri.scheme == 'https' && uri.host == Uri.parse(urls.learnPrefix).host;

/// Called separately on each attempt, so a retry uses the renewed CSRF token.
Uri withLearnAssetCsrf(Uri uri, String token) {
  if (!isLearnAssetUri(uri) || token.isEmpty) return uri;
  return uri.replace(
    queryParameters: {
      ...uri.queryParametersAll,
      '_csrf': [token],
    },
  );
}
