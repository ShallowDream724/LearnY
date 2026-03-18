/// WebView-based SSO login screen.
///
/// Flow:
/// 1. Show branded splash with login button
/// 2. User taps → opens WebView to id.tsinghua.edu.cn
/// 3. WebView follows redirects until learn.tsinghua.edu.cn is reached
/// 4. Extract cookies + CSRF token from the loaded page
/// 5. Pass credentials to API client and navigate to home
///
/// This bypasses the SM2 encryption entirely — the WebView handles it natively.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/api/urls.dart' as urls;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _showWebView = false;
  bool _isLoading = false;
  String? _errorMessage;
  late final WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: _onPageStarted,
        onPageFinished: _onPageFinished,
        onNavigationRequest: _onNavigationRequest,
      ));
  }

  void _startLogin() {
    setState(() {
      _showWebView = true;
      _isLoading = true;
      _errorMessage = null;
    });
    _webViewController.loadRequest(Uri.parse(urls.idLogin()));
  }

  void _onPageStarted(String url) {
    if (mounted) setState(() => _isLoading = true);
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Check if we've been redirected to the learn platform
    if (url.startsWith(urls.learnPrefix)) {
      await _extractCredentials();
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    // Allow all navigation during the SSO flow
    return NavigationDecision.navigate;
  }

  Future<void> _extractCredentials() async {
    try {
      setState(() => _isLoading = true);

      // Navigate to the student course list to get CSRF token
      await _webViewController
          .loadRequest(Uri.parse(urls.learnStudentCourseListPage()));

      // Wait briefly for the page to load
      await Future.delayed(const Duration(seconds: 2));

      // Extract page source to get CSRF token
      final pageSource = await _webViewController
          .runJavaScriptReturningResult('document.documentElement.outerHTML')
          as String;

      // Extract CSRF token
      final tokenRegex = RegExp(r'&_csrf=(\S*)"');
      final tokenMatch = tokenRegex.firstMatch(pageSource);

      if (tokenMatch == null) {
        setState(() {
          _errorMessage = '无法获取认证令牌，请重试';
          _showWebView = false;
          _isLoading = false;
        });
        return;
      }

      final csrfToken = tokenMatch.group(1)!;

      // Extract username from the page
      final nameRegex = RegExp(r'class="user-log"[^>]*>([^<]+)<');
      final nameMatch = nameRegex.firstMatch(pageSource);
      final username = nameMatch?.group(1)?.trim() ?? '';

      // Set CSRF token on the API client
      final api = ref.read(apiClientProvider);
      api.setCSRFToken(csrfToken);

      // Mark as logged in
      await ref.read(authProvider.notifier).onLoginSuccess(username);

      if (mounted) {
        setState(() {
          _showWebView = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '登录过程出错: ${e.toString().substring(0, 50)}';
          _showWebView = false;
          _isLoading = false;
        });
      }
    }
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtitleColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Logo
              _buildLogo(isDark)
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                  .slideY(begin: -0.1, end: 0),

              const SizedBox(height: 28),

              // Title
              Text(
                'LearnY',
                style: AppTypography.statLarge.copyWith(
                  color: textColor,
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
                  color: subtitleColor,
                  letterSpacing: 2,
                ),
              )
                  .animate(delay: 400.ms)
                  .fadeIn(duration: 500.ms),

              const Spacer(flex: 2),

              // Error message
              if (_errorMessage != null) ...[
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withAlpha(60)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: AppTypography.bodySmall
                              .copyWith(color: AppColors.error),
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
                  color: subtitleColor.withAlpha(120),
                ),
              ).animate(delay: 800.ms).fadeIn(duration: 400.ms),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(isDark ? 60 : 40),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.school_rounded,
          size: 42,
          color: Colors.white,
        ),
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
            });
          },
        ),
        title: const Text('清华大学统一身份认证'),
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
      body: WebViewWidget(controller: _webViewController),
    );
  }
}
