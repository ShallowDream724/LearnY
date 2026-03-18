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
import '../../core/design/responsive.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/database/database.dart';
import '../../core/router/router.dart';
import '../../core/services/file_download_service.dart';

// ---------------------------------------------------------------------------
//  Providers scoped to a course
// ---------------------------------------------------------------------------

/// Provides the course ID to child widgets.
final _courseIdProvider = Provider<String>((ref) => throw UnimplementedError());

/// Course data for the detail view.
final _courseDetailProvider = FutureProvider.family<Course?, String>(
  (ref, courseId) async {
    final db = ref.watch(databaseProvider);
    final courses = await db.getCoursesBySemester(
      ref.watch(currentSemesterIdProvider) ?? '',
    );
    try {
      return courses.firstWhere((c) => c.id == courseId);
    } catch (_) {
      return null;
    }
  },
);

/// Notifications for this course.
final _courseNotificationsProvider =
    FutureProvider.family<List<Notification>, String>(
  (ref, courseId) async {
    final db = ref.watch(databaseProvider);
    final notifications = await db.getNotificationsByCourse(courseId);
    // Sort: unread first, then by publish time descending
    notifications.sort((a, b) {
      if (a.hasRead != b.hasRead) return a.hasRead ? 1 : -1;
      return b.publishTime.compareTo(a.publishTime);
    });
    return notifications;
  },
);

/// Files for this course.
final _courseFilesProvider = FutureProvider.family<List<CourseFile>, String>(
  (ref, courseId) async {
    final db = ref.watch(databaseProvider);
    final files = await db.getFilesByCourse(courseId);
    // Sort by upload time descending
    files.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    return files;
  },
);

/// Homeworks for this course.
final _courseHomeworksProvider = FutureProvider.family<List<Homework>, String>(
  (ref, courseId) async {
    final db = ref.watch(databaseProvider);
    final homeworks = await db.getHomeworksByCourse(courseId);
    // Sort by deadline descending
    homeworks.sort((a, b) => b.deadline.compareTo(a.deadline));
    return homeworks;
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (course) {
          if (course == null) {
            return Center(
              child: Text('课程未找到',
                  style: AppTypography.titleMedium.copyWith(color: subColor)),
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding:
                      const EdgeInsets.only(left: 56, bottom: 50, right: 16),
                  title: Text(
                    course.name,
                    style: AppTypography.titleMedium.copyWith(
                      color: textColor,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    padding:
                        const EdgeInsets.only(left: 56, top: 40, right: 16),
                    child: SafeArea(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 8),
                          if (course.teacherName != null &&
                              course.teacherName!.isNotEmpty)
                            Text(
                              course.teacherName!,
                              style: AppTypography.bodySmall
                                  .copyWith(color: subColor),
                            ),
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
                _FilesTab(courseId: widget.courseId),
                _HomeworksTab(
                  courseId: widget.courseId,
                  courseName: course.name,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTab(String label, FutureProvider provider) {
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
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
                    // Read/unread dot
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

                    // Content
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

class _FilesTab extends ConsumerWidget {
  final String courseId;
  const _FilesTab({required this.courseId});

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
    final filesAsync = ref.watch(_courseFilesProvider(courseId));

    return filesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (files) {
        if (files.isEmpty) {
          return _EmptyState(
              icon: Icons.folder_open_rounded,
              label: '暂无文件',
              isDark: isDark);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          itemCount: files.length,
          itemBuilder: (context, index) {
            final f = files[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border, width: 0.5),
                ),
                child: Row(
                  children: [
                    // File type icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _fileColor(f.fileType).withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _fileIcon(f.fileType),
                        color: _fileColor(f.fileType),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // File info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  f.title,
                                  style: AppTypography.titleMedium
                                      .copyWith(color: textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (f.isNew)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.info.withAlpha(20),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('NEW',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.info,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                f.size.isNotEmpty ? f.size : '${f.rawSize} B',
                                style: AppTypography.bodySmall
                                    .copyWith(color: tertiaryColor),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatTime(f.uploadTime),
                                style: AppTypography.bodySmall
                                    .copyWith(color: tertiaryColor),
                              ),
                              if (f.markedImportant) ...[
                                const Spacer(),
                                Icon(Icons.star_rounded,
                                    size: 14, color: AppColors.warning),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Download button — real download with progress
                    const SizedBox(width: 8),
                    _FileDownloadButton(
                      file: f,
                      courseId: courseId,
                      subColor: subColor,
                    ),
                  ],
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

  IconData _fileIcon(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.contains('doc') || lower.contains('word'))
      return Icons.description_rounded;
    if (lower.contains('xls') || lower.contains('excel'))
      return Icons.table_chart_rounded;
    if (lower.contains('ppt') || lower.contains('power'))
      return Icons.slideshow_rounded;
    if (lower.contains('zip') || lower.contains('rar'))
      return Icons.folder_zip_rounded;
    if (lower.contains('mp4') || lower.contains('video') || lower.contains('avi'))
      return Icons.video_file_rounded;
    if (lower.contains('jpg') || lower.contains('png') || lower.contains('img'))
      return Icons.image_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _fileColor(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('pdf')) return const Color(0xFFEF4444);
    if (lower.contains('doc') || lower.contains('word'))
      return const Color(0xFF3B82F6);
    if (lower.contains('xls') || lower.contains('excel'))
      return const Color(0xFF22C55E);
    if (lower.contains('ppt') || lower.contains('power'))
      return const Color(0xFFF97316);
    if (lower.contains('zip') || lower.contains('rar'))
      return const Color(0xFF8B5CF6);
    return const Color(0xFF6B7280);
  }

  String _formatTime(String time) {
    final ms = int.tryParse(time);
    if (ms == null) return time;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day}';
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
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

  Color _statusColor(Homework hw) {
    if (hw.graded) return AppColors.success;
    if (hw.submitted) return AppColors.info;
    final ms = int.tryParse(hw.deadline);
    if (ms != null &&
        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now())) {
      return AppColors.error;
    }
    return AppColors.warning;
  }

  String _statusText(Homework hw) {
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
  final CourseFile file;
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
