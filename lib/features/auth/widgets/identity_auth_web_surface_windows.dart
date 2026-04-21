import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:webview_windows/webview_windows.dart';

import 'identity_auth_web_surface.dart';

class WindowsIdentityAuthWebSurfaceController
    implements IdentityAuthWebSurfaceController {
  WindowsIdentityAuthWebSurfaceController(this._callbacks);

  final IdentityAuthWebCallbacks _callbacks;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];

  WebviewController? _controller;
  String _currentUrl = '';

  @override
  Future<IdentityAuthWebAvailability> initialize() async {
    final availability =
        await _WindowsIdentityAuthWebEnvironment.ensureInitialized();
    if (!availability.isAvailable) {
      return availability;
    }

    final controller = WebviewController();
    await controller.initialize();
    await controller.setPopupWindowPolicy(WebviewPopupWindowPolicy.sameWindow);
    await controller.setBackgroundColor(Colors.white);

    _subscriptions.add(
      controller.url.listen((url) {
        _currentUrl = url;
        if (_callbacks.onNavigationRequest(url)) {
          unawaited(_stopNavigationSilently());
        }
      }),
    );
    _subscriptions.add(
      controller.loadingState.listen((state) {
        switch (state) {
          case LoadingState.loading:
            _callbacks.onPageStarted(_currentUrl);
            return;
          case LoadingState.navigationCompleted:
            unawaited(_callbacks.onPageFinished(_currentUrl));
            return;
          case LoadingState.none:
            return;
        }
      }),
    );
    _subscriptions.add(
      controller.webMessage.listen(
        (message) {
          _callbacks.onJavaScriptMessage(message);
        },
        onError: (error, stackTrace) {
          debugPrint('[LearnY] Windows auth web message error: $error');
        },
      ),
    );
    _controller = controller;

    return const IdentityAuthWebAvailability.available();
  }

  @override
  Future<void> clearBrowsingData() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    try {
      await controller.clearCookies();
    } catch (_) {}
    try {
      await controller.clearCache();
    } catch (_) {}
  }

  @override
  Future<void> loadUrl(String url) async {
    _currentUrl = url;
    await _controller?.loadUrl(url);
  }

  @override
  Future<void> runJavaScript(String script) async {
    await _controller?.executeScript(script);
  }

  @override
  Future<Object?> runJavaScriptReturningResult(String script) async {
    return _controller?.executeScript(script);
  }

  @override
  Future<String?> getCurrentCookieHeader() async {
    final controller = _controller;
    final currentUrl = _currentUrl.trim();
    if (controller == null || currentUrl.isEmpty) {
      return null;
    }
    final header = await controller.getCookieHeader(currentUrl);
    final normalized = header?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  @override
  Widget buildView() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.white),
      child: Webview(controller, permissionRequested: _onPermissionRequested),
    );
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _stopNavigationSilently() async {
    try {
      await _controller?.stop();
    } catch (_) {}
  }

  Future<WebviewPermissionDecision> _onPermissionRequested(
    String url,
    WebviewPermissionKind permissionKind,
    bool isUserInitiated,
  ) async {
    return WebviewPermissionDecision.deny;
  }
}

class _WindowsIdentityAuthWebEnvironment {
  static Future<IdentityAuthWebAvailability>? _initialization;

  static Future<IdentityAuthWebAvailability> ensureInitialized() async {
    final initialization = _initialization ??= _initialize();
    final availability = await initialization;
    if (!availability.isAvailable) {
      _initialization = null;
    }
    return availability;
  }

  static Future<IdentityAuthWebAvailability> _initialize() async {
    if (!Platform.isWindows) {
      return const IdentityAuthWebAvailability.unavailable('当前平台不支持桌面认证视图');
    }

    final version = await WebviewController.getWebViewVersion();
    if (version == null || version.trim().isEmpty) {
      return const IdentityAuthWebAvailability.missingRuntime(
        '此设备缺少 Microsoft Edge WebView2 Runtime，无法显示统一身份认证页面。',
      );
    }

    final supportDirectory = await getApplicationSupportDirectory();
    final userDataDirectory = Directory(
      path.join(supportDirectory.path, 'windows_auth_webview'),
    );
    await userDataDirectory.create(recursive: true);

    try {
      await WebviewController.initializeEnvironment(
        userDataPath: userDataDirectory.path,
      );
    } on PlatformException catch (error) {
      if (error.code == 'environment_already_initialized') {
        return const IdentityAuthWebAvailability.available();
      }
      return IdentityAuthWebAvailability.unavailable(
        error.message ?? 'Windows 认证环境初始化失败',
      );
    } catch (error) {
      return IdentityAuthWebAvailability.unavailable(
        'Windows 认证环境初始化失败：$error',
      );
    }

    return const IdentityAuthWebAvailability.available();
  }
}
