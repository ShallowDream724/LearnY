import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_toast.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/file_type_utils.dart';
import '../../../core/design/homework_reminder_menu.dart';
import '../../../core/design/swipe_to_read.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_models.dart';
import '../../../core/router/router.dart';
import '../../files/providers/file_bookmark_providers.dart';
import '../providers/home_providers.dart';
import 'notification_card.dart';
import 'stat_card.dart';
import 'urgent_deadline_banner.dart';

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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
        Text(title, style: AppTypography.headlineSmall.copyWith(color: c.text)),
        const Spacer(),
        if (count > 0)
          Text(
            '$count 项',
            style: AppTypography.bodySmall.copyWith(color: c.tertiary),
          ),
      ],
    );
  }
}

class HomeStatsSection extends ConsumerWidget {
  const HomeStatsSection({super.key, this.onUnreadTap});

  final VoidCallback? onUnreadTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(
      homeDataProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.totalCourses,
                async.valueOrNull!.pendingAssignments,
                async.valueOrNull!.unreadCount,
              ),
      ),
    );
    final favoriteCount =
        ref.watch(bookmarkedFileCountProvider).valueOrNull ?? 0;

    if (stats == null) return const SizedBox.shrink();

    final (totalCourses, pendingAssignments, unreadCount) = stats;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: '课程',
            value: totalCourses.toString(),
            icon: Icons.school_rounded,
            color: AppColors.primary,
            onTap: () => context.go(Routes.courses),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '待交',
            value: pendingAssignments.toString(),
            icon: Icons.assignment_late_rounded,
            color: pendingAssignments > 0
                ? AppColors.warning
                : AppColors.success,
            onTap: () => context.go(Routes.assignments),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '未读',
            value: unreadCount.toString(),
            icon: Icons.notifications_none_rounded,
            color: unreadCount > 0 ? AppColors.unreadBadge : AppColors.success,
            onTap: onUnreadTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '收藏',
            value: favoriteCount.toString(),
            icon: Icons.bookmark_rounded,
            color: AppColors.warning,
            onTap: () => context.push(Routes.favoriteFiles),
          ),
        ),
      ],
    );
  }
}

class HomeUrgentAssignmentsSection extends ConsumerWidget {
  const HomeUrgentAssignmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deadlineData = ref.watch(
      homeDataProvider.select((async) {
        final data = async.valueOrNull;
        if (data == null) {
          return null;
        }
        return (data.urgentAssignments, data.pendingAssignments);
      }),
    );

    if (deadlineData == null) {
      return const SizedBox.shrink();
    }

    final (assignments, pendingAssignments) = deadlineData;

    return Column(
      children: [
        UrgentDeadlineBanner(
          assignments: assignments,
          pendingAssignments: pendingAssignments,
          onTap: (hw) => context.push(
            Routes.homeworkDetail(
              homeworkId: hw.id,
              courseId: hw.courseId,
              courseName: hw.courseName,
            ),
          ),
          onLongPress: (hw, anchor) async {
            final action = await showHomeworkReminderMenu(
              context,
              title: hw.title,
              courseName: hw.courseName,
              isNoSubmissionNeeded: false,
              anchor: anchor,
            );
            if (!context.mounted || action == null) {
              return;
            }

            await ref
                .read(homeworkReminderActionsProvider)
                .setNoSubmissionNeeded(
                  hw.id,
                  noSubmissionNeeded:
                      action ==
                      HomeworkReminderMenuAction.markNoSubmissionNeeded,
                );
            if (!context.mounted) {
              return;
            }

            AppToast.showInfo(
              context,
              message: '已设为无需提交',
              actionLabel: '撤销',
              onAction: () {
                unawaited(
                  ref
                      .read(homeworkReminderActionsProvider)
                      .setNoSubmissionNeeded(hw.id, noSubmissionNeeded: false),
                );
              },
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class HomeUnreadNotificationsSection extends ConsumerWidget {
  const HomeUnreadNotificationsSection({super.key, this.onBeforeSwipeRead});

  final VoidCallback? onBeforeSwipeRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      homeDataProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.unreadNotifications,
                async.valueOrNull!.unreadCount,
              ),
      ),
    );

    if (data == null) return const SizedBox.shrink();

    final actions = ref.read(learningDataActionsProvider);
    final (notifications, unreadCount) = data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: '未读通知',
          count: unreadCount,
          color: AppColors.info,
        ),
        const SizedBox(height: 12),
        if (notifications.isNotEmpty)
          ...notifications.map(
            (notification) => KeyedSubtree(
              key: ValueKey('home_notification_${notification.id}'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SwipeToRead(
                  key: ValueKey(notification.id),
                  exitOnSwipe: true,
                  onSwipe: () {
                    onBeforeSwipeRead?.call();
                    actions.markNotificationRead(notification.id);
                  },
                  child: NotificationCard(
                    notification: notification,
                    onTap: () {
                      actions.markNotificationRead(notification.id);
                      context.push(
                        Routes.notificationDetail(
                          notificationId: notification.id,
                          courseId: notification.courseId,
                          courseName: notification.courseName,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
              final c = context.colors;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '暂无未读通知',
                  style: AppTypography.bodyMedium.copyWith(color: c.tertiary),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class HomeUnreadFilesSection extends ConsumerStatefulWidget {
  const HomeUnreadFilesSection({super.key});

  @override
  ConsumerState<HomeUnreadFilesSection> createState() =>
      _HomeUnreadFilesSectionState();
}

class _HomeUnreadFilesSectionState
    extends ConsumerState<HomeUnreadFilesSection> {
  final Set<String> _optimisticallyReadIds = <String>{};

  Future<void> _markFileReadOptimistically(FileSummary file) async {
    if (_optimisticallyReadIds.contains(file.id)) return;

    setState(() {
      _optimisticallyReadIds.add(file.id);
    });

    try {
      await ref.read(learningDataActionsProvider).markFileRead(file.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _optimisticallyReadIds.remove(file.id);
      });
      AppToast.showError(
        context,
        message: '标记文件已读失败',
        duration: const Duration(milliseconds: 2600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(
      homeDataProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.newFiles,
                async.valueOrNull!.totalUnreadFiles,
              ),
      ),
    );

    if (data == null) return const SizedBox.shrink();

    final (allFiles, totalUnreadFiles) = data;
    final visibleFiles = <FileSummary>[];
    var optimisticUnreadReduction = 0;

    for (final file in allFiles) {
      if (_optimisticallyReadIds.contains(file.id)) {
        optimisticUnreadReduction++;
        continue;
      }
      if (visibleFiles.length < 5) {
        visibleFiles.add(file);
      }
    }

    final effectiveTotalUnreadFiles =
        (totalUnreadFiles - optimisticUnreadReduction).clamp(
          0,
          totalUnreadFiles,
        );

    if (visibleFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: HomeSectionTitle(
                title: '未读文件',
                count: effectiveTotalUnreadFiles > 5
                    ? 0
                    : effectiveTotalUnreadFiles,
                color: const Color(0xFF7B1FA2),
              ),
            ),
            if (effectiveTotalUnreadFiles > 5) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.push(Routes.unreadFiles),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看全部($effectiveTotalUnreadFiles)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
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
        ...visibleFiles.map(
          (file) => KeyedSubtree(
            key: ValueKey('home_file_${file.id}'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SwipeToRead(
                key: ValueKey(file.id),
                exitOnSwipe: false,
                onSwipe: () {
                  unawaited(_markFileReadOptimistically(file));
                },
                child: HomeNewFileCard(
                  file: file,
                  onTap: () {
                    context.push(
                      Routes.fileDetail(
                        fileId: file.id,
                        courseId: file.courseId,
                        courseName: file.courseName,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class HomeNewFileCard extends StatelessWidget {
  const HomeNewFileCard({super.key, required this.file, this.onTap});

  final FileSummary file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ext = FileTypeUtils.extractExt(file.title, file.fileType);
    final color = FileTypeUtils.color(ext);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 0.5),
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
              child: Icon(FileTypeUtils.icon(ext), color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    style: AppTypography.titleMedium.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.courseName,
                    style: AppTypography.bodySmall.copyWith(
                      color: c.tertiary,
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
                  style: TextStyle(fontSize: 10, color: c.subtitle),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: c.tertiary),
          ],
        ),
      ),
    );
  }
}
