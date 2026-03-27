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
  const AutoReloginEnrollmentScreen({super.key, required this.input});

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
  String? _capturedTrustedFingerGenPrint;
  bool _capturedSingleLoginEnabled = false;
  Completer<void>? _trustedBrowserCaptureCompleter;
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
    if (ref.read(ssoTicketParserProvider).shouldAttemptFallback(url)) {
      await _fallbackCookieExtraction();
      return;
    }

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
      final data = raw['data'];
      if (data is! Map) {
        return;
      }
      final payload = data.map<String, String>(
        (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
      );
      switch (raw['type']) {
        case 'loginForm':
          _capturedFormData = payload;
          return;
        case 'trustedBrowser':
          final trustedFingerGenPrint =
              (payload['fingerGenPrint'] ?? payload['object'] ?? '').trim();
          if (trustedFingerGenPrint.isNotEmpty) {
            _capturedTrustedFingerGenPrint = trustedFingerGenPrint;
          }
          _capturedSingleLoginEnabled =
              _capturedSingleLoginEnabled ||
              _looksTruthy(payload['singleLogin']) ||
              _looksTruthy(payload['radioVal']);

          final nextFormData = Map<String, String>.from(
            _capturedFormData ?? payload,
          );
          if (trustedFingerGenPrint.isNotEmpty) {
            nextFormData['fingerGenPrint'] = trustedFingerGenPrint;
          }
          if ((payload['deviceName'] ?? '').trim().isNotEmpty) {
            nextFormData['deviceName'] = payload['deviceName']!.trim();
          }
          if (_capturedSingleLoginEnabled) {
            nextFormData['singleLogin'] = 'on';
          }
          _capturedFormData = nextFormData;
          debugPrint(
            '[LearnY] Trusted-browser enrollment captured '
            '(token=${trustedFingerGenPrint.isNotEmpty}, '
            'singleLogin=$_capturedSingleLoginEnabled)',
          );
          final completer = _trustedBrowserCaptureCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
          return;
        default:
          return;
      }
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
      await ref.read(ssoLoginCoordinatorProvider).consumeTicket(ticket);
      await _persistEnrolledCredential(capturedFormData);
    } on _EnrollmentTrustMissingException {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '自动重新登录授权未完成，请在二次认证后信任当前设备';
        _isProcessingTicket = false;
        _isPageLoading = false;
      });
    } on _EnrollmentVerificationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapVerificationApiError(error.error);
        _isProcessingTicket = false;
        _isPageLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapBootstrapApiError(error);
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

  Future<void> _fallbackCookieExtraction() async {
    if (_isProcessingTicket) {
      return;
    }

    setState(() {
      _isProcessingTicket = true;
      _isPageLoading = true;
      _errorMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      await _webViewController.loadRequest(
        Uri.parse(urls.learnStudentCourseListPage()),
      );
      await Future<void>.delayed(const Duration(seconds: 3));

      final rawHtml = await _webViewController.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final pageSnapshot = ref
          .read(ssoFallbackPageParserProvider)
          .parse(rawHtml.toString());

      final cookieRaw = await _webViewController.runJavaScriptReturningResult(
        'document.cookie',
      );
      var cookieString = cookieRaw.toString();
      if (cookieString.startsWith('"') && cookieString.endsWith('"')) {
        cookieString = cookieString.substring(1, cookieString.length - 1);
      }

      final capturedFormData = _capturedFormData;
      if (capturedFormData == null) {
        throw const ApiError(reason: FailReason.invalidResponse);
      }

      await ref
          .read(ssoLoginCoordinatorProvider)
          .completeFallbackLogin(
            pageSnapshot: pageSnapshot,
            cookieString: cookieString,
          );
      await _persistEnrolledCredential(capturedFormData);
    } on _EnrollmentTrustMissingException {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '自动重新登录授权未完成，请在二次认证后信任当前设备';
        _isProcessingTicket = false;
        _isPageLoading = false;
      });
    } on _EnrollmentVerificationException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapVerificationApiError(error.error);
        _isProcessingTicket = false;
        _isPageLoading = false;
      });
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapBootstrapApiError(error);
        _isProcessingTicket = false;
        _isPageLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Auto relogin enrollment fallback failed: $error');
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

  Future<void> _persistEnrolledCredential(
    Map<String, String> capturedFormData,
  ) async {
    final resolvedUsername = widget.input.username.trim();
    final resolvedFields = await _resolveEnrollmentFields(capturedFormData);

    if (resolvedUsername.isEmpty || resolvedFields.fingerPrint.isEmpty) {
      throw const ApiError(reason: FailReason.invalidResponse);
    }

    try {
      await ref
          .read(authReloginServiceProvider)
          .saveEnrolledCredential(
            username: resolvedUsername,
            password: widget.input.password,
            fingerPrint: resolvedFields.fingerPrint,
            fingerGenPrint: resolvedFields.fingerGenPrint,
            fingerGenPrint3: resolvedFields.fingerGenPrint3,
            deviceName: resolvedFields.deviceName,
            singleLoginEnabled: resolvedFields.singleLoginEnabled,
          );
    } on ApiError catch (error) {
      throw _EnrollmentVerificationException(error);
    }

    await ref.read(autoReloginEnabledProvider.notifier).setEnabled(true);
    ref.invalidate(storedCredentialAvailabilityProvider);

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(true);
  }

  Future<_ResolvedEnrollmentFields> _resolveEnrollmentFields(
    Map<String, String> capturedFormData,
  ) async {
    final resolved = Map<String, String>.from(capturedFormData);
    await _awaitTrustedBrowserCaptureIfNeeded(
      hasReusableFingerToken: (resolved['fingerGenPrint'] ?? '')
          .trim()
          .isNotEmpty,
    );

    final trustedFingerGenPrint = (_capturedTrustedFingerGenPrint ?? '').trim();
    if ((resolved['fingerGenPrint'] ?? '').trim().isEmpty &&
        trustedFingerGenPrint.isNotEmpty) {
      resolved['fingerGenPrint'] = trustedFingerGenPrint;
    }

    final singleLoginEnabled =
        _capturedSingleLoginEnabled || _looksTruthy(resolved['singleLogin']);
    if (singleLoginEnabled) {
      resolved['singleLogin'] = 'on';
    }

    final result = _ResolvedEnrollmentFields(
      fingerPrint: (resolved['fingerPrint'] ?? '').trim(),
      fingerGenPrint: (resolved['fingerGenPrint'] ?? '').trim(),
      fingerGenPrint3: (resolved['fingerGenPrint3'] ?? '').trim(),
      deviceName: (resolved['deviceName'] ?? '').trim(),
      singleLoginEnabled: singleLoginEnabled,
    );

    if (!result.hasReusableTrustedBrowserState) {
      throw const _EnrollmentTrustMissingException();
    }

    return result;
  }

  Future<void> _awaitTrustedBrowserCaptureIfNeeded({
    required bool hasReusableFingerToken,
  }) async {
    if (hasReusableFingerToken ||
        (_capturedTrustedFingerGenPrint ?? '').trim().isNotEmpty) {
      return;
    }

    final completer = _trustedBrowserCaptureCompleter ??= Completer<void>();
    try {
      await completer.future.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      debugPrint(
        '[LearnY] Trusted-browser capture did not arrive before timeout',
      );
    } finally {
      if (identical(_trustedBrowserCaptureCompleter, completer)) {
        _trustedBrowserCaptureCompleter = null;
      }
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
        const singleLogin = document.querySelector('[name="singleLogin"]');
        if (singleLogin && 'checked' in singleLogin) {
          data.singleLogin = singleLogin.checked ? (singleLogin.value || 'on') : '';
        }
        return JSON.stringify(data);
      })();
    ''');
    return _decodeStringMapResult(raw);
  }

  Map<String, String> _decodeStringMapResult(Object raw) {
    final decoded =
        jsonDecode(_decodeStringResult(raw)) as Map<String, dynamic>;
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

  String _mapBootstrapApiError(ApiError error) {
    return switch (error.reason) {
      FailReason.badCredential => '统一身份账号或密码不正确',
      FailReason.errorRoaming => '学堂会话建立失败，请稍后重试',
      FailReason.invalidResponse ||
      FailReason.errorFetchFromId => '统一身份认证验证失败，请稍后重试',
      _ => '验证失败，请稍后重试',
    };
  }

  String _mapVerificationApiError(ApiError error) {
    return switch (error.reason) {
      FailReason.badCredential => '自动重新登录验证失败：统一身份账号或密码不正确',
      FailReason.errorRoaming => '自动重新登录验证失败：学堂会话建立失败，请稍后重试',
      FailReason.invalidResponse ||
      FailReason.errorFetchFromId => '自动重新登录验证失败：统一身份认证验证失败，请稍后重试',
      _ => '自动重新登录验证失败，请稍后重试',
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
        const state = window.__learnyEnrollmentState || (window.__learnyEnrollmentState = {
          loginForm: null,
          trustedFingerGenPrint: '',
          deviceName: '',
          singleLoginEnabled: true,
        });

        const send = function(type, data) {
          channel.postMessage(JSON.stringify({ type: type, data: data }));
        };

        const looksLikeSaveFingerUrl = function(url) {
          return typeof url === 'string' && url.indexOf('/b/doubleAuth/personal/saveFinger') !== -1;
        };

        const readSavedFormField = function(name, fallbackSelector) {
          const saved = state.loginForm && state.loginForm[name];
          if (saved) {
            return String(saved).trim();
          }
          if (!fallbackSelector) {
            return '';
          }
          const element = document.querySelector(fallbackSelector);
          if (!element || !('value' in element)) {
            return '';
          }
          return String(element.value || '').trim();
        };

        const patchSaveFingerBody = function(body) {
          if (typeof body !== 'string') {
            return body;
          }
          const params = new URLSearchParams(body);
          const fingerPrint = readSavedFormField('fingerPrint', '#fingerPrint');
          const deviceName = readSavedFormField('deviceName', '#deviceName');
          if (fingerPrint) {
            params.set('fingerprint', fingerPrint);
          }
          if (deviceName) {
            params.set('deviceName', deviceName);
            state.deviceName = deviceName;
          }
          params.set('radioVal', '是');
          params.set('singleLogin', 'yes');
          return params.toString();
        };

        const reportTrustedBrowser = function(responseText, requestBody) {
          try {
            const parsed = JSON.parse(responseText || '{}');
            const trustedFingerGenPrint = parsed && parsed.object ? String(parsed.object) : '';
            if (!trustedFingerGenPrint) {
              return;
            }
            state.trustedFingerGenPrint = trustedFingerGenPrint;
            const params = new URLSearchParams(typeof requestBody === 'string' ? requestBody : '');
            send('trustedBrowser', {
              fingerGenPrint: trustedFingerGenPrint,
              deviceName: params.get('deviceName') || state.deviceName || '',
              singleLogin: params.get('singleLogin') || 'yes',
              radioVal: params.get('radioVal') || '是',
            });
          } catch (_) {}
        };

        const populate = function() {
          const usernameInput = document.querySelector('#i_user');
          const passwordInput = document.querySelector('#i_pass');
          const singleLoginInput = document.querySelector('[name="singleLogin"]');
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
          if (singleLoginInput && !singleLoginInput.checked) {
            singleLoginInput.click();
          }
          if (singleLoginInput && !singleLoginInput.checked) {
            singleLoginInput.checked = true;
            singleLoginInput.dispatchEvent(new Event('input', { bubbles: true }));
            singleLoginInput.dispatchEvent(new Event('change', { bubbles: true }));
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
          payload.singleLogin = payload.singleLogin || 'on';
          state.loginForm = payload;
          if (payload.deviceName) {
            state.deviceName = String(payload.deviceName);
          }
          send('loginForm', payload);
        };

        const hookXhr = function() {
          if (!window.XMLHttpRequest || window.XMLHttpRequest.__learnyTrustPatched) {
            return;
          }
          const originalOpen = window.XMLHttpRequest.prototype.open;
          const originalSend = window.XMLHttpRequest.prototype.send;
          window.XMLHttpRequest.prototype.open = function(method, url) {
            this.__learnyUrl = url;
            return originalOpen.apply(this, arguments);
          };
          window.XMLHttpRequest.prototype.send = function(body) {
            let nextBody = body;
            if (looksLikeSaveFingerUrl(this.__learnyUrl)) {
              nextBody = patchSaveFingerBody(body);
              this.__learnySaveFingerBody = nextBody;
              this.addEventListener('load', function() {
                reportTrustedBrowser(this.responseText, this.__learnySaveFingerBody);
              });
            }
            return originalSend.call(this, nextBody);
          };
          window.XMLHttpRequest.__learnyTrustPatched = true;
        };

        const hookFetch = function() {
          if (!window.fetch || window.fetch.__learnyTrustPatched) {
            return;
          }
          const originalFetch = window.fetch;
          window.fetch = function(resource, init) {
            const url = typeof resource === 'string'
              ? resource
              : (resource && resource.url) || '';
            if (!looksLikeSaveFingerUrl(url)) {
              return originalFetch.apply(this, arguments);
            }
            const nextInit = Object.assign({}, init || {});
            nextInit.body = patchSaveFingerBody(nextInit.body || '');
            return originalFetch.call(this, resource, nextInit).then(function(response) {
              try {
                response.clone().text().then(function(text) {
                  reportTrustedBrowser(text, nextInit.body);
                }).catch(function() {});
              } catch (_) {}
              return response;
            });
          };
          window.fetch.__learnyTrustPatched = true;
        };

        const autoConfirmTrustedBrowser = function() {
          const yesRadio = document.querySelector('input[name="type"][value="是"]');
          if (yesRadio && !yesRadio.checked) {
            yesRadio.click();
            yesRadio.dispatchEvent(new Event('change', { bubbles: true }));
          }
          if (!yesRadio || !yesRadio.checked) {
            return;
          }
          const buttons = Array.from(document.querySelectorAll('button, input[type="button"], input[type="submit"]'));
          const confirmButton = buttons.find(function(button) {
            const text = String(button.innerText || button.value || '').trim();
            return text === '确定';
          });
          if (confirmButton && !confirmButton.__learnyAutoClicked) {
            confirmButton.__learnyAutoClicked = true;
            setTimeout(function() {
              confirmButton.click();
            }, 120);
          }
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
        hookXhr();
        hookFetch();
        autoConfirmTrustedBrowser();

        if (!window.__learnyCaptureObserver) {
          window.__learnyCaptureObserver = new MutationObserver(function() {
            populate();
            hookNativeForm();
            hookJQuery();
            hookXhr();
            hookFetch();
            autoConfirmTrustedBrowser();
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
                style: AppTypography.bodySmall.copyWith(color: AppColors.error),
              ),
            ),
          Expanded(
            child: _isProcessingTicket
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
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

class _EnrollmentVerificationException implements Exception {
  const _EnrollmentVerificationException(this.error);

  final ApiError error;
}

class _EnrollmentTrustMissingException implements Exception {
  const _EnrollmentTrustMissingException();
}

class _ResolvedEnrollmentFields {
  const _ResolvedEnrollmentFields({
    required this.fingerPrint,
    required this.fingerGenPrint,
    required this.fingerGenPrint3,
    required this.deviceName,
    required this.singleLoginEnabled,
  });

  final String fingerPrint;
  final String fingerGenPrint;
  final String fingerGenPrint3;
  final String deviceName;
  final bool singleLoginEnabled;

  bool get hasReusableTrustedBrowserState => fingerGenPrint.isNotEmpty;
}

bool _looksTruthy(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'on' ||
      normalized == 'yes' ||
      normalized == 'true' ||
      normalized == '是';
}
