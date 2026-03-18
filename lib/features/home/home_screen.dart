/// Home Screen — Smart aggregation of urgent items.
///
/// Sections:
/// 1. Greeting + Stats bar (courses, pending, unread)
/// 2. Urgent assignments (deadline timeline)
/// 3. Unread notifications
/// 4. Quick actions
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
import 'widgets/stat_card.dart';
import 'widgets/deadline_card.dart';
import 'widgets/notification_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Trigger initial sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncStateProvider.notifier).syncAll();
    });
  }

  Future<void> _onRefresh() async {
    await ref.read(syncStateProvider.notifier).syncAll();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subtitleColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final authState = ref.watch(authProvider);
    final syncState = ref.watch(syncStateProvider);
    final homeAsync = ref.watch(homeDataProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── App Bar ──
            SliverAppBar(
              floating: true,
              snap: true,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _greeting(),
                    style: AppTypography.bodySmall.copyWith(
                      color: subtitleColor,
                    ),
                  ),
                  Text(
                    authState.username ?? 'LearnY',
                    style: AppTypography.headlineSmall.copyWith(
                      color: textColor,
                    ),
                  ),
                ],
              ),
              actions: [
                // Sync indicator
                if (syncState.status == SyncStatus.syncing)
                  const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: () {
                    context.push('/search');
                  },
                ),
              ],
            ),

            // ── Content ──
            homeAsync.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: subtitleColor),
                      const SizedBox(height: 12),
                      Text('加载失败',
                          style: AppTypography.titleMedium
                              .copyWith(color: textColor)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _onRefresh,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (data) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Stats Row ──
                    _buildStatsRow(data, isDark),
                    const SizedBox(height: 24),

                    // ── Urgent Assignments ──
                    if (data.urgentAssignments.isNotEmpty) ...[
                      _SectionTitle(
                        title: '紧急作业',
                        count: data.pendingAssignments,
                        color: AppColors.deadlineUrgent,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      ...data.urgentAssignments.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: DeadlineCard(hw: e.value)
                                  .animate(delay: (100 * e.key).ms)
                                  .fadeIn(duration: 300.ms)
                                  .slideX(begin: 0.05, end: 0),
                            ),
                          ),
                      const SizedBox(height: 16),
                    ],

                    // ── Unread Notifications ──
                    if (data.unreadNotifications.isNotEmpty) ...[
                      _SectionTitle(
                        title: '未读通知',
                        count: data.unreadCount,
                        color: AppColors.info,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      ...data.unreadNotifications.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: NotificationCard(notification: e.value)
                                  .animate(delay: (100 * e.key).ms)
                                  .fadeIn(duration: 300.ms)
                                  .slideX(begin: 0.05, end: 0),
                            ),
                          ),
                      const SizedBox(height: 16),
                    ],

                    // ── Empty state ──
                    if (data.urgentAssignments.isEmpty &&
                        data.unreadNotifications.isEmpty)
                      _buildEmptyState(isDark),
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(HomeData data, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: '课程',
            value: data.totalCourses.toString(),
            icon: Icons.school_rounded,
            color: AppColors.primary,
            isDark: isDark,
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: '待交',
            value: data.pendingAssignments.toString(),
            icon: Icons.assignment_late_rounded,
            color: data.pendingAssignments > 0
                ? AppColors.warning
                : AppColors.success,
            isDark: isDark,
          )
              .animate(delay: 100.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatCard(
            label: '未读',
            value: data.unreadCount.toString(),
            icon: Icons.notifications_none_rounded,
            color: data.unreadCount > 0
                ? AppColors.unreadBadge
                : AppColors.success,
            isDark: isDark,
          )
              .animate(delay: 200.ms)
              .fadeIn(duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final color =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 56, color: color),
            const SizedBox(height: 16),
            Text(
              '一切完成',
              style: AppTypography.headlineSmall.copyWith(color: color),
            ),
            const SizedBox(height: 4),
            Text(
              '没有紧急事项',
              style: AppTypography.bodyMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 500.ms);
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '深夜了';
    if (hour < 9) return '早上好';
    if (hour < 12) return '上午好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    if (hour < 22) return '晚上好';
    return '夜深了';
  }
}

// ─────────────────────────────────────────────
//  Section Title
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final bool isDark;

  const _SectionTitle({
    required this.title,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.headlineSmall.copyWith(color: textColor)),
        const Spacer(),
        Text(
          '$count 项',
          style: AppTypography.bodySmall.copyWith(color: subColor),
        ),
      ],
    );
  }
}
