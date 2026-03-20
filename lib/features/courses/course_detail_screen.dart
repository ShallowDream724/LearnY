/// Course detail screen — tabbed view of a single course.
///
/// Tabs:
/// 1. 通知 (Notifications) — with read/unread state
/// 2. 文件 (Files) — with download state, file size, search
/// 3. 作业 (Homework) — with status filter
///
/// Design decisions:
/// - Use TabBar instead of BottomNavBar (since we're inside the shell)
/// - SliverAppBar with course name + teacher pinned
/// - Each tab is its own lazy-loaded list
/// - On tablet, notifications + files show side-by-side
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/responsive.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/swipe_to_read.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/database/database.dart' as db;
import '../../core/router/router.dart';
import '../../core/services/file_download_service.dart';
import '../files/widgets/file_card.dart';

// ---------------------------------------------------------------------------
//  Providers scoped to a course (reactive — auto-update on DB writes)
// ---------------------------------------------------------------------------

/// Provides the course ID to child widgets.
final _courseIdProvider = Provider<String>((ref) => throw UnimplementedError());

/// Course data for the detail view.
final _courseDetailProvider = FutureProvider.family<db.Course?, String>(
  (ref, courseId) async {
    final database = ref.watch(databaseProvider);
    final courses = await database.getCoursesBySemester(
      ref.watch(currentSemesterIdProvider) ?? '',
    );
    try {
      return courses.firstWhere((c) => c.id == courseId);
    } catch (_) {
      return null;
    }
  },
);

/// Notifications for this course — reactive, auto-updates on DB writes.
final _courseNotificationsProvider =
    StreamProvider.family<List<db.Notification>, String>(
  (ref, courseId) {
    final database = ref.watch(databaseProvider);
    return database.watchNotificationsByCourse(courseId).map((notifications) {
      // Sort: unread first, then by publish time descending
      notifications.sort((a, b) {
        if (a.hasRead != b.hasRead) return a.hasRead ? 1 : -1;
        return b.publishTime.compareTo(a.publishTime);
      });
      return notifications;
    });
  },
);

/// Files for this course — reactive.
final _courseFilesProvider = StreamProvider.family<List<db.CourseFile>, String>(
  (ref, courseId) {
    final database = ref.watch(databaseProvider);
    return database.watchFilesByCourse(courseId).map((files) {
      files.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
      return files;
    });
  },
);

/// Homeworks for this course — reactive.
final _courseHomeworksProvider = StreamProvider.family<List<db.Homework>, String>(
  (ref, courseId) {
    final database = ref.watch(databaseProvider);
    return database.watchHomeworksByCourse(courseId).map((homeworks) {
      homeworks.sort((a, b) => b.deadline.compareTo(a.deadline));
      return homeworks;
    });
  },
);

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class CourseDetailScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CourseDetailScreen({super.key, required this.courseId});

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final courseAsync = ref.watch(_courseDetailProvider(widget.courseId));

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: ListSkeleton()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 48, color: subColor),
              const SizedBox(height: 12),
              Text('加载失败',
                  style: AppTypography.titleMedium
                      .copyWith(color: subColor)),
              const SizedBox(height: 8),
              Text('请返回重试',
                  style: AppTypography.bodySmall.copyWith(
                      color: subColor.withAlpha(180))),
            ],
          ),
        ),
        data: (course) {
          if (course == null) {
            return Center(
              child: Text('课程未找到',
                  style: AppTypography.titleMedium.copyWith(color: subColor)),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(syncStateProvider.notifier).syncCourse(widget.courseId);
            },
            color: AppColors.primary,
            child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.only(left: 56, bottom: 50, right: 16),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: AppTypography.titleMedium.copyWith(
                          color: textColor,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (course.teacherName.isNotEmpty)
                        Text(
                          course.teacherName,
                          style: AppTypography.bodySmall.copyWith(
                            color: subColor,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary.withAlpha(isDark ? 40 : 30),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: subColor,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: AppTypography.labelLarge,
                  unselectedLabelStyle: AppTypography.labelMedium,
                  tabs: [
                    _buildTab('通知', _courseNotificationsProvider),
                    _buildTab('文件', _courseFilesProvider),
                    _buildTab('作业', _courseHomeworksProvider),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _NotificationsTab(
                  courseId: widget.courseId,
                  courseName: course.name,
                ),
                _FilesTab(courseId: widget.courseId, courseName: course.name),
                _HomeworksTab(
                  courseId: widget.courseId,
                  courseName: course.name,
                ),
              ],
            ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab(String label, dynamic provider) {
    return Tab(text: label);
  }
}

// ---------------------------------------------------------------------------
//  Notifications Tab
// ---------------------------------------------------------------------------

class _NotificationsTab extends ConsumerWidget {
  final String courseId;
  final String courseName;
  const _NotificationsTab({required this.courseId, required this.courseName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final notifAsync = ref.watch(_courseNotificationsProvider(courseId));

    return notifAsync.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 40, color: tertiaryColor),
              const SizedBox(height: 10),
              Text('加载失败',
                  style: AppTypography.bodyMedium
                      .copyWith(color: textColor)),
            ],
          ),
        ),
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return _EmptyState(
              icon: Icons.notifications_none_rounded,
              label: '暂无通知',
              isDark: isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            final n = notifications[index];
            final isRead = n.hasRead || n.hasReadLocal;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(Routes.notificationDetail(
                    notificationId: n.id,
                    courseId: courseId,
                    courseName: courseName,
                  )),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 0.5),
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
                                color: n.markedImportant
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
                                      n.title,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: isRead ? subColor : textColor,
                                        fontWeight:
                                            isRead ? FontWeight.w400 : FontWeight.w600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (n.markedImportant)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '重要',
                                        style: AppTypography.labelSmall.copyWith(
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
                                  if (n.publisher != null &&
                                      n.publisher!.isNotEmpty) ...[
                                    Text(n.publisher!,
                                        style: AppTypography.bodySmall
                                            .copyWith(color: tertiaryColor)),
                                    const SizedBox(width: 12),
                                  ],
                                  Text(
                                    _formatTime(n.publishTime),
                                    style: AppTypography.bodySmall
                                        .copyWith(color: tertiaryColor),
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
            )
                .animate(delay: (40 * index).ms)
                .fadeIn(duration: 200.ms);
          },
        );
      },
    );
  }

  String _formatTime(String publishTime) {
    final ms = int.tryParse(publishTime);
    if (ms == null) return publishTime;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
//  Files Tab
// ---------------------------------------------------------------------------

class _FilesTab extends ConsumerStatefulWidget {
  final String courseId;
  final String courseName;
  const _FilesTab({required this.courseId, required this.courseName});

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

enum _FileFilter { all, unread, favorite, downloaded }

class _FilesTabState extends ConsumerState<_FilesTab> {
  _FileFilter _filter = _FileFilter.all;

  List<db.CourseFile> _applyFilter(List<db.CourseFile> files) {
    switch (_filter) {
      case _FileFilter.all:
        return files;
      case _FileFilter.unread:
        return files.where((f) => f.isNew).toList();
      case _FileFilter.favorite:
        return files.where((f) => f.isFavorite == true).toList();
      case _FileFilter.downloaded:
        return files.where((f) => f.localDownloadState == 'downloaded').toList();
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(syncStateProvider.notifier).syncCourse(widget.courseId);
    if (!mounted) return;
    final ss = ref.read(syncStateProvider);
    if (ss.status == SyncStatus.cooldown) {
      CooldownToast.show(context, seconds: ss.cooldownSeconds);
    }
  }

  void _markAsRead(db.CourseFile file) {
    if (file.isNew) {
      ref.read(databaseProvider).markFileRead(file.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final filesAsync = ref.watch(_courseFilesProvider(widget.courseId));

    return filesAsync.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 40, color: tertiaryColor),
              const SizedBox(height: 10),
              Text('加载失败',
                  style: AppTypography.bodyMedium
                      .copyWith(color: textColor)),
            ],
          ),
        ),
      ),
      data: (allFiles) {
        final files = _applyFilter(allFiles);

        return RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          child: Column(
            children: [
              // ── Filter pills ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: _FileFilter.values.map((filter) {
                    final isActive = _filter == filter;
                    final label = switch (filter) {
                      _FileFilter.all => '全部',
                      _FileFilter.unread => '未读',
                      _FileFilter.favorite => '收藏',
                      _FileFilter.downloaded => '已下载',
                    };
                    // Count for badge
                    final count = switch (filter) {
                      _FileFilter.all => allFiles.length,
                      _FileFilter.unread =>
                        allFiles.where((f) => f.isNew).length,
                      _FileFilter.favorite =>
                        allFiles.where((f) => f.isFavorite == true).length,
                      _FileFilter.downloaded =>
                        allFiles
                            .where(
                                (f) => f.localDownloadState == 'downloaded')
                            .length,
                    };
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterPill(
                        label: label,
                        count: count,
                        isActive: isActive,
                        isDark: isDark,
                        onTap: () => setState(() => _filter = filter),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // ── File list ──
              Expanded(
                child: files.isEmpty
                    ? ListView(
                        // Needed for RefreshIndicator to work on empty
                        children: [
                          SizedBox(height: 120),
                          _EmptyState(
                            icon: _filter == _FileFilter.all
                                ? Icons.folder_open_rounded
                                : Icons.filter_list_off_rounded,
                            label: _filter == _FileFilter.all
                                ? '暂无文件'
                                : '暂无${switch (_filter) {
                                    _FileFilter.unread => '未读',
                                    _FileFilter.favorite => '收藏',
                                    _FileFilter.downloaded => '已下载',
                                    _ => '',
                                  }}文件',
                            isDark: isDark,
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final f = files[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SwipeToRead(
                              isRead: !f.isNew,
                              onSwipe: () {
                                if (f.isNew) {
                                  ref.read(databaseProvider).markFileRead(f.id);
                                } else {
                                  ref.read(databaseProvider).markFileUnread(f.id);
                                }
                                ref.invalidate(homeDataProvider);
                              },
                              child: FileCard(
                                file: f,
                                courseName: widget.courseName,
                                hideCourseName: true,
                                onTap: () {
                                  context.push(Routes.fileDetail(
                                    fileId: f.id,
                                    courseId: widget.courseId,
                                    courseName: widget.courseName,
                                  ));
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
}

/// Filter pill chip for the files tab.
class _FilterPill extends StatelessWidget {
  final String label;
  final int count;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.count,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = AppColors.primary;
    final inactiveText =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final inactiveBg =
        isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? activeColor.withAlpha(isDark ? 40 : 25) : inactiveBg,
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
                color: isActive ? activeColor : inactiveText,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? activeColor
                      : inactiveText.withAlpha(128),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Homeworks Tab
// ---------------------------------------------------------------------------

class _HomeworksTab extends ConsumerWidget {
  final String courseId;
  final String courseName;
  const _HomeworksTab({required this.courseId, required this.courseName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final hwAsync = ref.watch(_courseHomeworksProvider(courseId));

    return hwAsync.when(
      loading: () => const ListSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 40, color: tertiaryColor),
              const SizedBox(height: 10),
              Text('加载失败',
                  style: AppTypography.bodyMedium
                      .copyWith(color: textColor)),
            ],
          ),
        ),
      ),
      data: (homeworks) {
        if (homeworks.isEmpty) {
          return _EmptyState(
              icon: Icons.assignment_outlined,
              label: '暂无作业',
              isDark: isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: homeworks.length,
          itemBuilder: (context, index) {
            final hw = homeworks[index];
            final statusColor = _statusColor(hw);
            final statusText = _statusText(hw);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: surface,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push(Routes.homeworkDetail(
                    homeworkId: hw.id,
                    courseId: courseId,
                    courseName: courseName,
                  )),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + status
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            hw.title,
                            style: AppTypography.titleMedium
                                .copyWith(color: textColor),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(statusText,
                              style: AppTypography.labelSmall.copyWith(
                                color: statusColor,
                                fontSize: 10,
                              )),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Bottom: deadline + grade
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 14, color: tertiaryColor),
                        const SizedBox(width: 4),
                        Text(_formatDeadline(hw.deadline),
                            style: AppTypography.bodySmall
                                .copyWith(color: tertiaryColor)),
                        if (hw.graded && hw.grade != null) ...[
                          const Spacer(),
                          Text('${hw.grade}',
                              style: AppTypography.titleSmall.copyWith(
                                color: _gradeColor(hw.grade!),
                                fontWeight: FontWeight.w700,
                              )),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              ),
              )
                  .animate(delay: (40 * index).ms)
                  .fadeIn(duration: 200.ms),
            );
          },
        );
      },
    );
  }

  Color _statusColor(db.Homework hw) {
    if (hw.graded) return AppColors.success;
    if (hw.submitted) return AppColors.info;
    final ms = int.tryParse(hw.deadline);
    if (ms != null &&
        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now())) {
      return AppColors.error;
    }
    return AppColors.warning;
  }

  String _statusText(db.Homework hw) {
    if (hw.graded) return '已批改';
    if (hw.submitted) return '已提交';
    final ms = int.tryParse(hw.deadline);
    if (ms != null &&
        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now())) {
      return '已超期';
    }
    return '待提交';
  }

  String _formatDeadline(String deadline) {
    final ms = int.tryParse(deadline);
    if (ms == null) return deadline;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _gradeColor(double grade) {
    if (grade >= 90) return AppColors.gradeExcellent;
    if (grade >= 80) return AppColors.gradeGood;
    if (grade >= 70) return AppColors.gradeAverage;
    if (grade >= 60) return AppColors.gradePoor;
    return AppColors.gradeFail;
  }
}

// ---------------------------------------------------------------------------
//  File download button — shows download/progress/success states
// ---------------------------------------------------------------------------

class _FileDownloadButton extends ConsumerWidget {
  final db.CourseFile file;
  final String courseId;
  final Color subColor;

  const _FileDownloadButton({
    required this.file,
    required this.courseId,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadStates = ref.watch(fileDownloadProvider);
    final fileState = downloadStates[file.id];
    final status = fileState?.status ?? 
        (file.localDownloadState == 'downloaded' 
            ? DownloadStatus.downloaded 
            : DownloadStatus.none);
    final progress = fileState?.progress ?? 0.0;

    return SizedBox(
      width: 40,
      height: 40,
      child: switch (status) {
        DownloadStatus.downloading => Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress > 0 ? progress : null,
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
              Text(
                '${(progress * 100).toInt()}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        DownloadStatus.downloaded => IconButton(
            icon: const Icon(Icons.check_circle_rounded,
                color: AppColors.success, size: 22),
            tooltip: '打开文件',
            onPressed: () async {
              final notifier = ref.read(fileDownloadProvider.notifier);
              final opened = await notifier.openFile(file.id);
              if (!opened && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('无法打开文件')),
                );
              }
            },
          ),
        DownloadStatus.failed => IconButton(
            icon: const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 22),
            tooltip: '下载失败，点击重试',
            onPressed: () => _startDownload(ref),
          ),
        _ => IconButton(
            icon: Icon(Icons.download_rounded, color: subColor, size: 22),
            tooltip: '下载',
            onPressed: () => _startDownload(ref),
          ),
      },
    );
  }

  void _startDownload(WidgetRef ref) {
    ref.read(fileDownloadProvider.notifier).downloadFile(
          fileId: file.id,
          courseId: courseId,
          downloadUrl: file.downloadUrl,
          fileName: file.title,
        );
  }
}

// ---------------------------------------------------------------------------
//  Empty state widget
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(label,
              style: AppTypography.titleMedium.copyWith(color: color)),
        ],
      ),
    );
  }
}
