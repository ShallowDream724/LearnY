// Home Screen — Smart aggregation of urgent items.
//
// Sections:
// 1. Greeting + Stats bar (courses, pending, unread)
// 2. Urgent assignments (deadline timeline)
// 3. Unread notifications
// 4. Quick actions
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_models.dart';
import '../../core/sync/sync_actions.dart';
import 'providers/home_providers.dart';
import 'providers/home_schedule_provider.dart';
import 'widgets/home_sections.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _hasBootstrappedHome = false;
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
    final syncState = (await ref.read(syncActionsProvider).refreshAll()).state;
    ref.invalidate(homeScheduleSnapshotProvider);
    if (!mounted) return;
    if (syncState.status == SyncStatus.success) {
      final msg = syncState.syncWarnings.isNotEmpty
          ? '同步完成（${syncState.updatedCount} 项），'
                '${syncState.syncWarnings.length} 个课程部分失败'
          : '同步完成，更新了 ${syncState.updatedCount} 项';
      AppToast.showSuccess(
        context,
        message: msg,
        duration: const Duration(milliseconds: 2600),
      );
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

      if (_hasBootstrappedHome || !next.hasValue) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasBootstrappedHome) {
          setState(() => _hasBootstrappedHome = true);
        }
      });
    });

    final c = context.colors;
    final authState = ref.watch(authProvider);
    final homeAsync = _hasBootstrappedHome ? null : ref.watch(homeDataProvider);

    Future<void> scrollToNotificationsSection() async {
      final targetContext = _notificationsSectionKey.currentContext;
      if (targetContext == null) {
        return;
      }
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          key: const PageStorageKey('home_scroll_view'),
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                  ),
                  Text(
                    authState.username ?? 'LearnY',
                    style: AppTypography.headlineSmall.copyWith(color: c.text),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {
                    context.push('/search');
                  },
                ),
              ],
            ),
            if (!_hasBootstrappedHome)
              homeAsync!.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const SliverFillRemaining(child: ListSkeleton()),
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
                  notificationsSectionKey: _notificationsSectionKey,
                  onUnreadStatTap: scrollToNotificationsSection,
                  onBeforeNotificationSwipeRead: preserveViewport,
                ),
              )
            else
              _HomeContentSliver(
                notificationsSectionKey: _notificationsSectionKey,
                onUnreadStatTap: scrollToNotificationsSection,
                onBeforeNotificationSwipeRead: preserveViewport,
              ),
          ],
        ),
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
    required this.notificationsSectionKey,
    required this.onUnreadStatTap,
    required this.onBeforeNotificationSwipeRead,
  });

  final GlobalKey notificationsSectionKey;
  final VoidCallback onUnreadStatTap;
  final VoidCallback onBeforeNotificationSwipeRead;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          HomeStatsSection(onUnreadTap: onUnreadStatTap),
          const SizedBox(height: 20),
          const HomeTodayScheduleSection(),
          const HomeUrgentAssignmentsSection(),
          HomeUnreadNotificationsSection(
            key: notificationsSectionKey,
            onBeforeSwipeRead: onBeforeNotificationSwipeRead,
          ),
          const HomeUnreadFilesSection(),
          const HomeEmptyStateSection(),
        ]),
      ),
    );
  }
}
