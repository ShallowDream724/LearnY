/// App shell — adaptive navigation: bottom bar on phones, side rail on tablets.
///
/// Uses Material 3 NavigationBar (compact) / NavigationRail (medium+).
/// 5 tabs: Home, Assignments, Files, Courses, Profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../design/responsive.dart';
import '../providers/connectivity_provider.dart';
import '../router/router.dart';

class AppShell extends ConsumerWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith(Routes.assignments)) return 1;
    if (location.startsWith(Routes.files)) return 2;
    if (location.startsWith(Routes.courses)) return 3;
    if (location.startsWith(Routes.profile)) return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(Routes.home);
      case 1:
        context.go(Routes.assignments);
      case 2:
        context.go(Routes.files);
      case 3:
        context.go(Routes.courses);
      case 4:
        context.go(Routes.profile);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = _currentIndex(context);
    final useRail = shouldShowRail(context);
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.status == NetworkStatus.offline;

    // Wrap child with offline banner
    final content = Column(
      children: [
        // Offline banner
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isOffline
              ? _OfflineBanner()
              : const SizedBox.shrink(),
        ),
        // Content
        Expanded(child: child),
      ],
    );

    if (useRail) {
      return _buildRailLayout(context, index, content);
    }
    return _buildBottomNavLayout(context, index, content);
  }

  // ─────────────────────────────────────────────
  //  Tablet: NavigationRail
  // ─────────────────────────────────────────────

  Widget _buildRailLayout(BuildContext context, int index, Widget content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final layout = layoutTypeOf(context);
    final extended = layout == LayoutType.expanded;

    return Scaffold(
      body: Row(
        children: [
          // Side rail
          Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border(
                right: BorderSide(color: border, width: 0.5),
              ),
            ),
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _onTap(context, i),
              extended: extended,
              minWidth: 72,
              minExtendedWidth: 200,
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.primary.withAlpha(30),
              selectedIconTheme:
                  const IconThemeData(color: AppColors.primary, size: 24),
              unselectedIconTheme: IconThemeData(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
                size: 24,
              ),
              selectedLabelTextStyle:
                  AppTypography.labelSmall.copyWith(color: AppColors.primary),
              unselectedLabelTextStyle: AppTypography.labelSmall.copyWith(
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.lightTextTertiary,
              ),
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              leading: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: extended ? 20 : 0,
                ),
                child: extended
                    ? Text(
                        'LearnY',
                        style: AppTypography.headlineSmall.copyWith(
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.lightTextPrimary,
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primary,
                              AppColors.primaryDark,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.school_rounded,
                            color: Colors.white, size: 20),
                      ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('首页'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment_rounded),
                  label: Text('作业'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_rounded),
                  label: Text('文件'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.school_outlined),
                  selectedIcon: Icon(Icons.school_rounded),
                  label: Text('课程'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outlined),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('我的'),
                ),
              ],
            ),
          ),

          // Content area
          Expanded(child: content),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  Phone: bottom NavigationBar
  // ─────────────────────────────────────────────

  Widget _buildBottomNavLayout(BuildContext context, int index, Widget content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      body: content,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => _onTap(context, i),
          height: Spacing.bottomNavHeight,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment_rounded),
              label: '作业',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              selectedIcon: Icon(Icons.folder_rounded),
              label: '文件',
            ),
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: '课程',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outlined),
              selectedIcon: Icon(Icons.person_rounded),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }
}

/// Subtle offline indicator banner.
class _OfflineBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.warning.withAlpha(isDark ? 40 : 25),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded,
                size: 14, color: AppColors.warning),
            const SizedBox(width: 6),
            Text(
              '网络不可用，显示的是缓存数据',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
