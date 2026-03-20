/// WebView-based SSO login screen — with proper Dio session handoff.
///
/// ## How it works
///
/// The original JS library does:
/// 1. POST login form with SM2-encrypted password to id.tsinghua.edu.cn
/// 2. Extract a `ticket` (like `ST-XXXXX`) from the response page
/// 3. Use the ticket to call `learn.tsinghua.edu.cn/b/j_spring_security_thauth_roaming_entry?ticket=XXX`
/// 4. This sets session cookies and authenticates the user
/// 5. Then fetch the course list page to extract the CSRF token
///
/// In our WebView approach:
/// 1. Load the id.tsinghua.edu.cn login page in a WebView
/// 2. The WebView handles SM2 encryption natively (the page's own JS does it)
/// 3. After successful login, the page produces a redirect containing the ticket
/// 4. We monitor WebView navigation for URLs matching the ticket pattern
/// 5. When we detect the ticket redirect, we:
///    a. Block the WebView from consuming it
///    b. Extract the ticket string
///    c. Use Dio to call learnAuthRoam(ticket) — Dio gets the session cookies
///    d. Use Dio to fetch the course list page for the CSRF token
/// 6. Now Dio is fully authenticated and the API client works
///
/// ## Why not just extract cookies from the WebView?
///
/// Session cookies are typically HttpOnly, so `document.cookie` in JS
/// won't return them. Platform-specific cookie extraction is fragile.
/// The ticket interception approach is clean and reliable.
///
/// ## Fallback
///
/// If ticket interception fails (URL pattern changed), we fall back to
/// extracting cookies via the WebView's cookie manager and injecting
/// them into Dio's CookieJar.
import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/api/urls.dart' as urls;
import '../../core/api/learn_api.dart';
import '../../core/router/router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _showWebView = false;
  bool _isLoading = false;
  bool _isProcessingTicket = false;
  String? _errorMessage;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onNavigationRequest: _onNavigationRequest,
        ),
      );
  }

  // ─────────────────────────────────────────────
  //  Core login flow
  // ─────────────────────────────────────────────

  void _startLogin() {
    setState(() {
      _showWebView = true;
      _isLoading = true;
      _isProcessingTicket = false;
      _errorMessage = null;
    });
    // Load the id.tsinghua login page.
    // The form's `action` handles SM2 encryption via its own JS.
    _webViewController.loadRequest(Uri.parse(urls.idLogin()));
  }

  void _onPageStarted(String url) {
    if (mounted && !_isProcessingTicket) {
      setState(() => _isLoading = true);
    }
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted || _isProcessingTicket) return;
    setState(() => _isLoading = false);

    // Fallback detection: if the WebView somehow ends up at learn.tsinghua
    // (meaning the ticket was consumed by the WebView before we could
    // intercept it), try the cookie-extraction fallback.
    if (url.startsWith(urls.learnPrefix) &&
        !url.contains('j_spring_security_thauth_roaming_entry') &&
        !_isProcessingTicket) {
      await _fallbackCookieExtraction();
    }
  }

  /// This is the critical method: we watch every WebView navigation.
  /// When we see the ticket URL (learn auth roaming), we intercept it.
  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final targetUrl = request.url;

    // Pattern: learn.tsinghua.edu.cn/b/j_spring_security_thauth_roaming_entry?ticket=XXX
    if (targetUrl.contains('j_spring_security_thauth_roaming_entry') &&
        targetUrl.contains('ticket=')) {
      // Extract ticket from URL
      final uri = Uri.parse(targetUrl);
      final ticket = uri.queryParameters['ticket'];

      if (ticket != null && ticket.isNotEmpty) {
        // Block the WebView — we'll use Dio to consume this ticket
        _consumeTicketWithDio(ticket);
        return NavigationDecision.prevent;
      }
    }

    // Also check: sometimes the redirect goes through id.tsinghua first
    // with a URL like id.tsinghua.edu.cn/.../callback?ticket=ST-XXXX
    // and then redirects to learn. Catch this pattern too.
    if (targetUrl.contains('id.tsinghua.edu.cn') &&
        targetUrl.contains('ticket=') &&
        !targetUrl.contains('login/form')) {
      // This might be the intermediate redirect.
      // Let the WebView follow it — it will eventually redirect to learn,
      // which we'll catch above.
    }

    // Allow all other navigation during the SSO flow
    return NavigationDecision.navigate;
  }

  // ─────────────────────────────────────────────
  //  Primary path: ticket interception
  // ─────────────────────────────────────────────

  /// We have the ticket. Now use Dio to:
  /// 1. Call learnAuthRoam(ticket) → Dio gets session cookies
  /// 2. Fetch the course list page → extract CSRF token
  /// 3. Extract username from the page
  Future<void> _consumeTicketWithDio(String ticket) async {
    if (_isProcessingTicket) return;
    _isProcessingTicket = true;

    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);

      // Authenticate Dio's session using the SSO ticket.
      // This internally: (1) follows the 302 redirect chain with cookie
      // tracking, (2) fetches the course list page, (3) extracts the CSRF
      // token and language preference.
      await api.loginWithTicket(ticket);

      // Fetch username from the authenticated session.
      final userInfo = await api.getUserInfo();
      final username = userInfo.name;

      // Mark login as successful.
      // Router will automatically redirect to home via auth state listener.
      await ref.read(authProvider.notifier).onLoginSuccess(username);
    } catch (e, stackTrace) {
      debugPrint('[LearnX] Login failed: $e');
      debugPrint('[LearnX] Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = '登录认证失败: ${_truncateError(e.toString())}';
          _showWebView = false;
          _isLoading = false;
          _isProcessingTicket = false;
        });
      }
    }
  }

  // ─────────────────────────────────────────────
  //  Fallback: cookie extraction from WebView
  // ─────────────────────────────────────────────

  /// If the ticket interception didn't work (WebView consumed the ticket
  /// before we could intercept it), try extracting what we need from the
  /// WebView itself. This is less reliable but serves as a safety net.
  Future<void> _fallbackCookieExtraction() async {
    if (_isProcessingTicket) return;
    _isProcessingTicket = true;
    setState(() => _isLoading = true);

    try {
      // Wait for the page to fully render
      await Future.delayed(const Duration(seconds: 2));

      // Try to navigate to the course list page in the WebView
      await _webViewController.loadRequest(
        Uri.parse(urls.learnStudentCourseListPage()),
      );
      await Future.delayed(const Duration(seconds: 3));

      // Extract CSRF token via JavaScript
      final rawHtml = await _webViewController.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );

      // The returned value might be JSON-encoded string (with surrounding quotes)
      String pageSource = rawHtml.toString();
      if (pageSource.startsWith('"') && pageSource.endsWith('"')) {
        pageSource = pageSource.substring(1, pageSource.length - 1);
        // Unescape JSON string escapes
        pageSource = pageSource
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\"', '"')
            .replaceAll(r'\\', r'\')
            .replaceAll(r'\/', '/');
      }

      // Extract CSRF token using multiple patterns (same logic as primary path)
      String? csrfToken;
      final p1 = RegExp(r'[&?]_csrf=([a-zA-Z0-9\-_]+)', multiLine: true);
      final m1 = p1.firstMatch(pageSource);
      if (m1 != null) csrfToken = m1.group(1);

      if (csrfToken == null) {
        final p2 = RegExp(r'&_csrf=(\S*)"', multiLine: true);
        final m2 = p2.firstMatch(pageSource);
        if (m2 != null) csrfToken = m2.group(1);
      }

      if (csrfToken == null || csrfToken.isEmpty) {
        debugPrint(
          '[LearnY] Fallback CSRF extraction failed. '
          'Page length: ${pageSource.length}',
        );
        throw Exception('Fallback: could not find CSRF token in page');
      }

      final api = ref.read(apiClientProvider);
      api.setCSRFToken(csrfToken);

      // Extract username
      final nameRegex = RegExp(r'class="user-log"[^>]*>([^<]+)<');
      final nameMatch = nameRegex.firstMatch(pageSource);
      final username = nameMatch?.group(1)?.trim() ?? '';

      // Now: the WebView has the session, but Dio doesn't.
      // Extract cookies from the WebView and inject into Dio's CookieJar.
      await _transferWebViewCookiesToDio(api);

      await ref.read(authProvider.notifier).onLoginSuccess(username);

      if (mounted) {
        context.go(Routes.home);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '认证回退失败: ${_truncateError(e.toString())}';
          _showWebView = false;
          _isLoading = false;
          _isProcessingTicket = false;
        });
      }
    }
  }

  /// Extract all cookies from WebView via JS and inject into Dio's CookieJar.
  /// Note: HttpOnly cookies won't be accessible via `document.cookie`.
  /// This is a best-effort fallback.
  Future<void> _transferWebViewCookiesToDio(Learn2018Helper api) async {
    try {
      // Get JavaScript-accessible cookies (non-HttpOnly only)
      final cookieStr = await _webViewController.runJavaScriptReturningResult(
        'document.cookie',
      );

      String cookieString = cookieStr.toString();
      if (cookieString.startsWith('"') && cookieString.endsWith('"')) {
        cookieString = cookieString.substring(1, cookieString.length - 1);
      }

      if (cookieString.isEmpty) return;

      // Parse cookie string: "key1=val1; key2=val2; ..."
      final cookies = cookieString.split(';').map((pair) {
        final parts = pair.trim().split('=');
        if (parts.length >= 2) {
          return Cookie(parts[0].trim(), parts.sublist(1).join('=').trim());
        }
        return null;
      }).whereType<Cookie>();

      // Inject into Dio's CookieJar
      final cookieJar = _getCookieJarFromHelper(api);
      if (cookieJar != null) {
        final learnUri = Uri.parse(urls.learnPrefix);
        final idUri = Uri.parse(urls.idPrefix);

        for (final cookie in cookies) {
          await cookieJar.saveFromResponse(learnUri, [cookie]);
          await cookieJar.saveFromResponse(idUri, [cookie]);
        }
      }
    } catch (_) {
      // Best-effort: if this fails, the CSRF token approach might still work
      // for some endpoints, or the user will need to re-login.
    }
  }

  // ─────────────────────────────────────────────
  //  Helpers: access private Dio instance
  // ─────────────────────────────────────────────

  /// Access the Dio instance from Learn2018Helper.
  /// This is needed because the helper's Dio has cookie management set up.
  CookieJar? _getCookieJarFromHelper(Learn2018Helper helper) {
    return helper.cookieJar;
  }

  String _truncateError(String error) {
    if (error.length > 80) return '${error.substring(0, 77)}...';
    return error;
  }

  // ─────────────────────────────────────────────
  //  Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_showWebView) {
      return _buildWebViewScreen();
    }
    return _buildBrandedScreen();
  }

  // ─────────────────────────────────────────────
  //  Branded login splash
  // ─────────────────────────────────────────────

  Widget _buildBrandedScreen() {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo
              _buildLogo()
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                  .slideY(begin: -0.1, end: 0),

              const SizedBox(height: 28),

              // Title
              Text(
                    'LearnY',
                    style: AppTypography.statLarge.copyWith(
                      color: c.text,
                      letterSpacing: -1.5,
                    ),
                  )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 8),

              // Subtitle
              Text(
                '清华大学网络学堂',
                style: AppTypography.bodyLarge.copyWith(
                  color: c.subtitle,
                  letterSpacing: 2,
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 500.ms),

              const Spacer(flex: 2),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Login button
              SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _startLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              '统一身份认证登录',
                              style: AppTypography.labelLarge.copyWith(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  )
                  .animate(delay: 600.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.15, end: 0),

              const SizedBox(height: 16),

              // Version info
              Text(
                'v0.1.0',
                style: AppTypography.bodySmall.copyWith(
                  color: c.subtitle.withAlpha(120),
                ),
              ).animate(delay: 800.ms).fadeIn(duration: 400.ms),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(context.isDark ? 60 : 40),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Icon(Icons.school_rounded, size: 42, color: Colors.white),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  WebView login screen
  // ─────────────────────────────────────────────

  Widget _buildWebViewScreen() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            setState(() {
              _showWebView = false;
              _isLoading = false;
              _isProcessingTicket = false;
            });
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('统一身份认证'),
            if (_isProcessingTicket)
              Text(
                '正在验证登录信息...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.primary,
                ),
              ),
          ],
        ),
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      body: _isProcessingTicket
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    '正在建立安全会话...',
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.colors.subtitle,
                    ),
                  ),
                ],
              ),
            )
          : WebViewWidget(controller: _webViewController),
    );
  }
}
