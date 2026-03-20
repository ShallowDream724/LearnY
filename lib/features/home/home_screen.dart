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
import '../../core/design/cooldown_toast.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/swipe_to_read.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/router/router.dart';
import 'widgets/stat_card.dart';
import 'widgets/urgent_deadline_banner.dart';
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
    // Sync is triggered by main.dart on auth state change.
    // No need to duplicate here.
  }

  Future<void> _onRefresh() async {
    await ref.read(syncStateProvider.notifier).syncAll();
    if (!mounted) return;

    final syncState = ref.read(syncStateProvider);
    if (syncState.status == SyncStatus.success) {
      final msg = syncState.syncWarnings.isNotEmpty
          ? '同步完成（${syncState.updatedCount} 项），'
            '${syncState.syncWarnings.length} 个课程部分失败'
          : '同步完成，更新了 ${syncState.updatedCount} 项';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (syncState.status == SyncStatus.sessionExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('会话过期，请重新登录'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warning,
          action: SnackBarAction(
            label: '登录',
            textColor: Colors.white,
            onPressed: () {
              // Must logout first to clear stale auth state,
              // otherwise router redirect blocks navigation to login.
              ref.read(authProvider.notifier).logout();
            },
          ),
        ),
      );
    } else if (syncState.status == SyncStatus.cooldown) {
      CooldownToast.show(context, seconds: syncState.cooldownSeconds);
    } else if (syncState.status == SyncStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步失败: ${syncState.errorMessage ?? "未知错误"}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          action: SnackBarAction(
            label: '重试',
            textColor: Colors.white,
            onPressed: _onRefresh,
          ),
        ),
      );
    }
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

    // Auto-handle session expiry from ANY sync trigger (auto or manual).
    // When session expires, clear stale state and redirect to login.
    ref.listen(syncStateProvider, (prev, next) {
      if (next.status == SyncStatus.sessionExpired) {
        ref.read(authProvider.notifier).logout();
      }
    });

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
                child: ListSkeleton(),
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
                      UrgentDeadlineBanner(
                        assignments: data.urgentAssignments,
                        onTap: (hw) => context.push(
                          Routes.homeworkDetail(
                            homeworkId: hw.id,
                            courseId: hw.courseId,
                            courseName: hw.courseName,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Unread Notifications ──
                    _SectionTitle(
                      title: '未读通知',
                      count: data.unreadCount,
                      color: AppColors.info,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 12),
                    if (data.unreadNotifications.isNotEmpty)
                      ...data.unreadNotifications.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: SwipeToRead(
                                key: ValueKey(e.value.id),
                                exitOnSwipe: true,
                                onSwipe: () {
                                  ref.read(databaseProvider)
                                      .markNotificationReadLocal(e.value.id);
                                  ref.invalidate(homeDataProvider);
                                },
                                child: NotificationCard(
                                  notification: e.value,
                                  onTap: () {
                                    ref.read(databaseProvider)
                                        .markNotificationReadLocal(e.value.id);
                                    ref.invalidate(homeDataProvider);
                                    context.push(
                                      Routes.notificationDetail(
                                        notificationId: e.value.id,
                                        courseId: e.value.courseId,
                                        courseName: e.value.courseName,
                                      ),
                                    );
                                  },
                                ),
                              )
                                  .animate(delay: (100 * e.key).ms)
                                  .fadeIn(duration: 300.ms)
                                  .slideX(begin: 0.05, end: 0),
                            ),
                          )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '暂无未读通知',
                          style: AppTypography.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // ── Unread Files ──
                    if (data.newFiles.isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _SectionTitle(
                              title: '未读文件',
                              count: data.totalUnreadFiles > 5 ? 0 : data.totalUnreadFiles,
                              color: const Color(0xFF7B1FA2),
                              isDark: isDark,
                            ),
                          ),
                          if (data.totalUnreadFiles > 5) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () => context.push(Routes.unreadFiles),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '查看全部(${data.totalUnreadFiles})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...data.newFiles.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: SwipeToRead(
                                key: ValueKey(e.value.id),
                                exitOnSwipe: true,
                                onSwipe: () {
                                  ref.read(databaseProvider)
                                      .markFileRead(e.value.id);
                                  ref.invalidate(homeDataProvider);
                                },
                                child: _NewFileCard(
                                  file: e.value,
                                  isDark: isDark,
                                  onTap: () {
                                    context.push(
                                      Routes.fileDetail(
                                        fileId: e.value.id,
                                        courseId: e.value.courseId,
                                        courseName: e.value.courseName,
                                      ),
                                    );
                                  },
                                ),
                              )
                                  .animate(delay: (80 * e.key).ms)
                                  .fadeIn(duration: 300.ms)
                                  .slideX(begin: 0.05, end: 0),
                            ),
                          ),
                      const SizedBox(height: 16),
                    ],

                    // ── Empty state ──
                    if (data.urgentAssignments.isEmpty &&
                        data.unreadNotifications.isEmpty &&
                        data.newFiles.isEmpty)
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
        if (count > 0)
          Text(
            '$count 项',
            style: AppTypography.bodySmall.copyWith(color: subColor),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  New File Card (home screen)
// ─────────────────────────────────────────────

class _NewFileCard extends StatelessWidget {
  final FileSummary file;
  final bool isDark;
  final VoidCallback? onTap;

  const _NewFileCard({
    required this.file,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final sub =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final ext = file.fileType.toLowerCase();
    final color = _fileTypeColor(ext);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_fileTypeIcon(ext), color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    style: AppTypography.titleMedium.copyWith(color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.courseName,
                    style: AppTypography.bodySmall.copyWith(
                      color: tertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ext.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  file.size.isNotEmpty ? file.size : '',
                  style: TextStyle(fontSize: 10, color: sub),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: tertiary),
          ],
        ),
      ),
    );
  }

  IconData _fileTypeIcon(String ext) {
    switch (ext) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'doc': case 'docx': return Icons.description_rounded;
      case 'ppt': case 'pptx': return Icons.slideshow_rounded;
      case 'xls': case 'xlsx': return Icons.table_chart_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Color _fileTypeColor(String ext) {
    switch (ext) {
      case 'pdf': return const Color(0xFFE53935);
      case 'doc': case 'docx': return const Color(0xFF1976D2);
      case 'ppt': case 'pptx': return const Color(0xFFE65100);
      case 'xls': case 'xlsx': return const Color(0xFF2E7D32);
      default: return const Color(0xFF546E7A);
    }
  }
}
