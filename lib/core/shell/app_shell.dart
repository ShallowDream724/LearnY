/// App shell — adaptive navigation: bottom bar on phones, side rail on tablets.
///
/// Uses Material 3 NavigationBar (compact) / NavigationRail (medium+).
/// 4 tabs: Home, Assignments, Courses, Profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_theme_colors.dart';
import '../design/colors.dart';
import '../design/responsive.dart';
import '../design/typography.dart';
import '../providers/providers.dart';
import '../providers/connectivity_provider.dart';
import '../router/router.dart';

class AppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    if (index == navigationShell.currentIndex) {
      return;
    }
    navigationShell.goBranch(index);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    final useRail = shouldShowRail(context);
    final auth = ref.watch(authProvider);
    final connectivity = ref.watch(connectivityProvider);
    final isOffline = connectivity.status == NetworkStatus.offline;
    final isSessionExpired = auth.requiresReauthentication;
    final currentLocation = GoRouterState.of(context).uri.toString();

    // Wrap child with app-level banners.
    final content = Column(
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isSessionExpired
              ? _SessionExpiredBanner(
                  onLogin: () {
                    context.go(Routes.loginWithReturnTo(currentLocation));
                  },
                )
              : const SizedBox.shrink(),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isOffline ? _OfflineBanner() : const SizedBox.shrink(),
        ),
        Expanded(child: navigationShell),
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
    final c = context.colors;
    final layout = layoutTypeOf(context);
    final extended = layout == LayoutType.expanded;

    return Scaffold(
      body: Row(
        children: [
          // Side rail
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(right: BorderSide(color: c.border, width: 0.5)),
            ),
            child: NavigationRail(
              selectedIndex: index,
              onDestinationSelected: (i) => _onTap(context, i),
              extended: extended,
              minWidth: 72,
              minExtendedWidth: 200,
              backgroundColor: Colors.transparent,
              indicatorColor: AppColors.primary.withAlpha(30),
              selectedIconTheme: const IconThemeData(
                color: AppColors.primary,
                size: 24,
              ),
              unselectedIconTheme: IconThemeData(color: c.tertiary, size: 24),
              selectedLabelTextStyle: AppTypography.labelSmall.copyWith(
                color: AppColors.primary,
              ),
              unselectedLabelTextStyle: AppTypography.labelSmall.copyWith(
                color: c.tertiary,
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
                          color: c.text,
                        ),
                      )
                    : Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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

  Widget _buildBottomNavLayout(
    BuildContext context,
    int index,
    Widget content,
  ) {
    final c = context.colors;

    return Scaffold(
      body: content,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: c.border, width: 0.5)),
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

Widget buildAppShellBranchContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) {
  return _AppShellBranchContainer(
    navigationShell: navigationShell,
    children: children,
  );
}

class _AppShellBranchContainer extends StatefulWidget {
  const _AppShellBranchContainer({
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<_AppShellBranchContainer> createState() =>
      _AppShellBranchContainerState();
}

class _AppShellBranchContainerState extends State<_AppShellBranchContainer> {
  late final PageController _pageController;
  bool _isSyncingFromShell = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: widget.navigationShell.currentIndex,
    );
  }

  @override
  void didUpdateWidget(covariant _AppShellBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      _syncToShellIndex(widget.navigationShell.currentIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = widget.navigationShell.currentIndex;
    if (shouldShowRail(context)) {
      return IndexedStack(index: currentIndex, children: widget.children);
    }

    final currentPath = GoRouterState.of(context).uri.path;
    final swipeEnabled = _isTopLevelTabPath(currentPath);

    return PageView(
      controller: _pageController,
      physics: swipeEnabled
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (_isSyncingFromShell ||
            index == widget.navigationShell.currentIndex) {
          return;
        }
        widget.navigationShell.goBranch(index);
      },
      children: [
        for (final child in widget.children)
          _ShellBranchKeepAlive(child: child),
      ],
    );
  }

  Future<void> _syncToShellIndex(int targetIndex) async {
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncToShellIndex(targetIndex);
        }
      });
      return;
    }

    final currentPage =
        _pageController.page?.round() ?? _pageController.initialPage;
    if (currentPage == targetIndex) {
      return;
    }

    _isSyncingFromShell = true;
    try {
      final distance = (currentPage - targetIndex).abs();
      if (distance > 1) {
        _pageController.jumpToPage(targetIndex);
      } else {
        await _pageController.animateToPage(
          targetIndex,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      _isSyncingFromShell = false;
    }
  }

  bool _isTopLevelTabPath(String path) {
    return path == Routes.home ||
        path == Routes.assignments ||
        path == Routes.courses ||
        path == Routes.profile;
  }
}

class _ShellBranchKeepAlive extends StatefulWidget {
  const _ShellBranchKeepAlive({required this.child});

  final Widget child;

  @override
  State<_ShellBranchKeepAlive> createState() => _ShellBranchKeepAliveState();
}

class _ShellBranchKeepAliveState extends State<_ShellBranchKeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _SessionExpiredBanner extends StatelessWidget {
  final VoidCallback onLogin;

  const _SessionExpiredBanner({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppColors.warning.withAlpha(context.isDark ? 46 : 20),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '会话已过期，可继续查看缓存数据',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: onLogin,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.warning,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('重新登录'),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: AppColors.warning.withAlpha(context.isDark ? 40 : 25),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 14, color: AppColors.warning),
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
