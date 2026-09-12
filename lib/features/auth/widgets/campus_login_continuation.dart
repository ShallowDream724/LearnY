import 'dart:async';

import '../../../core/api/learn_api.dart';
import '../../../core/api/registrar_calendar_api.dart';
import '../../../core/api/urls.dart' as urls;
import '../../../core/auth/campus_cookie_bridge.dart';
import 'identity_auth_web_surface.dart';

/// Completes a school-required identity challenge inside the existing login.
class CampusLoginContinuation {
  CampusLoginContinuation({
    required this.api,
    required this.surface,
    required this.onInteractionRequired,
  });

  final Learn2018Helper api;
  final IdentityAuthWebSurfaceController surface;
  final void Function() onInteractionRequired;
  Completer<void>? _completion;
  bool _disposed = false;
  bool _verifying = false;
  String? _latestPage;

  bool get isActive => _completion != null && !_completion!.isCompleted;

  Future<void> prepare() async {
    Uri? loginUri;
    try {
      // Enrollment has already persisted the credential. Use it for the
      // campus service too before asking the student to interact again.
      await _connect(allowCredentialRecovery: true);
    } on RegistrarException catch (error) {
      if (error.failure == RegistrarFailure.identityVerification) {
        loginUri = error.browserEntryUri ?? error.loginUri;
      }
    } catch (_) {
      // A service outage must not block access to Learn and cached coursework.
    }
    if (_disposed) throw StateError('Login cancelled');
    if (loginUri == null) return;
    final completion = Completer<void>();
    _completion = completion;
    onInteractionRequired();
    // Attach the cancellation listener before loading the next browser page.
    final navigation = surface.loadUrl(loginUri.toString()).catchError((
      Object error,
      StackTrace stack,
    ) {
      if (!completion.isCompleted) completion.completeError(error, stack);
    });
    try {
      await Future.wait([navigation, completion.future]);
    } finally {
      _completion = null;
    }
  }

  bool shouldBlockNavigation(String url) {
    final uri = Uri.tryParse(url);
    return uri == null ||
        uri.scheme != 'https' ||
        !CampusCookieBridge.hosts.contains(uri.host);
  }

  Future<void> onPageFinished(String url) async {
    _latestPage = url;
    if (!isActive || _verifying || shouldBlockNavigation(url)) return;
    final uri = Uri.parse(url);
    if (uri.host == 'id.tsinghua.edu.cn' || uri.host == 'oauth.tsinghua.edu.cn') {
      return;
    }
    _verifying = true;
    try {
      final headers = <Uri, String>{};
      // The callback can cross all four services. Export their current browser
      // cookies together, including HttpOnly OAuth/WebVPN session cookies.
      for (final host in CampusCookieBridge.hosts) {
        final destination = host == uri.host
            ? uri
            : host == 'id.tsinghua.edu.cn'
            ? Uri.parse(urls.idLogin())
            : Uri.https(host, '/');
        final header = await surface.getCookieHeaderForUrl(
          destination.toString(),
        );
        if (header?.isNotEmpty == true) headers[destination] = header!;
      }
      if (_disposed || !isActive) return;
      await CampusCookieBridge(api.cookieJar).importHeaders(headers);
      await _connect();
      _complete();
    } on RegistrarException catch (error) {
      if (error.failure != RegistrarFailure.identityVerification) _complete();
    } catch (_) {
      _complete();
    } finally {
      _verifying = false;
      final nextPage = _latestPage;
      if (isActive && nextPage != null && nextPage != url) {
        unawaited(onPageFinished(nextPage));
      }
    }
  }

  Future<void> _connect({bool allowCredentialRecovery = false}) => api
      .establishCampusSession(allowCredentialRecovery: allowCredentialRecovery);

  void _complete() {
    final completion = _completion;
    if (completion != null && !completion.isCompleted) completion.complete();
  }

  void dispose() {
    _disposed = true;
    final completion = _completion;
    if (completion != null && !completion.isCompleted) {
      completion.completeError(StateError('Login cancelled'));
    }
  }
}
