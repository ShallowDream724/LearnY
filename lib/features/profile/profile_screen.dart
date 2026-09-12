// Profile / Settings screen.
//
// Shows user info, app preferences, and logout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_materials.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/design/wallpaper_picker.dart';
import '../../core/design/app_light_scene.dart';
import '../../core/providers/wallpaper_provider.dart';
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
    final wallpaper = ref.watch(effectiveWallpaperProvider);
    final mobileWallpaper = ref.watch(mobileWallpapersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: const StudyLightSurface(),
            pinned: true,
            titleSpacing: pageGutter(context, maxWidth: 880),
            title: Text(
              '设置',
              style: AppTypography.headlineMedium.copyWith(color: c.text),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              pageGutter(context, maxWidth: 880),
              16,
              pageGutter(context, maxWidth: 880),
              shellContentBottomInset(context),
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                StudySurface(
                  tone: StudyTone.jade,
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: StudyPalette.of(
                            context,
                            StudyTone.jade,
                          ).accent.withAlpha(18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: StudyPalette.of(
                              context,
                              StudyTone.jade,
                            ).accent.withAlpha(28),
                          ),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 34,
                          color: StudyPalette.of(
                            context,
                            StudyTone.jade,
                          ).accent,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authState.username ?? '未登录',
                              style: AppTypography.headlineSmall.copyWith(
                                color: c.text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _buildHeaderSubtitle(profileIdentity),
                              style: AppTypography.bodyMedium.copyWith(
                                color: c.subtitle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final preferences = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SettingsSectionLabel(label: '使用偏好'),
                        SettingsGroup(
                          tone: StudyTone.ink,
                          children: [
                            SettingsRow(
                              title: '外观',
                              subtitle: '选择适合你的阅读环境',
                              trailing: AppearanceMenu(
                                value: themeMode,
                                onChanged: _changeTheme,
                              ),
                            ),
                            SettingsRow(
                              title: '背景',
                              subtitle:
                                  '${wallpaper.label} · ${ref.watch(wallpaperIntensityProvider)}%',
                              onTap: () => showWallpaperPicker(context),
                              trailing: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image(
                                  image: ref.watch(wallpaperThumbnailProvider),
                                  width: mobileWallpaper ? 28 : 64,
                                  height: mobileWallpaper ? 56 : 40,
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                ),
                              ),
                            ),
                            SettingsSwitchRow(
                              title: '自动重新登录',
                              subtitle: _buildAutoReloginSummary(
                                enabled: autoReloginEnabled,
                                hasStoredCredential:
                                    hasStoredCredential.valueOrNull,
                                status: autoReloginStatus,
                              ),
                              onDetails: () => _showAutoReloginStatus(
                                enabled: autoReloginEnabled,
                                hasStoredCredential:
                                    hasStoredCredential.valueOrNull,
                                status: autoReloginStatus,
                              ),
                              value: autoReloginEnabled,
                              onChanged: _updatingAutoRelogin
                                  ? null
                                  : _changeAutoRelogin,
                            ),
                          ],
                        ),
                      ],
                    );
                    final about = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SettingsSectionLabel(label: '关于 LearnY'),
                        SettingsGroup(
                          children: [
                            SettingsRow(
                              title: '版本',
                              subtitle: buildInfo?.shortLabel ?? '读取中...',
                            ),
                            SettingsRow(
                              title: _checkingUpdates ? '正在检查更新' : '检查更新',
                              subtitle: _buildUpdateSubtitle(updateInfo),
                              trailingColor: updateInfo?.hasUpdate == true
                                  ? AppColors.warning
                                  : null,
                              onTap: _checkingUpdates ? null : _checkForUpdate,
                            ),
                            SettingsRow(
                              title: '源代码',
                              subtitle: '在 GitHub 查看 LearnY',
                              onTap: () => launchUrl(
                                Uri.parse(appRepositoryUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                            SettingsRow(
                              title: '开源许可',
                              onTap: () => showLicensePage(
                                context: context,
                                applicationName: 'LearnY',
                                applicationVersion: buildInfo?.shortLabel,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                    final files = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SettingsSectionLabel(label: '学习资料'),
                        SettingsGroup(
                          tone: StudyTone.ochre,
                          children: [
                            SettingsRow(
                              title: '课程文件',
                              subtitle: '当前学期的文件与附件',
                              onTap: () => context.push(Routes.files),
                            ),
                            SettingsRow(
                              title: '收藏文件',
                              subtitle: favoriteCount == 0
                                  ? '随时回到收藏的资料'
                                  : '$favoriteCount 个收藏文件',
                              onTap: () => context.push(Routes.favoriteFiles),
                            ),
                            SettingsRow(
                              title: '文件管理',
                              subtitle: '管理已下载的文件',
                              onTap: () => context.push(Routes.fileManager),
                            ),
                          ],
                        ),
                      ],
                    );
                    if (constraints.maxWidth >= 720) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                preferences,
                                const SizedBox(height: 26),
                                about,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(flex: 4, child: files),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        preferences,
                        const SizedBox(height: 26),
                        files,
                        const SizedBox(height: 26),
                        about,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _loggingOut ? null : _logout,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(120, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      foregroundColor: AppColors.error,
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

  String _buildAutoReloginSummary({
    required bool enabled,
    required bool? hasStoredCredential,
    required AutoReloginStatusSnapshot status,
  }) {
    if (!enabled) return '已关闭';
    if (hasStoredCredential == null || !status.isLoaded) return '正在读取状态';
    if (status.phase == AutoReloginStatusPhase.probing) return '正在验证登录';
    if (!hasStoredCredential ||
        status.phase == AutoReloginStatusPhase.needsSetup) {
      return '需要重新配置';
    }
    if (status.phase == AutoReloginStatusPhase.degraded) return '登录恢复需要关注';
    return status.lastProbeAt == null ? '已开启，等待验证' : '已就绪 · 会话过期后自动恢复';
  }

  Future<void> _showAutoReloginStatus({
    required bool enabled,
    required bool? hasStoredCredential,
    required AutoReloginStatusSnapshot status,
  }) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('自动重新登录'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '会话过期后自动尝试恢复登录。学校要求验证码或人工验证时，仍需你完成登录。',
              style: AppTypography.bodyMedium.copyWith(
                color: context.colors.subtitle,
              ),
            ),
            const SizedBox(height: 20),
            StudySurface(
              tone: StudyTone.jade,
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  _buildAutoReloginDetails(
                    enabled: enabled,
                    hasStoredCredential: hasStoredCredential,
                    status: status,
                  ),
                  style: AppTypography.bodyMedium.copyWith(
                    color: context.colors.text,
                    height: 1.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

  String _buildAutoReloginDetails({
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
      lines.add('最近学堂恢复：$recoveryMethod · ${_formatStatusTime(recoveryAt)}');
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
