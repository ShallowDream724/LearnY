import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth.dart';
import '../../core/design/app_toast.dart';
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
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: c.surface,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '自动重新登录说明',
                  style: AppTypography.titleLarge.copyWith(color: c.text),
                ),
                const SizedBox(height: 12),
                Text(
                  '开启后，LearnY 会在首次登录时顺带验证静默恢复能力。账号密码只保存在系统安全存储中，不会写入本地数据库，也不会上传到我们的服务器。',
                  style: AppTypography.bodyMedium.copyWith(
                    color: c.subtitle,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '如果统一身份页面出现“信任当前设备 / 180天”等提示，建议勾选。这样后续会话过期时，应用才有机会自动恢复，而不是再次打断你手动登录。',
                  style: AppTypography.bodyMedium.copyWith(
                    color: c.subtitle,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              _buildLogo()
                  .animate()
                  .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                  .slideY(begin: -0.1, end: 0),
              const SizedBox(height: 28),
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
              Text(
                '清华大学网络学堂',
                style: AppTypography.bodyLarge.copyWith(
                  color: c.subtitle,
                  letterSpacing: 2,
                ),
              ).animate(delay: 400.ms).fadeIn(duration: 500.ms),
              const Spacer(flex: 2),
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
                const SizedBox(height: 16),
              ],
              LoginAutoReloginCard(
                    enabled: _enableAutoReloginOnLogin,
                    showGuideBody: showGuideBody,
                    onChanged: (value) {
                      setState(() {
                        _enableAutoReloginOnLogin = value;
                      });
                    },
                    onLearnMore: _showAutoReloginDetails,
                    onDismissGuide: _dismissGuide,
                  )
                  .animate(delay: 540.ms)
                  .fadeIn(duration: 450.ms)
                  .slideY(begin: 0.1, end: 0),
              const SizedBox(height: 18),
              SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLaunchingFlow ? null : _startLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLaunchingFlow
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
                  .animate(delay: 620.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.15, end: 0),
              const SizedBox(height: 16),
              Text(
                buildInfo?.shortLabel ?? '读取版本中...',
                style: AppTypography.bodySmall.copyWith(
                  color: c.subtitle.withAlpha(120),
                ),
              ).animate(delay: 780.ms).fadeIn(duration: 400.ms),
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
}
