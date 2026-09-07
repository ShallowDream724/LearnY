// Profile / Settings screen.
//
// Shows user info, app preferences, and logout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/router/router.dart';
import '../../core/shell/shell_layout_metrics.dart';
import '../../core/utils/china_time.dart';
import '../files/providers/file_bookmark_providers.dart';
import 'providers/profile_identity_provider.dart';
import 'widgets/auto_relogin_enrollment_screen.dart';
import 'widgets/auto_relogin_setup_dialog.dart';
import 'widgets/appearance_menu.dart';
import 'widgets/settings_rows.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _updatingAutoRelogin = false;
  bool _checkingUpdates = false;
  bool _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);
    final autoReloginEnabled = ref.watch(autoReloginEnabledProvider);
    final hasStoredCredential = ref.watch(storedCredentialAvailabilityProvider);
    final autoReloginStatus = ref.watch(autoReloginStatusProvider);
    final favoriteCount =
        ref.watch(bookmarkedFileCountProvider).valueOrNull ?? 0;
    final profileIdentity = ref.watch(profileIdentityProvider).valueOrNull;
    final buildInfo = ref.watch(appBuildInfoProvider).valueOrNull;
    final updateInfo = ref.watch(appUpdateInfoProvider).valueOrNull;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            titleSpacing: pageGutter(context, maxWidth: 760),
            title: Text(
              '设置',
              style: AppTypography.headlineMedium.copyWith(color: c.text),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              pageGutter(context, maxWidth: 760),
              8,
              pageGutter(context, maxWidth: 760),
              shellContentBottomInset(context),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── User Card ──
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: c.surfaceHigh,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _initials(authState.username ?? ''),
                            style: AppTypography.titleLarge.copyWith(
                              color: c.text,
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
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _buildHeaderSubtitle(profileIdentity),
                              style: AppTypography.bodySmall.copyWith(
                                color: c.subtitle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Settings Section ──
                SettingsSectionLabel(label: '偏好设置'),
                const SizedBox(height: 8),

                // Theme setting
                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.palette_outlined,
                      title: '外观',
                      trailing: AppearanceMenu(
                        value: themeMode,
                        onChanged: _changeTheme,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                SettingsSectionLabel(label: '登录与安全'),
                const SizedBox(height: 8),

                SettingsGroup(
                  children: [
                    SettingsSwitchRow(
                      icon: Icons.lock_clock_outlined,
                      title: '自动重新登录',
                      subtitle: _buildAutoReloginSubtitle(
                        enabled: autoReloginEnabled,
                        hasStoredCredential: hasStoredCredential.valueOrNull,
                        status: autoReloginStatus,
                      ),
                      value: autoReloginEnabled,
                      onChanged: _updatingAutoRelogin
                          ? null
                          : _changeAutoRelogin,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Data Management Section ──
                SettingsSectionLabel(label: '数据管理'),
                const SizedBox(height: 8),

                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.folder_copy_outlined,
                      title: '课程文件',
                      subtitle: '当前学习学期的文件与附件',
                      onTap: () => context.push(Routes.files),
                    ),
                    SettingsRow(
                      icon: Icons.bookmark_outline_rounded,
                      title: '收藏文件',
                      subtitle: favoriteCount == 0
                          ? '查看你收藏的文件'
                          : '$favoriteCount 个收藏文件',
                      onTap: () => context.push(Routes.favoriteFiles),
                    ),
                    SettingsRow(
                      icon: Icons.folder_rounded,
                      title: '文件管理',
                      subtitle: '管理已下载的文件',
                      onTap: () => context.push(Routes.fileManager),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── About Section ──
                SettingsSectionLabel(label: '关于'),
                const SizedBox(height: 8),

                SettingsGroup(
                  children: [
                    SettingsRow(
                      icon: Icons.info_outlined,
                      title: '版本',
                      subtitle: buildInfo?.shortLabel ?? '读取中...',
                    ),
                    SettingsRow(
                      icon: updateInfo?.hasUpdate == true
                          ? Icons.system_update_rounded
                          : Icons.update_rounded,
                      title: _checkingUpdates ? '正在检查更新' : '检查更新',
                      subtitle: _buildUpdateSubtitle(updateInfo),
                      trailingColor: updateInfo?.hasUpdate == true
                          ? AppColors.warning
                          : null,
                      onTap: _checkingUpdates ? null : _checkForUpdate,
                    ),
                    SettingsRow(
                      icon: Icons.code_rounded,
                      title: '源代码',
                      subtitle: 'GitHub',
                      onTap: () {
                        // Open GitHub repo
                        launchUrl(
                          Uri.parse(appRepositoryUrl),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // ── Logout ──
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loggingOut ? null : _logout,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withAlpha(60)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _loggingOut ? '正在退出' : '退出登录',
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ),
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

  Future<void> _changeAutoRelogin(bool enabled) async {
    setState(() => _updatingAutoRelogin = true);
    try {
      await _handleAutoReloginToggle(context, ref, enabled: enabled);
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '自动重新登录设置失败，请重试');
    } finally {
      if (mounted) setState(() => _updatingAutoRelogin = false);
    }
  }

  Future<void> _changeTheme(String value) async {
    try {
      await ref.read(themeModeProvider.notifier).setTheme(value);
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '外观设置未能保存');
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdates = true);
    try {
      await _handleUpdateTap(context, ref);
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '检查更新失败');
    } finally {
      if (mounted) setState(() => _checkingUpdates = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await ref.read(authProvider.notifier).logout();
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '退出登录失败，请重试');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
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
    required AutoReloginStatusSnapshot status,
  }) {
    if (!enabled) {
      return '关闭';
    }
    if (hasStoredCredential == null || !status.isLoaded) {
      return '读取中...';
    }
    if (status.phase == AutoReloginStatusPhase.probing) {
      return '正在验证';
    }
    if (!hasStoredCredential) {
      if (status.failureDisplayLabel == null) {
        return '需重新配置';
      }
      return '需重新配置\n最近失败：${status.failureDisplayLabel!}';
    }
    if (status.phase == AutoReloginStatusPhase.needsSetup) {
      return status.failureDisplayLabel == null
          ? '需配置'
          : '需配置\n最近失败：${status.failureDisplayLabel!}';
    }

    final probeAt = status.lastProbeAt;
    if (probeAt == null) {
      return '待验证';
    }

    final lines = <String>['已就绪', '最近校验：${_buildProbeLabel(status, probeAt)}'];
    if (status.phase == AutoReloginStatusPhase.degraded &&
        status.failureDisplayLabel != null) {
      lines.insert(0, '最近失败：${status.failureDisplayLabel!}');
    }

    final recoveryMethod = status.recoveryMethodDisplayLabel;
    final recoveryAt = status.lastRecoveryAt;
    if (recoveryMethod != null && recoveryAt != null) {
      lines.add('最近恢复：$recoveryMethod · ${_formatStatusTime(recoveryAt)}');
    }
    return lines.join('\n');
  }

  String _buildProbeLabel(AutoReloginStatusSnapshot status, DateTime probeAt) {
    final method = status.probeMethodDisplayLabel;
    if (method == null) {
      return _formatStatusTime(probeAt);
    }
    return '$method · ${_formatStatusTime(probeAt)}';
  }

  String _formatStatusTime(DateTime time) {
    return formatMonthDayHourMinuteInChina(time);
  }

  Future<void> _handleAutoReloginToggle(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    if (!enabled) {
      await ref.read(autoReloginCapabilityStoreProvider).disable();
      if (context.mounted) {
        AppToast.showInfo(context, message: '已关闭自动重新登录');
      }
      return;
    }

    final initialUsername = await ref.read(
      preferredIdentityAccountProvider.future,
    );
    if (!context.mounted) {
      return;
    }
    final input = await showDialog<AutoReloginSetupInput>(
      context: context,
      builder: (_) => AutoReloginSetupDialog(initialUsername: initialUsername),
    );
    if (input == null || !context.mounted) {
      return;
    }
    await ref.read(identityAccountHintStoreProvider).save(input.username);
    if (!context.mounted) {
      return;
    }

    final result = await Navigator.of(context).push<AuthEntryResult>(
      MaterialPageRoute(
        builder: (_) => AutoReloginEnrollmentScreen(input: input),
      ),
    );
    if (!context.mounted || result == null) {
      return;
    }
    if (result.autoReloginConfigured) {
      AppToast.showSuccess(context, message: '已启用并验证自动重新登录');
      return;
    }
    if (result.noticeMessage != null) {
      AppToast.showWarning(context, message: result.noticeMessage!);
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
