import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'identity_auth_web_surface.dart';

class MobileIdentityAuthWebSurfaceController
    implements IdentityAuthWebSurfaceController {
  MobileIdentityAuthWebSurfaceController(this._callbacks);

  final IdentityAuthWebCallbacks _callbacks;
  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  late final WebViewController _controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..addJavaScriptChannel(
      _channelName,
      onMessageReceived: (message) {
        _callbacks.onJavaScriptMessage(message.message);
      },
    )
    ..setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: _callbacks.onPageStarted,
        onPageFinished: (url) {
          _callbacks.onPageFinished(url);
        },
        onNavigationRequest: (request) {
          final consumed = _callbacks.onNavigationRequest(request.url);
          return consumed
              ? NavigationDecision.prevent
              : NavigationDecision.navigate;
        },
      ),
    );

  static const String _channelName = 'LearnYIdentityAuth';

  @override
  Future<IdentityAuthWebAvailability> initialize() async {
    return const IdentityAuthWebAvailability.available();
  }

  @override
  Future<void> clearBrowsingData() async {
    try {
      await _controller.clearLocalStorage();
    } catch (_) {}
    await _cookieManager.clearCookies();
  }

  @override
  Future<void> loadUrl(String url) {
    return _controller.loadRequest(Uri.parse(url));
  }

  @override
  Future<void> runJavaScript(String script) {
    return _controller.runJavaScript(script);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) {
    return _controller.runJavaScriptReturningResult(script);
  }

  @override
  Future<String?> getCurrentCookieHeader() async {
    final raw = await _controller.runJavaScriptReturningResult(
      'document.cookie',
    );
    return _normalizeJavaScriptStringResult(raw);
  }

  @override
  Widget buildView() {
    return WebViewWidget(controller: _controller);
  }

  @override
  Future<void> dispose() async {}

  String? _normalizeJavaScriptStringResult(Object? raw) {
    if (raw == null) {
      return null;
    }
    final value = raw.toString().trim();
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      return value
          .substring(1, value.length - 1)
          .replaceAll(r'\"', '"')
          .replaceAll(r'\\', '\\');
    }
    return value;
  }
}
