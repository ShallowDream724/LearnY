import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/api/enums.dart';
import '../../../core/api/models.dart';
import '../../../core/api/urls.dart' as urls;
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/providers.dart';
import 'auto_relogin_setup_dialog.dart';

class AutoReloginEnrollmentScreen extends ConsumerStatefulWidget {
  const AutoReloginEnrollmentScreen({
    super.key,
    required this.input,
  });

  final AutoReloginSetupInput input;

  @override
  ConsumerState<AutoReloginEnrollmentScreen> createState() =>
      _AutoReloginEnrollmentScreenState();
}

class _AutoReloginEnrollmentScreenState
    extends ConsumerState<AutoReloginEnrollmentScreen> {
  static const _channelName = 'LearnYAutoRelogin';

  final WebViewCookieManager _cookieManager = WebViewCookieManager();

  late final WebViewController _webViewController;

  Map<String, String>? _capturedFormData;
  bool _isPageLoading = true;
  bool _isProcessingTicket = false;
  bool _didAttemptAutoSubmit = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        _channelName,
        onMessageReceived: _handleJavaScriptMessage,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: _onPageStarted,
          onPageFinished: _onPageFinished,
          onNavigationRequest: _onNavigationRequest,
        ),
      );
    unawaited(_prepareFreshLoginPage());
  }

  Future<void> _prepareFreshLoginPage() async {
    await _cookieManager.clearCookies();
    await _webViewController.loadRequest(Uri.parse(urls.idLogin()));
  }

  void _onPageStarted(String _) {
    if (!mounted || _isProcessingTicket) {
      return;
    }
    setState(() {
      _isPageLoading = true;
      _errorMessage = null;
    });
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted || _isProcessingTicket) {
      return;
    }

    setState(() {
      _isPageLoading = false;
    });

    final uri = Uri.tryParse(url);
    if (uri?.host != Uri.parse(urls.idPrefix).host) {
      return;
    }

    final shouldAutoSubmit = !_didAttemptAutoSubmit;
    if (shouldAutoSubmit) {
      _didAttemptAutoSubmit = true;
    }

    try {
      await _webViewController.runJavaScript(
        _buildInjectionScript(shouldAutoSubmit: shouldAutoSubmit),
      );
      final inlineError = await _readInlineLoginError();
      if (!mounted || inlineError == null || inlineError.isEmpty) {
        return;
      }
      setState(() {
        _errorMessage = inlineError;
      });
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Auto relogin enrollment inject failed: $error');
      debugPrint('$stackTrace');
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final instruction = ref
        .read(ssoTicketParserProvider)
        .inspectNavigation(request.url);
    if (instruction.shouldConsumeTicket && instruction.ticket != null) {
      unawaited(_handleTicket(instruction.ticket!));
      return NavigationDecision.prevent;
    }
    return NavigationDecision.navigate;
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    try {
      final raw = jsonDecode(message.message) as Map<String, dynamic>;
      if (raw['type'] != 'loginForm') {
        return;
      }
      final data = raw['data'];
      if (data is! Map) {
        return;
      }
      _capturedFormData = data.map<String, String>(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
    } catch (error) {
      debugPrint('[LearnY] Failed to decode enrollment payload: $error');
    }
  }

  Future<void> _handleTicket(String ticket) async {
    if (_isProcessingTicket) {
      return;
    }

    setState(() {
      _isProcessingTicket = true;
      _isPageLoading = true;
      _errorMessage = null;
    });

    try {
      final capturedFormData =
          _capturedFormData ?? await _readCurrentFormDataFromPage();
      final resolvedUsername =
          (capturedFormData['i_user'] ?? widget.input.username).trim();
      final fingerPrint = (capturedFormData['fingerPrint'] ?? '').trim();
      final fingerGenPrint3 = capturedFormData['fingerGenPrint3'] ?? '';
      final fingerGenPrint =
          (capturedFormData['fingerGenPrint'] ?? '').trim().isNotEmpty
          ? capturedFormData['fingerGenPrint']!.trim()
          : fingerGenPrint3;
      final deviceName = capturedFormData['deviceName'] ?? '';

      if (resolvedUsername.isEmpty || fingerPrint.isEmpty) {
        throw const ApiError(reason: FailReason.invalidResponse);
      }

      await ref.read(ssoLoginCoordinatorProvider).consumeTicket(ticket);
      await ref.read(authReloginServiceProvider).saveVerifiedCredential(
        username: resolvedUsername,
        password: widget.input.password,
        fingerPrint: fingerPrint,
        fingerGenPrint: fingerGenPrint,
        fingerGenPrint3: fingerGenPrint3,
        deviceName: deviceName,
      );
      await ref.read(autoReloginEnabledProvider.notifier).setEnabled(true);
      ref.invalidate(storedCredentialAvailabilityProvider);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapApiError(error);
        _isProcessingTicket = false;
        _isPageLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Auto relogin enrollment failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '验证失败，请稍后重试';
        _isProcessingTicket = false;
        _isPageLoading = false;
      });
    }
  }

  Future<Map<String, String>> _readCurrentFormDataFromPage() async {
    final raw = await _webViewController.runJavaScriptReturningResult('''
      (function() {
        const data = {};
        const ids = ['i_user', 'fingerPrint', 'fingerGenPrint', 'fingerGenPrint3', 'deviceName'];
        for (const id of ids) {
          const element = document.getElementById(id);
          if (element && 'value' in element) {
            data[id] = element.value || '';
          }
        }
        return JSON.stringify(data);
      })();
    ''');
    return _decodeStringMapResult(raw);
  }

  Future<String?> _readInlineLoginError() async {
    final raw = await _webViewController.runJavaScriptReturningResult('''
      (function() {
        const selectors = ['#msg_note', '#c_note .red', '.alert-danger', '.red'];
        for (const selector of selectors) {
          const element = document.querySelector(selector);
          const text = (element && element.innerText) ? element.innerText.trim() : '';
          if (text) {
            return text;
          }
        }
        return '';
      })();
    ''');
    final message = _decodeStringResult(raw).trim();
    if (message.isEmpty) {
      return null;
    }
    if (message.contains('用户名或密码不正确') || message.contains('请重试')) {
      return '统一身份账号或密码不正确';
    }
    if (message.contains('验证码')) {
      return '请完成验证码后继续登录';
    }
    return null;
  }

  Map<String, String> _decodeStringMapResult(Object raw) {
    final decoded = jsonDecode(_decodeStringResult(raw)) as Map<String, dynamic>;
    return decoded.map<String, String>(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  String _decodeStringResult(Object raw) {
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is String) {
          return decoded;
        }
      } catch (_) {
        return raw;
      }
      return raw;
    }
    return raw.toString();
  }

  String _mapApiError(ApiError error) {
    return switch (error.reason) {
      FailReason.badCredential => '统一身份账号或密码不正确',
      FailReason.errorRoaming => '学堂会话建立失败，请稍后重试',
      FailReason.invalidResponse || FailReason.errorFetchFromId =>
        '统一身份认证验证失败，请稍后重试',
      _ => '验证失败，请稍后重试',
    };
  }

  String _buildInjectionScript({required bool shouldAutoSubmit}) {
    final username = jsonEncode(widget.input.username);
    final password = jsonEncode(widget.input.password);
    final autoSubmit = shouldAutoSubmit ? 'true' : 'false';

    return '''
      (function() {
        const channel = window.$_channelName;
        if (!channel) {
          return false;
        }

        const username = $username;
        const password = $password;
        const shouldAutoSubmit = $autoSubmit;

        const send = function(type, data) {
          channel.postMessage(JSON.stringify({ type: type, data: data }));
        };

        const populate = function() {
          const usernameInput = document.querySelector('#i_user');
          const passwordInput = document.querySelector('#i_pass');
          if (usernameInput) {
            usernameInput.value = username;
            usernameInput.dispatchEvent(new Event('input', { bubbles: true }));
            usernameInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
          if (passwordInput) {
            passwordInput.value = password;
            passwordInput.dispatchEvent(new Event('input', { bubbles: true }));
            passwordInput.dispatchEvent(new Event('change', { bubbles: true }));
          }
        };

        const capture = function(form) {
          if (!form) {
            return;
          }
          const payload = {};
          const formData = new FormData(form);
          for (const entry of formData.entries()) {
            payload[entry[0]] = entry[1];
          }
          send('loginForm', payload);
        };

        const hookNativeForm = function() {
          const form = document.getElementById('theform');
          if (!form || form.__learnyCaptured) {
            return;
          }
          form.__learnyCaptured = true;
          form.addEventListener('submit', function() {
            capture(form);
          }, true);
          const originalSubmit = form.submit;
          form.submit = function() {
            capture(form);
            return originalSubmit.apply(form, arguments);
          };
        };

        const hookJQuery = function() {
          if (!window.jQuery || !window.jQuery.fn || !window.jQuery.fn.submit) {
            return;
          }
          if (window.jQuery.fn.submit.__learnyCaptured) {
            return;
          }
          const originalSubmit = window.jQuery.fn.submit;
          window.jQuery.fn.submit = function() {
            const form = this && this[0];
            capture(form);
            return originalSubmit.apply(this, arguments);
          };
          window.jQuery.fn.submit.__learnyCaptured = true;
        };

        populate();
        hookNativeForm();
        hookJQuery();

        if (!window.__learnyCaptureObserver) {
          window.__learnyCaptureObserver = new MutationObserver(function() {
            populate();
            hookNativeForm();
            hookJQuery();
          });
          window.__learnyCaptureObserver.observe(document.documentElement, {
            childList: true,
            subtree: true,
          });
        }

        if (shouldAutoSubmit && !window.__learnyAutoSubmitTriggered) {
          const captcha = document.getElementById('c_code');
          const captchaVisible = captcha && !captcha.classList.contains('hidden');
          if (!captchaVisible) {
            window.__learnyAutoSubmitTriggered = true;
            setTimeout(function() {
              if (typeof doLogin === 'function') {
                doLogin();
                return;
              }
              const loginButton = document.querySelector(
                'a.btn.btn-lg.btn-primary.btn-block'
              );
              if (loginButton) {
                loginButton.click();
              }
            }, 250);
          }
        }

        return true;
      })();
    ''';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('验证统一身份'),
            Text(
              _isProcessingTicket ? '正在保存安全凭据...' : '如出现验证码，请在页面中完成',
              style: AppTypography.bodySmall.copyWith(
                color: _isProcessingTicket ? AppColors.primary : c.subtitle,
              ),
            ),
          ],
        ),
        bottom: _isPageLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                ),
              )
            : null,
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.error.withAlpha(48)),
              ),
              child: Text(
                _errorMessage!,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.error,
                ),
              ),
            ),
          Expanded(
            child: _isProcessingTicket
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 16),
                        Text(
                          '正在建立学堂会话并保存安全凭据...',
                          style: AppTypography.bodyMedium.copyWith(
                            color: c.subtitle,
                          ),
                        ),
                      ],
                    ),
                  )
                : WebViewWidget(controller: _webViewController),
          ),
        ],
      ),
    );
  }
}
