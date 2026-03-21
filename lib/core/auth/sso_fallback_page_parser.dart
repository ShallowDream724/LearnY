import 'package:flutter_riverpod/flutter_riverpod.dart';

class SsoFallbackPageSnapshot {
  const SsoFallbackPageSnapshot({
    required this.csrfToken,
    required this.username,
  });

  final String csrfToken;
  final String username;
}

class SsoFallbackParseException implements Exception {
  const SsoFallbackParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SsoFallbackPageParser {
  const SsoFallbackPageParser();

  SsoFallbackPageSnapshot parse(String rawJavaScriptResult) {
    final pageSource = _normalizeJavaScriptHtmlResult(rawJavaScriptResult);
    final csrfToken = _extractCsrfToken(pageSource);
    if (csrfToken == null || csrfToken.isEmpty) {
      throw const SsoFallbackParseException(
        'Fallback: could not find CSRF token in page',
      );
    }

    return SsoFallbackPageSnapshot(
      csrfToken: csrfToken,
      username: _extractUsername(pageSource),
    );
  }

  String _normalizeJavaScriptHtmlResult(String rawHtml) {
    var pageSource = rawHtml;
    if (pageSource.startsWith('"') && pageSource.endsWith('"')) {
      pageSource = pageSource.substring(1, pageSource.length - 1);
      pageSource = pageSource
          .replaceAll(r'\n', '\n')
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', r'\')
          .replaceAll(r'\/', '/');
    }
    return pageSource;
  }

  String? _extractCsrfToken(String pageSource) {
    final patterns = <RegExp>[
      RegExp(r'[&?]_csrf=([a-zA-Z0-9\-_]+)', multiLine: true),
      RegExp(r'&_csrf=(\S*)"', multiLine: true),
      RegExp(r'name="_csrf"\s+value="([a-zA-Z0-9\-_]+)"', multiLine: true),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(pageSource);
      final token = match?.group(1);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    }
    return null;
  }

  String _extractUsername(String pageSource) {
    final nameRegex = RegExp(r'class="user-log"[^>]*>([^<]+)<');
    return nameRegex.firstMatch(pageSource)?.group(1)?.trim() ?? '';
  }
}

final ssoFallbackPageParserProvider = Provider<SsoFallbackPageParser>((ref) {
  return const SsoFallbackPageParser();
});
