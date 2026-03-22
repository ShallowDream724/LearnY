// Profile / Settings screen.
//
// Shows user info, app preferences, and logout.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/router/router.dart';
import '../files/providers/file_bookmark_providers.dart';
import 'providers/profile_identity_provider.dart';
import 'widgets/auto_relogin_enrollment_screen.dart';
import 'widgets/auto_relogin_setup_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final autoReloginEnabled = ref.watch(autoReloginEnabledProvider);
    final hasStoredCredential = ref.watch(storedCredentialAvailabilityProvider);
    final favoriteCount =
        ref.watch(bookmarkedFileCountProvider).valueOrNull ?? 0;
    final profileIdentity = ref.watch(profileIdentityProvider).valueOrNull;
    final buildInfo = ref.watch(appBuildInfoProvider).valueOrNull;
    final updateInfo = ref.watch(appUpdateInfoProvider).valueOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text(
              '我的',
              style: AppTypography.headlineMedium.copyWith(color: c.text),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── User Card ──
                Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.primaryDark, AppColors.primary],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withAlpha(
                              c.isDark ? 40 : 30,
                            ),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text(
                                _initials(authState.username ?? ''),
                                style: AppTypography.titleLarge.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authState.username ?? '未登录',
                                  style: AppTypography.titleLarge.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _buildHeaderSubtitle(profileIdentity),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: Colors.white.withAlpha(180),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0),

                const SizedBox(height: 24),

                // ── Settings Section ──
                _SectionLabel(label: '偏好设置', textColor: c.subtitle),
                const SizedBox(height: 8),

                // Theme setting
                _SettingsCard(
                  surface: c.surface,
                  border: c.border,
                  children: [
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: '外观',
                      subtitle: switch (themeMode) {
                        'light' => '浅色',
                        'dark' => '深色',
                        _ => '跟随系统',
                      },
                      textColor: c.text,
                      subColor: c.subtitle,
                      onTap: () {
                        // Cycle: system → light → dark
                        final next = switch (themeMode) {
                          'system' => 'light',
                          'light' => 'dark',
                          _ => 'system',
                        };
                        ref.read(themeModeProvider.notifier).setTheme(next);
                      },
                    ),
                  ],
                ).animate(delay: 100.ms).fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                _SectionLabel(label: '登录与安全', textColor: c.subtitle),
                const SizedBox(height: 8),

                _SettingsCard(
                  surface: c.surface,
                  border: c.border,
                  children: [
                    _SettingsSwitchTile(
                      icon: Icons.lock_clock_outlined,
                      title: '自动重新登录',
                      subtitle: _buildAutoReloginSubtitle(
                        enabled: autoReloginEnabled,
                        hasStoredCredential: hasStoredCredential.valueOrNull,
                      ),
                      value: autoReloginEnabled,
                      textColor: c.text,
                      subColor: c.subtitle,
                      onChanged: (value) => _handleAutoReloginToggle(
                        context,
                        ref,
                        enabled: value,
                      ),
                    ),
                  ],
                ).animate(delay: 125.ms).fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                // ── Data Management Section ──
                _SectionLabel(label: '数据管理', textColor: c.subtitle),
                const SizedBox(height: 8),

                _SettingsCard(
                  surface: c.surface,
                  border: c.border,
                  children: [
                    _SettingsTile(
                      icon: Icons.bookmark_outline_rounded,
                      title: '收藏文件',
                      subtitle: favoriteCount == 0
                          ? '查看你收藏的文件'
                          : '$favoriteCount 个收藏文件',
                      textColor: c.text,
                      subColor: c.subtitle,
                      onTap: () => context.push(Routes.favoriteFiles),
                    ),
                    Divider(color: c.border, height: 0),
                    _SettingsTile(
                      icon: Icons.folder_rounded,
                      title: '文件管理',
                      subtitle: '管理已下载的文件',
                      textColor: c.text,
                      subColor: c.subtitle,
                      onTap: () => context.push(Routes.fileManager),
                    ),
                  ],
                ).animate(delay: 150.ms).fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                // ── About Section ──
                _SectionLabel(label: '关于', textColor: c.subtitle),
                const SizedBox(height: 8),

                _SettingsCard(
                  surface: c.surface,
                  border: c.border,
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outlined,
                      title: '版本',
                      subtitle: buildInfo?.shortLabel ?? '读取中...',
                      textColor: c.text,
                      subColor: c.subtitle,
                    ),
                    Divider(color: c.border, height: 0),
                    _SettingsTile(
                      icon: updateInfo?.hasUpdate == true
                          ? Icons.system_update_rounded
                          : Icons.update_rounded,
                      title: '检查更新',
                      subtitle: _buildUpdateSubtitle(updateInfo),
                      textColor: c.text,
                      subColor: c.subtitle,
                      trailingColor: updateInfo?.hasUpdate == true
                          ? AppColors.warning
                          : null,
                      onTap: () => _handleUpdateTap(context, ref),
                    ),
                    Divider(color: c.border, height: 0),
                    _SettingsTile(
                      icon: Icons.code_rounded,
                      title: '源代码',
                      subtitle: 'GitHub',
                      textColor: c.text,
                      subColor: c.subtitle,
                      onTap: () {
                        // Open GitHub repo
                        launchUrl(
                          Uri.parse(appRepositoryUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ).animate(delay: 200.ms).fadeIn(duration: 300.ms),

                const SizedBox(height: 32),

                // ── Logout ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withAlpha(60)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      '退出登录',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '';
    final chars = name.runes.toList();
    if (chars.isNotEmpty && chars[0] > 127) {
      return String.fromCharCode(chars[0]);
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  String _buildHeaderSubtitle(ProfileIdentity? identity) {
    final department = identity?.department.trim() ?? '';
    if (department.isEmpty) {
      return '清华大学';
    }
    return '清华大学 · $department';
  }

  String _buildUpdateSubtitle(AppUpdateInfo? updateInfo) {
    if (updateInfo == null) {
      return '检查中...';
    }
    if (updateInfo.hasUpdate && updateInfo.displayLatestVersion != null) {
      return '发现 ${updateInfo.displayLatestVersion}';
    }
    if (updateInfo.hasNoPublishedRelease) {
      return '暂无发布';
    }
    if (updateInfo.isUnavailable) {
      return 'GitHub 不可达';
    }
    return '当前 ${updateInfo.currentBuild.shortLabel}';
  }

  String _buildAutoReloginSubtitle({
    required bool enabled,
    required bool? hasStoredCredential,
  }) {
    if (!enabled) {
      return '关闭';
    }
    if (hasStoredCredential == null) {
      return '读取中...';
    }
    if (!hasStoredCredential) {
      return '需重新配置';
    }
    return '已开启';
  }

  Future<void> _handleAutoReloginToggle(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    if (!enabled) {
      await ref.read(authReloginServiceProvider).clearStoredCredential();
      await ref.read(autoReloginEnabledProvider.notifier).setEnabled(false);
      ref.invalidate(storedCredentialAvailabilityProvider);
      if (context.mounted) {
        AppToast.showInfo(context, message: '已关闭自动重新登录');
      }
      return;
    }

    final input = await showDialog<AutoReloginSetupInput>(
      context: context,
      builder: (_) => const AutoReloginSetupDialog(),
    );
    if (input == null || !context.mounted) {
      return;
    }

    final configured = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AutoReloginEnrollmentScreen(input: input),
      ),
    );
    if (configured == true && context.mounted) {
      AppToast.showSuccess(context, message: '已启用自动重新登录');
    }
  }

  Future<void> _handleUpdateTap(BuildContext context, WidgetRef ref) async {
    final info = await ref.refresh(appUpdateInfoProvider.future);
    if (!context.mounted) {
      return;
    }

    if (info.hasUpdate && info.releaseUrl != null) {
      AppToast.showInfo(
        context,
        message: '发现新版本 ${info.displayLatestVersion ?? info.latestVersion}',
        actionLabel: '打开',
        onAction: () {
          launchUrl(
            Uri.parse(info.releaseUrl!),
            mode: LaunchMode.externalApplication,
          );
        },
      );
      return;
    }

    if (info.isUnavailable) {
      AppToast.showWarning(context, message: info.errorMessage ?? 'GitHub 不可达');
      return;
    }

    if (info.hasNoPublishedRelease) {
      AppToast.showInfo(context, message: 'GitHub 已连接，但当前还没有发布版本');
      return;
    }

    AppToast.showSuccess(context, message: '已是最新版本');
  }
}

// ─────────────────────────────────────────────
//  Helper widgets
// ─────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color textColor;

  const _SectionLabel({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTypography.labelSmall.copyWith(
        color: textColor,
        letterSpacing: 1,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Color surface;
  final Color border;
  final List<Widget> children;

  const _SettingsCard({
    required this.surface,
    required this.border,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subColor;
  final Color? trailingColor;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subColor,
    this.trailingColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: subColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTypography.titleMedium.copyWith(color: textColor),
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: trailingColor ?? subColor,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: trailingColor ?? subColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.textColor,
    required this.subColor,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color textColor;
  final Color subColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: subColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(color: textColor),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall.copyWith(color: subColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
