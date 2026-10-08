import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/app_surfaces.dart';
import '../design/app_toast.dart';
import '../design/app_light_scene.dart';
import '../design/app_materials.dart';
import '../design/app_theme_colors.dart';
import '../design/responsive.dart';
import '../design/typography.dart';
import '../providers/connectivity_provider.dart';
import '../providers/providers.dart';
import '../providers/wallpaper_provider.dart';
import '../router/router.dart';
import '../semester/semester_switcher.dart';
import '../../features/home/providers/home_schedule_provider.dart';
import 'app_bottom_navigation.dart';
import 'shell_navigation_progress.dart';
import 'shell_branch_back_scope.dart';

const _destinations = <ShellNavDestinationData>[
  ShellNavDestinationData(
    icon: CupertinoIcons.house,
    selectedIcon: CupertinoIcons.house_fill,
    label: '首页',
  ),
  ShellNavDestinationData(
    icon: CupertinoIcons.doc_text,
    selectedIcon: CupertinoIcons.doc_text_fill,
    label: '作业',
  ),
  ShellNavDestinationData(
    icon: CupertinoIcons.square_grid_2x2,
    selectedIcon: CupertinoIcons.square_grid_2x2_fill,
    label: '课程',
  ),
  ShellNavDestinationData(
    icon: CupertinoIcons.person_crop_circle,
    selectedIcon: CupertinoIcons.person_crop_circle_fill,
    label: '我的',
  ),
];

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  late final _navigationProgress = ShellNavigationProgress(
    widget.navigationShell.currentIndex.toDouble(),
  );

  @override
  void dispose() {
    _navigationProgress.dispose();
    super.dispose();
  }

  void _select(int index) {
    _navigationProgress.settlePage(index);
    if (index != widget.navigationShell.currentIndex) {
      widget.navigationShell.goBranch(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rail = shouldShowRail(context);
    final auth = ref.watch(authProvider);
    final offline =
        ref.watch(connectivityProvider).status == NetworkStatus.offline;
    final campusVerification = ref.watch(
      campusIdentityVerificationRequiredProvider,
    );
    final location = GoRouterState.of(context).uri.toString();
    Future<void> refreshAll() async {
      final result = await ref.read(homeRefreshActionsProvider).refresh();
      if (!context.mounted || !result.isCurrent || result.scheduleRefreshed) {
        return;
      }
      AppToast.showWarning(
        context,
        message: '课表刷新失败，其他内容状态请查看同步结果',
        actionLabel: '重试',
        onAction: refreshAll,
      );
    }

    final content = ContentLayout(
      child: Column(
        children: [
          if (auth.requiresReauthentication || campusVerification)
            _AccessNotice(
              icon: Icons.lock_clock_outlined,
              message: auth.requiresReauthentication
                  ? '登录已过期，已有内容仍可查看'
                  : '校园登录需要验证，已有内容仍可查看',
              action: TextButton(
                onPressed: () => context.go(Routes.loginWithReturnTo(location)),
                child: const Text('重新登录'),
              ),
            )
          else if (offline)
            const _AccessNotice(
              icon: Icons.wifi_off_outlined,
              message: '当前离线，正在显示已保存的内容',
            ),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
    return StudyLightBackdrop(
      wallpaper: ref.watch(effectiveWallpaperProvider),
      imageProvider: ref.watch(
        wallpaperImageProvider(Theme.of(context).brightness),
      ),
      mobileArtwork: ref.watch(mobileWallpapersProvider),
      strength: ref.watch(wallpaperIntensityProvider) / 100,
      child: ShellNavigationProgressScope(
        progress: _navigationProgress,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          extendBody: !rail,
          body: rail
              ? Row(
                  children: [
                    _Sidebar(
                      index: widget.navigationShell.currentIndex,
                      onSelected: _select,
                      onRefresh: refreshAll,
                    ),
                    Expanded(child: content),
                  ],
                )
              : content,
          bottomNavigationBar:
              rail || MediaQuery.viewInsetsOf(context).bottom > 0
              ? null
              : AppBottomNavigation(
                  destinations: _destinations,
                  selectedIndex: widget.navigationShell.currentIndex,
                  progress: _navigationProgress,
                  onTap: _select,
                ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.index,
    required this.onSelected,
    required this.onRefresh,
  });
  final int index;
  final ValueChanged<int> onSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final extended = MediaQuery.sizeOf(context).width >= 1000;
    return Material(
      color: c.surface.withAlpha(context.isDark ? 76 : 108),
      child: Container(
        width: extended ? 208 : 80,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: c.border, width: .5)),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(extended ? 24 : 8, 30, 8, 30),
                child: extended
                    ? Row(
                        children: [
                          const StudyMark(size: 30),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'LearnY',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.headlineMedium.copyWith(
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Tooltip(
                        message: 'LearnY',
                        child: const StudyMark(size: 30),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final (i, destination) in _destinations.indexed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: extended
                            ? ListTile(
                                selected: i == index,
                                selectedColor: c.infoAccent,
                                selectedTileColor: c.surface,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minLeadingWidth: 20,
                                horizontalTitleGap: 12,
                                leading: Icon(
                                  i == index
                                      ? destination.selectedIcon
                                      : destination.icon,
                                  size: 20,
                                ),
                                title: Text(
                                  destination.label,
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: i == index
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                                onTap: () => onSelected(i),
                              )
                            : IconButton(
                                tooltip: destination.label,
                                isSelected: i == index,
                                style: IconButton.styleFrom(
                                  backgroundColor: i == index
                                      ? c.surface
                                      : null,
                                  foregroundColor: i == index
                                      ? c.infoAccent
                                      : c.subtitle,
                                ),
                                icon: Icon(destination.icon),
                                selectedIcon: Icon(destination.selectedIcon),
                                onPressed: () => onSelected(i),
                              ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                child: extended
                    ? Row(
                        children: [
                          const Expanded(child: SemesterSelector()),
                          SemesterSyncControl(
                            onRefresh: onRefresh,
                            refreshTooltip: '刷新全部内容和课表',
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const SemesterSelector(iconOnly: true),
                          SemesterSyncControl(
                            onRefresh: onRefresh,
                            refreshTooltip: '刷新全部内容和课表',
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget buildAppShellBranchContainer(
  BuildContext context,
  StatefulNavigationShell navigationShell,
  List<Widget> children,
) => _BranchPager(navigationShell: navigationShell, children: children);

/// Keep one pager identity across resizing, so branch navigators retain context.
/// Taps switch directly; touch swipes use Flutter's own page physics.
class _BranchPager extends StatefulWidget {
  const _BranchPager({required this.navigationShell, required this.children});
  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  State<_BranchPager> createState() => _BranchPagerState();
}

class _BranchPagerState extends State<_BranchPager> {
  late final PageController _controller;
  ShellNavigationProgress? _progress;
  bool _jumping = false;
  int? _selectionFromPager;

  @override
  void initState() {
    super.initState();
    _controller = PageController(
      initialPage: widget.navigationShell.currentIndex,
    )..addListener(_publishPage);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = ShellNavigationProgressScope.of(context);
    if (!identical(_progress, next)) {
      _progress?.detach(_controller);
      _progress = next..attach(_controller);
    }
  }

  void _publishPage() {
    if (_jumping ||
        _progress?.selecting == true ||
        !_controller.hasClients ||
        !_controller.position.hasContentDimensions) {
      return;
    }
    final page = _controller.page;
    if (page != null) {
      _progress?.follow(page.clamp(0, widget.children.length - 1).toDouble());
    }
  }

  @override
  void didUpdateWidget(covariant _BranchPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      final target = widget.navigationShell.currentIndex;
      final fromPager = _selectionFromPager == target;
      _selectionFromPager = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !_controller.hasClients ||
            widget.navigationShell.currentIndex != target) {
          return;
        }
        // Pager-driven changes keep their physics; explicit navigation cancels it.
        if (!fromPager) {
          _progress?.select(target);
          _jumping = true;
          try {
            _controller.jumpToPage(target);
          } finally {
            _jumping = false;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _progress?.detach(_controller);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final shellIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    final topLevel = const [
      Routes.home,
      Routes.assignments,
      Routes.courses,
      Routes.profile,
    ].contains(path);
    return PageView(
      controller: _controller,
      physics: !shouldShowRail(context) && topLevel
          ? const PageScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      onPageChanged: (index) {
        if (widget.navigationShell.currentIndex != index) {
          _selectionFromPager = index;
          widget.navigationShell.goBranch(index);
        }
      },
      children: [
        for (var index = 0; index < widget.children.length; index++)
          _KeepBranch(
            child: ShellBranchBackScope(
              enabled:
                  shellIsCurrent &&
                  index == widget.navigationShell.currentIndex,
              child: TickerMode(
                enabled: index == widget.navigationShell.currentIndex,
                child: ExcludeFocus(
                  excluding: index != widget.navigationShell.currentIndex,
                  child: widget.children[index],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _KeepBranch extends StatefulWidget {
  const _KeepBranch({required this.child});
  final Widget child;
  @override
  State<_KeepBranch> createState() => _KeepBranchState();
}

class _KeepBranchState extends State<_KeepBranch>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _AccessNotice extends StatelessWidget {
  const _AccessNotice({required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surfaceHigh,
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: context.colors.subtitle),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ?action,
          ],
        ),
      ),
    ),
  );
}
