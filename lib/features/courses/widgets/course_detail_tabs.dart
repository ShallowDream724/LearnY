import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_surfaces.dart';
import '../../../core/design/cooldown_toast.dart';
import '../../../core/design/shimmer.dart';
import '../../../core/design/swipe_to_read.dart';
import '../../../core/design/animated_data_list.dart';
import '../../../core/design/read_action_feedback.dart';
import '../../../core/design/typography.dart';
import '../../../core/files/file_models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_models.dart';
import '../../../core/router/router.dart';
import '../../../core/shell/shell_layout_metrics.dart';
import '../../../core/sync/sync_actions.dart';
import '../../../core/utils/deadline_time.dart';
import '../../../core/utils/notification_read_state.dart';
import '../../assignments/homework_reminder_action.dart';
import '../../assignments/widgets/assignment_list_item.dart';
import '../../files/providers/file_bookmark_providers.dart';
import '../../files/widgets/file_card.dart';
import '../../files/widgets/file_type_filter_button.dart';
import '../providers/course_queries.dart';

class CourseNotificationsTab extends ConsumerWidget {
  const CourseNotificationsTab({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  final String courseId;
  final String courseName;

  Future<void> _onRefresh(BuildContext context, WidgetRef ref) async {
    final syncState =
        (await ref.read(syncActionsProvider).refreshCourse(courseId)).state;
    if (!context.mounted) return;
    if (syncState.status == SyncStatus.cooldown) {
      CooldownToast.show(context, seconds: syncState.cooldownSeconds);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final notifAsync = ref.watch(courseNotificationsProvider(courseId));
    final actions = ref.read(learningDataActionsProvider);

    return ReadingWidth(
      child: notifAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => _CourseLoadError(
          onRetry: () => ref.invalidate(courseNotificationsProvider(courseId)),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _onRefresh(context, ref),
              color: context.colors.infoAccent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: shellContentBottomInset(context),
                ),
                children: const [
                  _CourseEmptyState(
                    icon: Icons.notifications_none_rounded,
                    label: '暂无通知',
                  ),
                ],
              ),
            );
          }

          return ReadActionFeedback(
            key: ValueKey(courseId),
            child: RefreshIndicator(
              onRefresh: () => _onRefresh(context, ref),
              color: context.colors.infoAccent,
              child: ListView.builder(
                key: PageStorageKey('course-notifications-$courseId'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  shellContentBottomInset(context, extraSpacing: 16),
                ),
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isRead = notification.isEffectivelyRead;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SwipeToRead(
                      key: ValueKey(notification.id),
                      isRead: isRead,
                      readMenuTitle: notification.title,
                      actionId: 'notification-${notification.id}',
                      onUndo: () => actions.setNotificationReadState(
                        notification.id,
                        isRead: isRead,
                      ),
                      onSwipe: () => actions.setNotificationReadState(
                        notification.id,
                        isRead: !isRead,
                      ),
                      child: StudySurface(
                        tone: isRead
                            ? StudyTone.slate
                            : StudyPalette.course(context, courseId),
                        radius: 16,
                        padding: const EdgeInsets.all(18),
                        onTap: () => context.push(
                          Routes.notificationDetail(
                            notificationId: notification.id,
                            courseId: courseId,
                            courseName: courseName,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    notification.title,
                                    style: AppTypography.titleLarge.copyWith(
                                      color: c.text,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!isRead)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 12,
                                      top: 8,
                                    ),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: c.infoAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                if (notification.markedImportant)
                                  Text(
                                    '重要',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: StudyPalette.of(
                                        context,
                                        StudyTone.ochre,
                                      ).accent,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                if (notification.publisher.isNotEmpty)
                                  Text(
                                    notification.publisher,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: c.subtitle,
                                    ),
                                  ),
                                Text(
                                  _formatTime(notification.publishTime),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: c.subtitle,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String publishTime) {
    final ms = int.tryParse(publishTime);
    if (ms == null) return publishTime;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }
}

class CourseFilesTab extends ConsumerStatefulWidget {
  const CourseFilesTab({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  final String courseId;
  final String courseName;

  @override
  ConsumerState<CourseFilesTab> createState() => _CourseFilesTabState();
}

class _CourseFilesTabState extends ConsumerState<CourseFilesTab> {
  CourseFileFilter _filter = CourseFileFilter.all;
  String? _typeFilter;

  Future<void> _onRefresh() async {
    final syncState =
        (await ref.read(syncActionsProvider).refreshCourse(widget.courseId))
            .state;
    if (!mounted) return;
    if (syncState.status == SyncStatus.cooldown) {
      CooldownToast.show(context, seconds: syncState.cooldownSeconds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filesAsync = ref.watch(courseFilesProvider(widget.courseId));
    final favoriteKeys =
        ref.watch(bookmarkedAssetKeysProvider).valueOrNull ?? {};
    final actions = ref.read(learningDataActionsProvider);

    return ReadingWidth(
      child: filesAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => _CourseLoadError(
          onRetry: () => ref.invalidate(courseFilesProvider(widget.courseId)),
        ),
        data: (allFiles) {
          final presentation = buildCourseFilesPresentation(
            files: allFiles,
            favoriteKeys: favoriteKeys,
            filter: _filter,
            typeFilter: _typeFilter,
          );
          final files = presentation.filteredFiles;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            color: context.colors.infoAccent,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        ...CourseFileFilter.values.map((filter) {
                          final isActive = _filter == filter;
                          final label = switch (filter) {
                            CourseFileFilter.all => '全部',
                            CourseFileFilter.unread => '未读',
                            CourseFileFilter.favorite => '收藏',
                            CourseFileFilter.downloaded => '已下载',
                          };
                          final count = switch (filter) {
                            CourseFileFilter.all => allFiles.length,
                            CourseFileFilter.unread =>
                              allFiles.where((file) => file.isNew).length,
                            CourseFileFilter.favorite =>
                              allFiles
                                  .where(
                                    (file) => favoriteKeys.contains(file.id),
                                  )
                                  .length,
                            CourseFileFilter.downloaded =>
                              allFiles
                                  .where(
                                    (file) =>
                                        file.localDownloadState == 'downloaded',
                                  )
                                  .length,
                          };

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _CourseFileFilterPill(
                              label: label,
                              count: count,
                              isActive: isActive,
                              onTap: () => setState(() => _filter = filter),
                            ),
                          );
                        }),
                        FileTypeFilterButton(
                          currentFilter: _typeFilter,
                          typeCounts: presentation.typeCounts,
                          onChanged: (value) =>
                              setState(() => _typeFilter = value),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ReadActionFeedback(
                    key: ValueKey((widget.courseId, _filter, _typeFilter)),
                    child: AnimatedDataList(
                      items: files,
                      itemId: (file) => file.id,
                      emptyBuilder: (context) => _CourseEmptyState(
                        icon: _filter == CourseFileFilter.all
                            ? Icons.folder_open_rounded
                            : Icons.filter_list_off_rounded,
                        label: _buildEmptyStateLabel(),
                      ),
                      key: PageStorageKey('course-files-${widget.courseId}'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        shellContentBottomInset(context, extraSpacing: 16),
                      ),
                      itemBuilder: (context, file) {
                        final isFavorite = favoriteKeys.contains(file.id);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SwipeToRead(
                            key: ValueKey(file.id),
                            isRead: !file.isNew,
                            actionId: 'file-${file.id}',
                            removesOnRead: _filter == CourseFileFilter.unread,
                            onUndo: () => actions.setFileReadState(
                              file.id,
                              isRead: !file.isNew,
                            ),
                            onSwipe: () => actions.setFileReadState(
                              file.id,
                              isRead: file.isNew,
                            ),
                            child: FileCard(
                              item: FileDetailItem.fromCourseFile(
                                file,
                                courseName: widget.courseName,
                              ),
                              hideCourseName: true,
                              isFavorite: isFavorite,
                              onTap: () {
                                context.push(
                                  Routes.fileDetail(
                                    fileId: file.id,
                                    courseId: widget.courseId,
                                    courseName: widget.courseName,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _buildEmptyStateLabel() {
    if (_filter == CourseFileFilter.all && _typeFilter == null) {
      return '暂无文件';
    }

    final filterLabel = switch (_filter) {
      CourseFileFilter.all => '',
      CourseFileFilter.unread => '未读',
      CourseFileFilter.favorite => '收藏',
      CourseFileFilter.downloaded => '已下载',
    };
    final typeLabel = _typeFilter == null
        ? ''
        : '${_typeFilter!.toUpperCase()} ';
    return '暂无$typeLabel$filterLabel文件';
  }
}

class CourseHomeworksTab extends ConsumerWidget {
  const CourseHomeworksTab({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  final String courseId;
  final String courseName;

  Future<void> _onRefresh(BuildContext context, WidgetRef ref) async {
    final syncState =
        (await ref.read(syncActionsProvider).refreshCourse(courseId)).state;
    if (!context.mounted) return;
    if (syncState.status == SyncStatus.cooldown) {
      CooldownToast.show(context, seconds: syncState.cooldownSeconds);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(minuteTickProvider).valueOrNull ?? nowInShanghai();
    final homeworksAsync = ref.watch(courseHomeworksProvider(courseId));
    final noSubmissionNeededIds =
        ref.watch(homeworkNoSubmissionNeededIdsProvider).valueOrNull ??
        const <String>{};

    return ReadingWidth(
      child: homeworksAsync.when(
        loading: () => const ListSkeleton(),
        error: (e, _) => _CourseLoadError(
          onRetry: () => ref.invalidate(courseHomeworksProvider(courseId)),
        ),
        data: (homeworks) {
          if (homeworks.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _onRefresh(context, ref),
              color: context.colors.infoAccent,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: shellContentBottomInset(context),
                ),
                children: const [
                  _CourseEmptyState(
                    icon: Icons.assignment_outlined,
                    label: '暂无作业',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _onRefresh(context, ref),
            color: context.colors.infoAccent,
            child: ListView.builder(
              key: PageStorageKey('course-homeworks-$courseId'),
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                shellContentBottomInset(context, extraSpacing: 16),
              ),
              itemCount: homeworks.length,
              itemBuilder: (context, index) {
                final homework = homeworks[index];
                final noSubmissionNeeded = noSubmissionNeededIds.contains(
                  homework.id,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AssignmentListItem(
                    homework: homework,
                    courseName: '',
                    now: now,
                    noSubmissionNeeded: noSubmissionNeeded,
                    onTap: () => context.push(
                      Routes.homeworkDetail(
                        homeworkId: homework.id,
                        courseId: courseId,
                        courseName: courseName,
                      ),
                    ),
                    onReminder: (anchor) => showAssignmentReminderAction(
                      context: context,
                      ref: ref,
                      homework: homework,
                      courseName: courseName,
                      noSubmissionNeeded: noSubmissionNeeded,
                      anchor: anchor,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CourseFileFilterPill extends StatelessWidget {
  const _CourseFileFilterPill({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final activeColor = c.infoAccent;

    return ChoiceChip(
      selected: isActive,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive ? activeColor : c.subtitle,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive ? activeColor : c.subtitle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CourseEmptyState extends StatelessWidget {
  const _CourseEmptyState({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(icon: icon, title: label);
  }
}

class _CourseLoadError extends StatelessWidget {
  const _CourseLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppEmptyState(
    icon: Icons.error_outline_rounded,
    title: '加载失败',
    action: OutlinedButton.icon(
      onPressed: onRetry,
      icon: const Icon(Icons.refresh_rounded),
      label: const Text('重试'),
    ),
  );
}
