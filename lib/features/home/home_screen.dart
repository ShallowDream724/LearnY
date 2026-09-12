// Daily arrangement and actionable coursework share a single reading rhythm.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/design/responsive.dart';
import '../../core/design/app_light_scene.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_models.dart';
import '../../core/shell/shell_layout_metrics.dart';
import '../../core/semester/semester_switcher.dart';
import '../../core/router/router.dart';
import 'providers/home_providers.dart';
import 'providers/home_schedule_provider.dart';
import 'widgets/home_sections.dart';
import 'widgets/home_schedule_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _notificationsSectionKey = GlobalKey();
  double? _pendingViewportOffset;

  @override
  void initState() {
    super.initState();
    // Sync is triggered by main.dart on auth state change.
    // No need to duplicate here.
  }

  Future<void> _onRefresh() async {
    final result = await ref.read(homeRefreshActionsProvider).refresh();
    if (!mounted || !result.isCurrent) return;
    final syncState = result.syncState;
    final scheduleRefreshed = result.scheduleRefreshed;
    if (syncState.status == SyncStatus.success) {
      if (syncState.syncWarnings.isEmpty && scheduleRefreshed) {
        AppToast.showSuccess(
          context,
          message: '同步完成，更新了 ${syncState.updatedCount} 项',
          duration: const Duration(milliseconds: 2600),
        );
      } else {
        final warnings = <String>[
          if (syncState.syncWarnings.isNotEmpty)
            '${syncState.syncWarnings.length} 个课程部分失败',
          if (!scheduleRefreshed) '课表刷新失败',
        ];
        AppToast.showWarning(
          context,
          message: '已更新 ${syncState.updatedCount} 项；${warnings.join('，')}',
          duration: const Duration(milliseconds: 3400),
          actionLabel: '重试',
          onAction: _onRefresh,
        );
      }
    } else if (syncState.status == SyncStatus.sessionExpired) {
      AppToast.showWarning(
        context,
        message: '会话已过期，可继续查看缓存数据',
        duration: const Duration(milliseconds: 2600),
      );
    } else if (syncState.status == SyncStatus.cooldown) {
      CooldownToast.show(context, seconds: syncState.cooldownSeconds);
    } else if (syncState.status == SyncStatus.error) {
      AppToast.showError(
        context,
        message: '同步失败: ${syncState.errorMessage ?? "未知错误"}',
        duration: const Duration(milliseconds: 3400),
        actionLabel: '重试',
        onAction: _onRefresh,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<HomeData>>(homeDataProvider, (previous, next) {
      if (_pendingViewportOffset != null && next.hasValue) {
        final targetOffset = _pendingViewportOffset!;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final maxScroll = _scrollController.position.maxScrollExtent;
          final clampedOffset = targetOffset.clamp(0.0, maxScroll);
          if ((_scrollController.offset - clampedOffset).abs() > 0.5) {
            _scrollController.jumpTo(clampedOffset);
          }
          _pendingViewportOffset = null;
        });
      }
    });

    final c = context.colors;
    final authState = ref.watch(authProvider);
    final homeAsync = ref.watch(homeDataProvider);
    ref.listen(currentSemesterIdProvider, (previous, next) {
      if (previous != next) {
        _pendingViewportOffset = null;
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
    });

    Future<void> scrollToNotificationsSection() async {
      final targetContext = _notificationsSectionKey.currentContext;
      if (targetContext == null) {
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: AppMotion.duration(context),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = pageGutterForWidth(constraints.maxWidth);
          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary,
            child: CustomScrollView(
              key: const PageStorageKey('home_scroll_view'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: const StudyLightSurface(),
                  toolbarHeight: semesterToolbarHeight(context),
                  titleSpacing: gutter,
                  title: SemesterPageTitle(
                    title: '${_greeting()}，${authState.username ?? "LearnY"}',
                  ),
                  actions: [
                    IconButton(
                      tooltip: '课程文件',
                      icon: const Icon(Icons.folder_open_outlined),
                      onPressed: () => context.push(Routes.files),
                    ),
                    IconButton(
                      tooltip: '搜索',
                      icon: const Icon(Icons.search_rounded),
                      onPressed: () {
                        context.push('/search');
                      },
                    ),
                    if (!shouldShowRail(context))
                      SemesterSyncControl(
                        onRefresh: _onRefresh,
                        refreshTooltip: '刷新全部内容和课表',
                      ),
                    SizedBox(width: gutter - 8),
                  ],
                ),
                homeAsync.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () =>
                      const SliverFillRemaining(child: ListSkeleton()),
                  error: (error, _) => SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 48,
                            color: c.subtitle,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '加载失败',
                            style: AppTypography.titleMedium.copyWith(
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _onRefresh,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (_) => _HomeContentSliver(
                    gutter: gutter,
                    notificationsSectionKey: _notificationsSectionKey,
                    onUnreadStatTap: scrollToNotificationsSection,
                    onBeforeNotificationSwipeRead: preserveViewport,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _greeting() {
    // Always use Shanghai time (UTC+8)
    final hour = DateTime.now().toUtc().add(const Duration(hours: 8)).hour;
    if (hour < 6) return '深夜了';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }

  void preserveViewport() {
    if (!_scrollController.hasClients) return;
    _pendingViewportOffset = _scrollController.offset;
  }
}

class _HomeContentSliver extends StatelessWidget {
  const _HomeContentSliver({
    required this.gutter,
    required this.notificationsSectionKey,
    required this.onUnreadStatTap,
    required this.onBeforeNotificationSwipeRead,
  });

  final GlobalKey notificationsSectionKey;
  final double gutter;
  final VoidCallback onUnreadStatTap;
  final VoidCallback onBeforeNotificationSwipeRead;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        8,
        gutter,
        shellContentBottomInset(context),
      ),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          HomeStatsSection(onUnreadTap: onUnreadStatTap),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final updates = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HomeUnreadNotificationsSection(
                    key: notificationsSectionKey,
                    onBeforeSwipeRead: onBeforeNotificationSwipeRead,
                  ),
                  const HomeUnreadFilesSection(),
                ],
              );
              if (constraints.maxWidth < 840) {
                return Column(
                  children: [
                    const HomeTodayScheduleSection(),
                    const HomeUrgentAssignmentsSection(),
                    updates,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    flex: 5,
                    child: Column(
                      children: [
                        HomeTodayScheduleSection(),
                        HomeUrgentAssignmentsSection(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 3, child: updates),
                ],
              );
            },
          ),
        ]),
      ),
    );
  }
}
