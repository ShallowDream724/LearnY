import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/app_materials.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/guides/guide_presenter.dart';
import '../../core/guides/guide_registry.dart';
import '../../core/providers/app_update_provider.dart';
import '../../core/providers/auth_preferences_provider.dart';
import '../../core/router/router.dart';
import 'widgets/auto_relogin_setup_dialog.dart';
import 'widgets/identity_auth_flow_screen.dart';
import 'widgets/login_auto_relogin_card.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.returnTo});

  final String? returnTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLaunchingFlow = false;
  bool _enableAutoReloginOnLogin = false;
  bool _guidePresentationRecorded = false;
  String? _errorMessage;
  ProviderSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = ref.listenManual<AuthState>(authProvider, (
      previous,
      next,
    ) {
      if (!_shouldAutoLeaveLogin(previous, next)) {
        return;
      }
      _navigateAfterAuthSuccess();
    });
  }

  @override
  void dispose() {
    _authSubscription?.close();
    super.dispose();
  }

  Future<void> _startLogin() async {
    if (_isLaunchingFlow) {
      return;
    }

    setState(() {
      _isLaunchingFlow = true;
      _errorMessage = null;
    });

    try {
      final result = await _openAuthFlow();
      if (!mounted) {
        return;
      }
      if (result == null) {
        return;
      }

      if (result.autoReloginConfigured) {
        AppToast.showSuccess(context, message: '自动重新登录已启用并完成校验');
      } else if (result.noticeMessage != null) {
        AppToast.showWarning(context, message: result.noticeMessage!);
      }
      _navigateAfterAuthSuccess();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = '登录暂时无法启动，请重试');
    } finally {
      if (mounted) {
        setState(() {
          _isLaunchingFlow = false;
        });
      }
    }
  }

  Future<AuthEntryResult?> _openAuthFlow() async {
    AuthEntryRequest request = const AuthEntryRequest.loginOnly();
    if (_enableAutoReloginOnLogin) {
      final initialUsername = await ref.read(
        preferredIdentityAccountProvider.future,
      );
      if (!mounted) {
        return null;
      }
      final input = await showDialog<AutoReloginSetupInput>(
        context: context,
        builder: (_) =>
            AutoReloginSetupDialog(initialUsername: initialUsername),
      );
      if (input == null || !mounted) {
        return null;
      }
      await ref.read(identityAccountHintStoreProvider).save(input.username);
      if (!mounted) {
        return null;
      }
      request = AuthEntryRequest.loginAndEnableAutoRelogin(input: input);
    }

    return Navigator.of(context).push<AuthEntryResult>(
      MaterialPageRoute(
        builder: (_) => IdentityAuthFlowScreen(request: request),
      ),
    );
  }

  Future<void> _showAutoReloginDetails() async {
    final c = context.colors;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: const Text('自动重新登录'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '开启后，会话过期时 LearnY 会自动尝试恢复登录。账号密码只保存在系统安全存储中，不会上传到我们的服务器。',
                style: AppTypography.bodyMedium.copyWith(
                  color: c.subtitle,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '如果学校提示“信任当前设备”，请确认后继续。学校要求验证码或人工验证时，仍需你完成登录。',
                style: AppTypography.bodyMedium.copyWith(
                  color: c.subtitle,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _dismissGuide() async {
    await ref
        .read(guidePresenterProvider)
        .dismiss(GuideRegistry.loginAutoRelogin);
    ref.invalidate(guideVisibilityProvider(GuideRegistry.loginAutoRelogin.id));
  }

  bool _shouldAutoLeaveLogin(AuthState? previous, AuthState next) {
    final becameUsable =
        next.canAccessCachedData && !next.requiresReauthentication;
    if (!becameUsable) {
      return false;
    }

    final wasUsable =
        previous != null &&
        previous.canAccessCachedData &&
        !previous.requiresReauthentication;
    return !wasUsable;
  }

  void _navigateAfterAuthSuccess() {
    if (!mounted) {
      return;
    }

    final auth = ref.read(authProvider);
    if (!auth.canAccessCachedData || auth.requiresReauthentication) {
      return;
    }

    final destination =
        widget.returnTo != null &&
            widget.returnTo!.isNotEmpty &&
            widget.returnTo != Routes.login
        ? widget.returnTo!
        : Routes.home;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final router = GoRouter.of(context);
      if (router.routerDelegate.currentConfiguration.uri.toString() ==
          destination) {
        return;
      }
      context.go(destination);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final buildInfo = ref.watch(appBuildInfoProvider).valueOrNull;
    final showGuideAsync = ref.watch(
      guideVisibilityProvider(GuideRegistry.loginAutoRelogin.id),
    );
    final showGuideBody = showGuideAsync.valueOrNull ?? true;

    if (showGuideBody && !_guidePresentationRecorded) {
      _guidePresentationRecorded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(guidePresenterProvider)
            .markPresented(GuideRegistry.loginAutoRelogin);
      });
    }
    if (!showGuideBody) {
      _guidePresentationRecorded = false;
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  final identity = Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: wide
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      const StudyMark(size: 64),
                      const SizedBox(height: 24),
                      Text(
                        'LearnY',
                        style: AppTypography.headlineLarge.copyWith(
                          color: c.text,
                          fontSize: wide ? 42 : 34,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '清华大学网络学堂',
                        style: AppTypography.bodyLarge.copyWith(
                          color: c.subtitle,
                        ),
                      ),
                    ],
                  );
                  final signIn = StudySurface(
                    tone: StudyTone.slate,
                    radius: 24,
                    padding: EdgeInsets.all(wide ? 32 : 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '登录',
                          style: AppTypography.headlineMedium.copyWith(
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '使用清华大学统一身份账号',
                          style: AppTypography.bodyMedium.copyWith(
                            color: c.subtitle,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_errorMessage != null) ...[
                          StudySurface(
                            tone: StudyTone.rose,
                            radius: 12,
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        LoginAutoReloginCard(
                          enabled: _enableAutoReloginOnLogin,
                          showGuideBody: showGuideBody,
                          onChanged: (value) =>
                              setState(() => _enableAutoReloginOnLogin = value),
                          onLearnMore: _showAutoReloginDetails,
                          onDismissGuide: _dismissGuide,
                        ),
                        const SizedBox(height: 22),
                        FilledButton(
                          onPressed: _isLaunchingFlow ? null : _startLogin,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLaunchingFlow
                              ? SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                  ),
                                )
                              : const Text('统一身份认证登录'),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          buildInfo?.shortLabel ?? '读取版本中...',
                          textAlign: TextAlign.center,
                          style: AppTypography.bodySmall.copyWith(
                            color: c.tertiary,
                          ),
                        ),
                      ],
                    ),
                  );
                  if (wide) {
                    return Row(
                      children: [
                        Expanded(child: identity),
                        const SizedBox(width: 48),
                        SizedBox(
                          width: constraints.maxWidth >= 840 ? 480 : 440,
                          child: signIn,
                        ),
                      ],
                    );
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      identity,
                      const SizedBox(height: 32),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: signIn,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
