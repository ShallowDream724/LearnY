import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_materials.dart';
import '../../../core/design/app_toast.dart';
import '../../../core/design/file_type_utils.dart';
import '../../../core/design/homework_reminder_menu.dart';
import '../../../core/design/swipe_to_read.dart';
import '../../../core/design/animated_data_list.dart';
import '../../../core/design/read_action_feedback.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_models.dart';
import '../../../core/router/router.dart';
import '../../assignments/providers/assignments_providers.dart';
import '../../files/providers/file_bookmark_providers.dart';
import '../providers/home_providers.dart';
import 'notification_card.dart';
import 'stat_card.dart';
import 'pending_assignments.dart';

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    required this.count,
    this.action,
  });
  final String title;
  final int count;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: AppTypography.headlineSmall.copyWith(
            color: context.colors.text,
          ),
        ),
      ),
      if (count > 0)
        Text('$count', style: Theme.of(context).textTheme.bodySmall),
      ?action,
    ],
  );
}

class HomeStatsSection extends ConsumerWidget {
  const HomeStatsSection({super.key, this.onUnreadTap});
  final VoidCallback? onUnreadTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(
      homeDataProvider.select(
        (value) => value.valueOrNull == null
            ? null
            : (
                value.valueOrNull!.totalCourses,
                value.valueOrNull!.pendingAssignments,
                value.valueOrNull!.unreadCount,
              ),
      ),
    );
    final favorites = ref.watch(bookmarkedFileCountProvider).valueOrNull ?? 0;
    if (stats == null) return const SizedBox.shrink();
    final (courses, pending, unread) = stats;
    final entries = [
      StatCard(
        label: '课程',
        value: '$courses',
        onTap: () => context.go(Routes.courses),
      ),
      if (pending > 0)
        StatCard(
          label: '待交',
          value: '$pending',
          tone: StudyTone.ochre,
          onTap: () {
            ref.read(homeworkFilterProvider.notifier).state =
                HomeworkFilter.pending;
            context.go(Routes.assignments);
          },
        ),
      if (unread > 0)
        StatCard(
          label: '未读',
          value: '$unread',
          tone: StudyTone.jade,
          onTap: onUnreadTap,
        ),
      if (favorites > 0)
        StatCard(
          label: '收藏',
          value: '$favorites',
          tone: StudyTone.plum,
          onTap: () => context.push(Routes.favoriteFiles),
        ),
    ];
    return Wrap(spacing: 4, runSpacing: 4, children: entries);
  }
}

class HomeUrgentAssignmentsSection extends ConsumerWidget {
  const HomeUrgentAssignmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      homeDataProvider.select(
        (value) => value.valueOrNull == null
            ? null
            : (
                value.valueOrNull!.urgentAssignments,
                value.valueOrNull!.pendingAssignments,
              ),
      ),
    );
    if (data == null) return const SizedBox.shrink();
    final (assignments, pending) = data;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: PendingAssignments(
        assignments: assignments,
        pendingAssignments: pending,
        onTap: (homework) => context.push(
          Routes.homeworkDetail(
            homeworkId: homework.id,
            courseId: homework.courseId,
            courseName: homework.courseName,
          ),
        ),
        onLongPress: (homework, anchor) async {
          final action = await showHomeworkReminderMenu(
            context,
            title: homework.title,
            courseName: homework.courseName,
            isNoSubmissionNeeded: false,
            anchor: anchor,
          );
          if (!context.mounted || action == null) return;
          try {
            await ref
                .read(homeworkReminderActionsProvider)
                .setNoSubmissionNeeded(
                  homework.id,
                  noSubmissionNeeded:
                      action ==
                      HomeworkReminderMenuAction.markNoSubmissionNeeded,
                );
            if (!context.mounted) return;
            AppToast.showInfo(
              context,
              message: '已设为无需提交',
              actionLabel: '撤销',
              onAction: () => unawaited(
                ref
                    .read(homeworkReminderActionsProvider)
                    .setNoSubmissionNeeded(
                      homework.id,
                      noSubmissionNeeded: false,
                    )
                    .catchError((Object _) {
                      if (context.mounted) {
                        AppToast.showError(context, message: '提醒设置未能恢复');
                      }
                    }),
              ),
            );
          } catch (_) {
            if (context.mounted) {
              AppToast.showError(context, message: '提醒设置未能保存');
            }
          }
        },
      ),
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
        (value) => value.valueOrNull == null
            ? null
            : (
                value.valueOrNull!.unreadNotifications,
                value.valueOrNull!.unreadCount,
              ),
      ),
    );
    if (data == null) return const SizedBox.shrink();
    final (notifications, unread) = data;
    final actions = ref.read(learningDataActionsProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: StudySurface(
        padding: const EdgeInsets.all(18),
        child: ReadActionFeedback(
          key: ValueKey(ref.watch(currentSemesterIdProvider)),
          expand: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HomeSectionTitle(title: '未读通知', count: unread),
              const SizedBox(height: 12),
              AnimatedDataList(
                items: notifications,
                itemId: (notification) => notification.id,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                emptyBuilder: (context) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '暂无未读通知',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                itemBuilder: (context, notification) => Padding(
                  key: ValueKey('notification-${notification.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SwipeToRead(
                    actionId: 'notification-${notification.id}',
                    removesOnRead: true,
                    onUndo: () =>
                        actions.markNotificationUnread(notification.id),
                    onSwipe: () async {
                      onBeforeSwipeRead?.call();
                      await actions.markNotificationRead(notification.id);
                    },
                    child: NotificationCard(
                      notification: notification,
                      onTap: () => context.push(
                        Routes.notificationDetail(
                          notificationId: notification.id,
                          courseId: notification.courseId,
                          courseName: notification.courseName,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeUnreadFilesSection extends ConsumerWidget {
  const HomeUnreadFilesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      homeDataProvider.select(
        (value) => value.valueOrNull == null
            ? null
            : (
                value.valueOrNull!.newFiles,
                value.valueOrNull!.totalUnreadFiles,
              ),
      ),
    );
    if (data == null) return const SizedBox.shrink();
    final (files, total) = data;
    final actions = ref.read(learningDataActionsProvider);
    return StudySurface(
      padding: const EdgeInsets.all(18),
      child: ReadActionFeedback(
        key: ValueKey(ref.watch(currentSemesterIdProvider)),
        expand: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HomeSectionTitle(
              title: '未读文件',
              count: total,
              action: total > 5
                  ? IconButton(
                      tooltip: '查看全部未读文件',
                      onPressed: () => context.push(Routes.unreadFiles),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            AnimatedDataList(
              items: files.take(5).toList(),
              itemId: (file) => file.id,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              emptyBuilder: (context) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('暂无未读文件'),
              ),
              itemBuilder: (context, file) => Padding(
                key: ValueKey('file-${file.id}'),
                padding: const EdgeInsets.only(bottom: 8),
                child: SwipeToRead(
                  actionId: 'file-${file.id}',
                  removesOnRead: true,
                  onUndo: () => actions.markFileUnread(file.id),
                  onSwipe: () => actions.markFileRead(file.id),
                  child: HomeNewFileCard(
                    file: file,
                    onTap: () => context.push(
                      Routes.fileDetail(
                        fileId: file.id,
                        courseId: file.courseId,
                        courseName: file.courseName,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                FileTypeUtils.icon(ext),
                color: FileTypeUtils.color(ext),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(color: c.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      file.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                    if (file.size.isNotEmpty)
                      Text(
                        file.size,
                        style: AppTypography.bodySmall.copyWith(
                          color: c.subtitle,
                        ),
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
