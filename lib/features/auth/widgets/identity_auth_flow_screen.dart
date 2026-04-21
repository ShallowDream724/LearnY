import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/enums.dart';
import '../../../core/api/models.dart';
import '../../../core/api/urls.dart' as urls;
import '../../../core/auth/auth.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import 'identity_auth_web_surface.dart';

class IdentityAuthFlowScreen extends ConsumerStatefulWidget {
  const IdentityAuthFlowScreen({super.key, required this.request});

  final AuthEntryRequest request;

  @override
  ConsumerState<IdentityAuthFlowScreen> createState() =>
      _IdentityAuthFlowScreenState();
}

class _IdentityAuthFlowScreenState
    extends ConsumerState<IdentityAuthFlowScreen> {
  late final IdentityAuthWebSurfaceController _webSurfaceController;

  Map<String, String>? _capturedFormData;
  String? _capturedTrustedFingerGenPrint;
  bool _capturedSingleLoginEnabled = false;
  bool _didRequestTrustedBrowserEnrollment = false;
  bool _isTrustedBrowserRefreshPass = false;
  int _trustedBrowserRefreshAttempt = 0;
  String? _bootstrappedUsername;
  Completer<void>? _trustedBrowserCaptureCompleter;
  bool _isPageLoading = true;
  bool _isProcessing = false;
  bool _didAttemptAutoSubmit = false;
  bool _isWebSurfaceReady = false;
  String? _errorMessage;
  IdentityAuthWebAvailability? _webAvailability;

  @override
  void initState() {
    super.initState();
    _webSurfaceController = createIdentityAuthWebSurfaceController(
      IdentityAuthWebCallbacks(
        onPageStarted: _onPageStarted,
        onPageFinished: _onPageFinished,
        onNavigationRequest: _onNavigationRequest,
        onJavaScriptMessage: _handleJavaScriptMessage,
      ),
    );
    unawaited(_initializeWebSurface());
  }

  @override
  void dispose() {
    unawaited(_webSurfaceController.dispose());
    super.dispose();
  }

  Future<void> _initializeWebSurface() async {
    final availability = await _webSurfaceController.initialize();
    if (!mounted) {
      return;
    }

    if (!availability.isAvailable) {
      setState(() {
        _webAvailability = availability;
        _isWebSurfaceReady = false;
        _isPageLoading = false;
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _webAvailability = availability;
      _isWebSurfaceReady = true;
    });
    await _prepareLoginPage();
  }

  Future<void> _prepareLoginPage({
    bool isTrustedBrowserRefreshPass = false,
  }) async {
    if (!_isWebSurfaceReady) {
      return;
    }
    _capturedFormData = null;
    _capturedTrustedFingerGenPrint = null;
    _capturedSingleLoginEnabled = false;
    _didRequestTrustedBrowserEnrollment = false;
    _isTrustedBrowserRefreshPass = isTrustedBrowserRefreshPass;
    _trustedBrowserCaptureCompleter = null;
    _didAttemptAutoSubmit = false;
    if (!isTrustedBrowserRefreshPass) {
      _trustedBrowserRefreshAttempt = 0;
      _bootstrappedUsername = null;
    }

    if (widget.request.resetBrowserContext) {
      await _webSurfaceController.clearBrowsingData();
    }

    await _webSurfaceController.loadUrl(urls.idLogin());
  }

  void _onPageStarted(String _) {
    if (!mounted || _isProcessing) {
      return;
    }
    setState(() {
      _isPageLoading = true;
      _errorMessage = null;
    });
  }

  Future<void> _onPageFinished(String url) async {
    if (!mounted || _isProcessing) {
      return;
    }

    setState(() {
      _isPageLoading = false;
    });

    if (ref.read(ssoTicketParserProvider).shouldAttemptFallback(url)) {
      await _fallbackCookieExtraction();
      return;
    }

    if (!widget.request.shouldInjectCredential) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri?.host != Uri.parse(urls.idPrefix).host) {
      return;
    }

    final shouldAutoSubmit = !_didAttemptAutoSubmit;
    if (shouldAutoSubmit) {
      _didAttemptAutoSubmit = true;
    }

    try {
      await _webSurfaceController.runJavaScript(
        _buildInjectionScript(shouldAutoSubmit: shouldAutoSubmit),
      );
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Identity auth inject failed: $error');
      debugPrint('$stackTrace');
    }
  }

  bool _onNavigationRequest(String url) {
    final instruction = ref
        .read(ssoTicketParserProvider)
        .inspectNavigation(url);
    if (instruction.shouldConsumeTicket && instruction.ticket != null) {
      unawaited(_handleTicket(instruction.ticket!));
      return true;
    }
    return false;
  }

  void _handleJavaScriptMessage(Object message) {
    try {
      final raw = switch (message) {
        final String value => jsonDecode(value) as Map<String, dynamic>,
        final Map<dynamic, dynamic> value => value.map<String, dynamic>(
          (key, value) => MapEntry(key.toString(), value),
        ),
        _ => throw const FormatException(
          'Unexpected JavaScript bridge payload',
        ),
      };
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
        case 'trustedBrowserRequested':
          _didRequestTrustedBrowserEnrollment = true;
          _capturedSingleLoginEnabled =
              _capturedSingleLoginEnabled ||
              _looksTruthy(payload['singleLogin']) ||
              _looksTruthy(payload['radioVal']);
          final requestedFormData = Map<String, String>.from(
            _capturedFormData ?? payload,
          );
          if ((payload['deviceName'] ?? '').trim().isNotEmpty) {
            requestedFormData['deviceName'] = payload['deviceName']!.trim();
          }
          if (_capturedSingleLoginEnabled) {
            requestedFormData['singleLogin'] = 'on';
          }
          _capturedFormData = requestedFormData;
          return;
        case 'trustedBrowser':
          _didRequestTrustedBrowserEnrollment = true;
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
            nextFormData['fingerGenPrint3'] = trustedFingerGenPrint;
          }
          if ((payload['deviceName'] ?? '').trim().isNotEmpty) {
            nextFormData['deviceName'] = payload['deviceName']!.trim();
          }
          if (_capturedSingleLoginEnabled) {
            nextFormData['singleLogin'] = 'on';
          }
          _capturedFormData = nextFormData;

          final completer = _trustedBrowserCaptureCompleter;
          if (completer != null && !completer.isCompleted) {
            completer.complete();
          }
          return;
        default:
          return;
      }
    } catch (error) {
      debugPrint('[LearnY] Failed to decode identity auth payload: $error');
    }
  }

  Future<void> _handleTicket(String ticket) async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _isPageLoading = true;
      _errorMessage = null;
    });

    try {
      final enrollmentPayload = await _resolveEnrollmentPayloadIfNeeded();
      if (_isTrustedBrowserRefreshPass) {
        final username = _bootstrappedUsername;
        if (username == null || username.isEmpty) {
          throw StateError('trusted browser refresh missing bootstrap user');
        }
        final result = await ref
            .read(authEntryCoordinatorProvider)
            .configureAutoReloginForExistingSession(
              username: username,
              enrollmentPayload: enrollmentPayload,
            );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(result);
        return;
      }

      final shouldRefreshTrustedBrowserState =
          _shouldRefreshTrustedBrowserState(enrollmentPayload);
      final result = await ref
          .read(authEntryCoordinatorProvider)
          .consumeTicket(
            request: shouldRefreshTrustedBrowserState
                ? const AuthEntryRequest.loginOnly()
                : widget.request,
            ticket: ticket,
            enrollmentPayload: shouldRefreshTrustedBrowserState
                ? null
                : enrollmentPayload,
          );
      if (!mounted) {
        return;
      }
      if (shouldRefreshTrustedBrowserState) {
        await _startTrustedBrowserRefresh(result.username);
        return;
      }
      Navigator.of(context).pop(result);
    } on ApiError catch (error) {
      if (await _handleRefreshPassApiError(error)) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapBootstrapApiError(error);
        _isProcessing = false;
        _isPageLoading = false;
      });
    } catch (error, stackTrace) {
      if (await _handleRefreshPassError()) {
        return;
      }
      debugPrint('[LearnY] Identity ticket flow failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '认证失败，请稍后重试';
        _isProcessing = false;
        _isPageLoading = false;
      });
    }
  }

  Future<void> _fallbackCookieExtraction() async {
    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _isPageLoading = true;
      _errorMessage = null;
    });

    try {
      await Future<void>.delayed(const Duration(seconds: 2));
      await _webSurfaceController.loadUrl(urls.learnStudentCourseListPage());
      await Future<void>.delayed(const Duration(seconds: 3));

      final rawHtml = await _webSurfaceController.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      final pageSnapshot = ref
          .read(ssoFallbackPageParserProvider)
          .parse(_decodeStringResult(rawHtml));

      final cookieString =
          (await _webSurfaceController.getCurrentCookieHeader()) ??
          _decodeStringResult(
            await _webSurfaceController.runJavaScriptReturningResult(
              'document.cookie',
            ),
          );

      final enrollmentPayload = await _resolveEnrollmentPayloadIfNeeded();
      if (_isTrustedBrowserRefreshPass) {
        final username = _bootstrappedUsername;
        if (username == null || username.isEmpty) {
          throw StateError('trusted browser refresh missing bootstrap user');
        }
        final result = await ref
            .read(authEntryCoordinatorProvider)
            .configureAutoReloginForExistingSession(
              username: username,
              enrollmentPayload: enrollmentPayload,
            );
        if (!mounted) {
          return;
        }
        Navigator.of(context).pop(result);
        return;
      }

      final shouldRefreshTrustedBrowserState =
          _shouldRefreshTrustedBrowserState(enrollmentPayload);
      final result = await ref
          .read(authEntryCoordinatorProvider)
          .completeFallback(
            request: shouldRefreshTrustedBrowserState
                ? const AuthEntryRequest.loginOnly()
                : widget.request,
            pageSnapshot: pageSnapshot,
            cookieString: cookieString,
            enrollmentPayload: shouldRefreshTrustedBrowserState
                ? null
                : enrollmentPayload,
          );
      if (!mounted) {
        return;
      }
      if (shouldRefreshTrustedBrowserState) {
        await _startTrustedBrowserRefresh(result.username);
        return;
      }
      Navigator.of(context).pop(result);
    } on ApiError catch (error) {
      if (await _handleRefreshPassApiError(error)) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = _mapBootstrapApiError(error);
        _isProcessing = false;
        _isPageLoading = false;
      });
    } catch (error, stackTrace) {
      if (await _handleRefreshPassError()) {
        return;
      }
      debugPrint('[LearnY] Identity fallback flow failed: $error');
      debugPrint('$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '认证失败，请稍后重试';
        _isProcessing = false;
        _isPageLoading = false;
      });
    }
  }

  Future<AutoReloginEnrollmentPayload?>
  _resolveEnrollmentPayloadIfNeeded() async {
    if (!widget.request.requiresAutoRelogin) {
      return null;
    }

    final capturedFormData =
        _capturedFormData ?? await _readCurrentFormDataFromPage();
    return _resolveEnrollmentPayload(capturedFormData);
  }

  Future<AutoReloginEnrollmentPayload> _resolveEnrollmentPayload(
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
    if ((resolved['fingerGenPrint3'] ?? '').trim().isEmpty &&
        (resolved['fingerGenPrint'] ?? '').trim().isNotEmpty) {
      resolved['fingerGenPrint3'] = resolved['fingerGenPrint']!.trim();
    }

    final singleLoginEnabled =
        _capturedSingleLoginEnabled || _looksTruthy(resolved['singleLogin']);
    if (singleLoginEnabled) {
      resolved['singleLogin'] = 'on';
    }

    final input = widget.request.input!;
    final submittedUsername = (resolved['i_user'] ?? '').trim();
    final submittedPassword = resolved['i_pass'] ?? '';
    return AutoReloginEnrollmentPayload(
      username: submittedUsername.isEmpty
          ? input.username.trim()
          : submittedUsername,
      password: resolveEnrollmentPassword(
        submittedPassword: submittedPassword,
        fallbackPassword: input.password,
      ),
      fingerPrint: (resolved['fingerPrint'] ?? '').trim(),
      fingerGenPrint: (resolved['fingerGenPrint'] ?? '').trim(),
      fingerGenPrint3: (resolved['fingerGenPrint3'] ?? '').trim(),
      deviceName: (resolved['deviceName'] ?? '').trim(),
      singleLoginEnabled: singleLoginEnabled,
    );
  }

  bool _shouldRefreshTrustedBrowserState(
    AutoReloginEnrollmentPayload? enrollmentPayload,
  ) {
    if (_isTrustedBrowserRefreshPass || !widget.request.requiresAutoRelogin) {
      return false;
    }
    if (!_didRequestTrustedBrowserEnrollment) {
      return false;
    }
    return enrollmentPayload == null ||
        !enrollmentPayload.hasReusableTrustedBrowserState;
  }

  Future<void> _startTrustedBrowserRefresh(String username) async {
    _bootstrappedUsername = username;
    _trustedBrowserRefreshAttempt++;
    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = false;
      _isPageLoading = true;
      _errorMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) {
      return;
    }
    await _prepareLoginPage(isTrustedBrowserRefreshPass: true);
  }

  Future<bool> _handleRefreshPassApiError(ApiError error) async {
    if (!_isTrustedBrowserRefreshPass) {
      return false;
    }
    if (await _retryTrustedBrowserRefreshIfNeeded(error)) {
      return true;
    }
    return _completeRefreshPassWithNoticeIfPossible();
  }

  Future<bool> _handleRefreshPassError() async {
    if (!_isTrustedBrowserRefreshPass) {
      return false;
    }
    return _completeRefreshPassWithNoticeIfPossible();
  }

  Future<bool> _retryTrustedBrowserRefreshIfNeeded(ApiError error) async {
    if (!_canRetryTrustedBrowserRefresh(error)) {
      return false;
    }
    if (_trustedBrowserRefreshAttempt >= 3) {
      return false;
    }
    final username = _bootstrappedUsername;
    if (username == null || username.isEmpty) {
      return false;
    }
    final delaySeconds = _trustedBrowserRefreshAttempt;
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _isPageLoading = true;
        _errorMessage = null;
      });
    }
    await Future<void>.delayed(Duration(seconds: delaySeconds));
    if (!mounted) {
      return true;
    }
    await _startTrustedBrowserRefresh(username);
    return true;
  }

  bool _canRetryTrustedBrowserRefresh(ApiError error) {
    return switch (error.reason) {
      FailReason.badCredential ||
      FailReason.errorFetchFromId ||
      FailReason.invalidResponse => true,
      _ => false,
    };
  }

  bool _completeRefreshPassWithNoticeIfPossible() {
    if (widget.request.mode != AuthEntryMode.loginAndEnableAutoRelogin) {
      return false;
    }
    final username = _bootstrappedUsername;
    if (username == null || username.isEmpty || !mounted) {
      return false;
    }
    Navigator.of(context).pop(
      AuthEntryResult(
        username: username,
        autoReloginConfigured: false,
        noticeMessage: '已完成登录，但自动重新登录授权尚未生效，请稍后在“我的”页重试',
      ),
    );
    return true;
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
      await completer.future.timeout(const Duration(seconds: 5));
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
    final raw = await _webSurfaceController.runJavaScriptReturningResult('''
      (function() {
        const data = {};
        const ids = ['i_user', 'i_pass', 'fingerPrint', 'fingerGenPrint', 'fingerGenPrint3', 'deviceName'];
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

  Map<String, String> _decodeStringMapResult(Object? raw) {
    final decoded =
        jsonDecode(_decodeStringResult(raw)) as Map<String, dynamic>;
    return decoded.map<String, String>(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  String _decodeStringResult(Object? raw) {
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
    if (_isTrustedBrowserRefreshPass) {
      return '自动重新登录授权尚未生效，请稍后重试';
    }
    return switch (error.reason) {
      FailReason.badCredential => '统一身份账号或密码不正确',
      FailReason.errorRoaming => '学堂会话建立失败，请稍后重试',
      FailReason.invalidResponse ||
      FailReason.errorFetchFromId => '统一身份认证验证失败，请稍后重试',
      _ => '认证失败，请稍后重试',
    };
  }

  String _buildInjectionScript({required bool shouldAutoSubmit}) {
    final input = widget.request.input!;
    final username = jsonEncode(input.username);
    final password = jsonEncode(input.password);
    final autoSubmit = shouldAutoSubmit ? 'true' : 'false';

    return '''
      (function() {
        const hasBridge =
          (
            window.LearnYIdentityAuth &&
            typeof window.LearnYIdentityAuth.postMessage === 'function'
          ) ||
          (
            window.chrome &&
            window.chrome.webview &&
            typeof window.chrome.webview.postMessage === 'function'
          );

        const postMessage = function(message) {
          if (
            window.LearnYIdentityAuth &&
            typeof window.LearnYIdentityAuth.postMessage === 'function'
          ) {
            window.LearnYIdentityAuth.postMessage(message);
            return true;
          }
          if (
            window.chrome &&
            window.chrome.webview &&
            typeof window.chrome.webview.postMessage === 'function'
          ) {
            window.chrome.webview.postMessage(message);
            return true;
          }
          return false;
        };

        if (!hasBridge) {
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
          return postMessage(JSON.stringify({ type: type, data: data }));
        };

        const reportTrustedBrowserRequested = function() {
          if (window.__learnyTrustedBrowserRequested) {
            return;
          }
          window.__learnyTrustedBrowserRequested = true;
          send('trustedBrowserRequested', {
            deviceName: readSavedFormField('deviceName', '#deviceName'),
            singleLogin: 'yes',
            radioVal: '是',
          });
        };

        const dispatchValueChange = function(element) {
          if (!element) {
            return;
          }
          try {
            element.dispatchEvent(new Event('input', { bubbles: true }));
            element.dispatchEvent(new Event('change', { bubbles: true }));
          } catch (_) {}
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
            dispatchValueChange(passwordInput);
          }
          ensureSingleLoginSelection(singleLoginInput && singleLoginInput.form);
        };

        const ensureSingleLoginSelection = function(form) {
          const singleLoginInput = document.querySelector('[name="singleLogin"]');
          if (!singleLoginInput) {
            return true;
          }

          const resolvedForm = form || singleLoginInput.form || document.getElementById('theform');
          const syncHiddenField = function(forcePresent) {
            if (!resolvedForm) {
              return false;
            }
            let hiddenField = resolvedForm.querySelector('input[data-learny-force-single-login="1"]');
            const hasFormValue = new FormData(resolvedForm).has('singleLogin');
            if (forcePresent && !hasFormValue) {
              if (!hiddenField) {
                hiddenField = document.createElement('input');
                hiddenField.type = 'hidden';
                hiddenField.name = 'singleLogin';
                hiddenField.value = 'on';
                hiddenField.setAttribute('data-learny-force-single-login', '1');
                resolvedForm.appendChild(hiddenField);
              } else {
                hiddenField.value = 'on';
              }
              return true;
            }
            if (!forcePresent && hiddenField) {
              hiddenField.remove();
            }
            return hasFormValue;
          };

          if (!singleLoginInput.checked) {
            try {
              singleLoginInput.click();
            } catch (_) {}
          }
          if (!singleLoginInput.checked) {
            try {
              singleLoginInput.checked = true;
            } catch (_) {}
            dispatchValueChange(singleLoginInput);
          }

          const hasFormValueAfterToggle = syncHiddenField(!singleLoginInput.checked);
          return singleLoginInput.checked || hasFormValueAfterToggle;
        };

        const capture = function(form) {
          if (!form) {
            return;
          }
          ensureSingleLoginSelection(form);
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
          reportTrustedBrowserRequested();
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

        const tryAutoSubmit = function() {
          if (!shouldAutoSubmit || window.__learnyAutoSubmitTriggered) {
            return;
          }

          const captcha = document.getElementById('c_code');
          const captchaVisible = captcha && !captcha.classList.contains('hidden');
          if (captchaVisible) {
            return;
          }

          const form = document.getElementById('theform');
          if (!ensureSingleLoginSelection(form)) {
            return;
          }

          if (form && document.querySelector('[name="singleLogin"]')) {
            const hasSingleLoginValue = new FormData(form).has('singleLogin');
            if (!hasSingleLoginValue) {
              return;
            }
          }

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
        };

        populate();
        hookNativeForm();
        hookJQuery();
        hookXhr();
        hookFetch();
        autoConfirmTrustedBrowser();
        tryAutoSubmit();

        if (!window.__learnyCaptureObserver) {
          window.__learnyCaptureObserver = new MutationObserver(function() {
            populate();
            hookNativeForm();
            hookJQuery();
            hookXhr();
            hookFetch();
            autoConfirmTrustedBrowser();
            tryAutoSubmit();
          });
          window.__learnyCaptureObserver.observe(document.documentElement, {
            childList: true,
            subtree: true,
          });
        }

        return true;
      })();
    ''';
  }

  Future<void> _openWebView2RuntimeDownload() async {
    final uri = Uri.parse(
      'https://developer.microsoft.com/en-us/microsoft-edge/webview2/',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildWebSurfaceBody(BuildContext context) {
    final c = context.colors;

    if (_isProcessing) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              _processingLabel,
              style: AppTypography.bodyMedium.copyWith(color: c.subtitle),
            ),
          ],
        ),
      );
    }

    if (!_isWebSurfaceReady) {
      final availability = _webAvailability;
      if (availability != null && !availability.isAvailable) {
        final isMissingRuntime =
            availability.status ==
            IdentityAuthWebAvailabilityStatus.missingRuntime;
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMissingRuntime
                      ? Icons.desktop_windows_outlined
                      : Icons.error_outline_rounded,
                  size: 34,
                  color: c.subtitle,
                ),
                const SizedBox(height: 16),
                Text(
                  availability.message ?? '认证视图初始化失败',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: c.subtitle,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                          _isPageLoading = true;
                        });
                        unawaited(_initializeWebSurface());
                      },
                      child: const Text('重新尝试'),
                    ),
                    if (isMissingRuntime)
                      OutlinedButton(
                        onPressed: _openWebView2RuntimeDownload,
                        child: const Text('安装 WebView2'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }

      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    return _webSurfaceController.buildView();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_appBarTitle),
            Text(
              _appBarSubtitle,
              style: AppTypography.bodySmall.copyWith(
                color: _isProcessing ? AppColors.primary : c.subtitle,
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
          Expanded(child: _buildWebSurfaceBody(context)),
        ],
      ),
    );
  }

  String get _appBarTitle {
    return switch (widget.request.mode) {
      AuthEntryMode.loginOnly => '统一身份认证',
      AuthEntryMode.loginAndEnableAutoRelogin => '统一身份认证',
      AuthEntryMode.enableAutoRelogin => '验证统一身份',
    };
  }

  String get _appBarSubtitle {
    if (_isProcessing) {
      return _processingLabel;
    }
    if (_isTrustedBrowserRefreshPass) {
      return '正在刷新信任设备授权，如再次出现验证码请继续完成';
    }
    return widget.request.requiresAutoRelogin
        ? '如出现验证码或信任设备提示，请在页面中完成'
        : '如出现验证码，请在页面中完成';
  }

  String get _processingLabel {
    if (_isTrustedBrowserRefreshPass) {
      return '正在完成自动重新登录校验...';
    }
    if (!widget.request.requiresAutoRelogin) {
      return '正在建立安全会话...';
    }
    return '正在建立会话并校验自动重新登录...';
  }
}

bool _looksTruthy(String? value) {
  final normalized = (value ?? '').trim().toLowerCase();
  return normalized == 'on' ||
      normalized == 'yes' ||
      normalized == 'true' ||
      normalized == '是';
}
