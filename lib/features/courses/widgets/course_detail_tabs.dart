import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/cooldown_toast.dart';
import '../../../core/design/shimmer.dart';
import '../../../core/design/swipe_to_read.dart';
import '../../../core/design/typography.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/files/file_models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_models.dart';
import '../../../core/router/router.dart';
import '../../../core/sync/sync_actions.dart';
import '../../../core/utils/deadline_time.dart';
import '../../../core/utils/notification_read_state.dart';
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

    return notifAsync.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: c.tertiary),
              const SizedBox(height: 10),
              Text(
                '加载失败',
                style: AppTypography.bodyMedium.copyWith(color: c.text),
              ),
            ],
          ),
        ),
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _onRefresh(context, ref),
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 120),
              children: const [
                _CourseEmptyState(
                  icon: Icons.notifications_none_rounded,
                  label: '暂无通知',
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => _onRefresh(context, ref),
          color: AppColors.primary,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              final isRead = notification.isEffectivelyRead;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(
                      Routes.notificationDetail(
                        notificationId: notification.id,
                        courseId: courseId,
                        courseName: courseName,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isRead)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 10),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: notification.markedImportant
                                      ? AppColors.warning
                                      : AppColors.info,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              color: isRead
                                                  ? c.subtitle
                                                  : c.text,
                                              fontWeight: isRead
                                                  ? FontWeight.w400
                                                  : FontWeight.w600,
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (notification.markedImportant)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withAlpha(
                                            20,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          '重要',
                                          style: AppTypography.labelSmall
                                              .copyWith(
                                                color: AppColors.warning,
                                                fontSize: 10,
                                              ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    if (notification.publisher.isNotEmpty) ...[
                                      Text(
                                        notification.publisher,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: c.tertiary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Text(
                                      _formatTime(notification.publishTime),
                                      style: AppTypography.bodySmall.copyWith(
                                        color: c.tertiary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate(delay: (40 * index).ms).fadeIn(duration: 200.ms);
            },
          ),
        );
      },
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
    final c = context.colors;
    final filesAsync = ref.watch(courseFilesProvider(widget.courseId));
    final favoriteKeys =
        ref.watch(bookmarkedAssetKeysProvider).valueOrNull ?? {};
    final actions = ref.read(learningDataActionsProvider);

    return filesAsync.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: c.tertiary),
              const SizedBox(height: 10),
              Text(
                '加载失败',
                style: AppTypography.bodyMedium.copyWith(color: c.text),
              ),
            ],
          ),
        ),
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
          color: AppColors.primary,
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
                                .where((file) => favoriteKeys.contains(file.id))
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
                child: files.isEmpty
                    ? ListView(
                        children: [
                          SizedBox(height: 120),
                          _CourseEmptyState(
                            icon: _filter == CourseFileFilter.all
                                ? Icons.folder_open_rounded
                                : Icons.filter_list_off_rounded,
                            label: _buildEmptyStateLabel(),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          final isFavorite = favoriteKeys.contains(file.id);
                          return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: SwipeToRead(
                                  isRead: !file.isNew,
                                  onSwipe: () {
                                    if (file.isNew) {
                                      actions.markFileRead(file.id);
                                    } else {
                                      actions.markFileUnread(file.id);
                                    }
                                  },
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
                              )
                              .animate(delay: (40 * index).ms)
                              .fadeIn(duration: 200.ms);
                        },
                      ),
              ),
            ],
          ),
        );
      },
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
    final c = context.colors;
    final homeworksAsync = ref.watch(courseHomeworksProvider(courseId));

    return homeworksAsync.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: c.tertiary),
              const SizedBox(height: 10),
              Text(
                '加载失败',
                style: AppTypography.bodyMedium.copyWith(color: c.text),
              ),
            ],
          ),
        ),
      ),
      data: (homeworks) {
        if (homeworks.isEmpty) {
          return RefreshIndicator(
            onRefresh: () => _onRefresh(context, ref),
            color: AppColors.primary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 120),
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
          color: AppColors.primary,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: homeworks.length,
            itemBuilder: (context, index) {
              final homework = homeworks[index];
              final statusColor = _statusColor(homework);
              final statusText = _statusText(homework);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => context.push(
                      Routes.homeworkDetail(
                        homeworkId: homework.id,
                        courseId: courseId,
                        courseName: courseName,
                      ),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  homework.title,
                                  style: AppTypography.titleMedium.copyWith(
                                    color: c.text,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusText,
                                  style: AppTypography.labelSmall.copyWith(
                                    color: statusColor,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 14,
                                color: c.tertiary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDeadline(homework.deadline),
                                style: AppTypography.bodySmall.copyWith(
                                  color: c.tertiary,
                                ),
                              ),
                              if (homework.graded &&
                                  homework.grade != null) ...[
                                const Spacer(),
                                Text(
                                  '${homework.grade}',
                                  style: AppTypography.titleSmall.copyWith(
                                    color: _gradeColor(homework.grade!),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate(delay: (40 * index).ms).fadeIn(duration: 200.ms),
              );
            },
          ),
        );
      },
    );
  }

  Color _statusColor(db.Homework homework) {
    if (homework.graded) return AppColors.success;
    if (homework.submitted) return AppColors.info;
    final deadline = tryParseEpochMillisToLocal(homework.deadline);
    if (deadline != null && deadline.isBefore(nowInShanghai())) {
      return AppColors.error;
    }
    return AppColors.warning;
  }

  String _statusText(db.Homework homework) {
    if (homework.graded) return '已批改';
    if (homework.submitted) return '已提交';
    final deadline = tryParseEpochMillisToLocal(homework.deadline);
    if (deadline != null && deadline.isBefore(nowInShanghai())) {
      return '已超期';
    }
    return '待提交';
  }

  String _formatDeadline(String deadline) {
    final d = tryParseEpochMillisToLocal(deadline);
    if (d == null) return deadline;
    return '${d.month}/${d.day} '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  Color _gradeColor(double grade) {
    if (grade >= 90) return AppColors.gradeExcellent;
    if (grade >= 80) return AppColors.gradeGood;
    if (grade >= 70) return AppColors.gradeAverage;
    if (grade >= 60) return AppColors.gradePoor;
    return AppColors.gradeFail;
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
    final activeColor = AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withAlpha(c.isDark ? 40 : 25)
              : c.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: activeColor.withAlpha(80), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? activeColor : c.subtitle,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? activeColor : c.subtitle.withAlpha(128),
                ),
              ),
            ],
          ],
        ),
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
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: c.tertiary),
          const SizedBox(height: 12),
          Text(
            label,
            style: AppTypography.titleMedium.copyWith(color: c.tertiary),
          ),
        ],
      ),
    );
  }
}
