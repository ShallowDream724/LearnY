/// Profile / Settings screen.
///
/// Shows user info, app preferences, and logout.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/router/router.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final authState = ref.watch(authProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text(
              '我的',
              style: AppTypography.headlineMedium.copyWith(color: textColor),
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
                        color: AppColors.primary.withAlpha(isDark ? 40 : 30),
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
                              style: AppTypography.titleLarge
                                  .copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '清华大学',
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
                _SectionLabel(label: '偏好设置', textColor: subColor),
                const SizedBox(height: 8),

                // Theme setting
                _SettingsCard(
                  surface: surface,
                  border: border,
                  children: [
                    _SettingsTile(
                      icon: Icons.palette_outlined,
                      title: '外观',
                      subtitle: switch (themeMode) {
                        'light' => '浅色',
                        'dark' => '深色',
                        _ => '跟随系统',
                      },
                      textColor: textColor,
                      subColor: subColor,
                      onTap: () {
                        // Cycle: system → light → dark
                        final next = switch (themeMode) {
                          'system' => 'light',
                          'light' => 'dark',
                          _ => 'system',
                        };
                        ref.read(themeModeProvider.notifier).state = next;
                      },
                    ),
                  ],
                )
                    .animate(delay: 100.ms)
                    .fadeIn(duration: 300.ms),

                const SizedBox(height: 24),

                // ── About Section ──
                _SectionLabel(label: '关于', textColor: subColor),
                const SizedBox(height: 8),

                _SettingsCard(
                  surface: surface,
                  border: border,
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outlined,
                      title: '版本',
                      subtitle: 'v0.1.0',
                      textColor: textColor,
                      subColor: subColor,
                    ),
                    Divider(color: border, height: 0),
                    _SettingsTile(
                      icon: Icons.code_rounded,
                      title: '源代码',
                      subtitle: 'GitHub',
                      textColor: textColor,
                      subColor: subColor,
                      onTap: () {
                        // Open GitHub repo
                        launchUrl(Uri.parse('https://github.com/ShallowDream724/LearnY'));
                      },
                    ),
                  ],
                )
                    .animate(delay: 200.ms)
                    .fadeIn(duration: 300.ms),

                const SizedBox(height: 32),

                // ── Logout ──
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (!context.mounted) return;
                      context.go(Routes.login);
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
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.error),
                    ),
                  ),
                )
                    .animate(delay: 300.ms)
                    .fadeIn(duration: 300.ms),
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
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subColor,
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
              child: Text(title,
                  style: AppTypography.titleMedium.copyWith(color: textColor)),
            ),
            Text(subtitle,
                style: AppTypography.bodySmall.copyWith(color: subColor)),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 18, color: subColor),
            ],
          ],
        ),
      ),
    );
  }
}
