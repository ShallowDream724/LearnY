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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/router/router.dart';
import 'providers/course_queries.dart';
import 'widgets/course_detail_tabs.dart';

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
    final c = context.colors;
    final courseAsync = ref.watch(courseDetailProvider(widget.courseId));

    return Scaffold(
      body: courseAsync.when(
        loading: () => const Center(child: ListSkeleton()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: c.subtitle),
              const SizedBox(height: 12),
              Text(
                '加载失败',
                style: AppTypography.titleMedium.copyWith(color: c.subtitle),
              ),
              const SizedBox(height: 8),
              Text(
                '请返回重试',
                style: AppTypography.bodySmall.copyWith(
                  color: c.subtitle.withAlpha(180),
                ),
              ),
            ],
          ),
        ),
        data: (course) {
          if (course == null) {
            return Center(
              child: Text(
                '课程未找到',
                style: AppTypography.titleMedium.copyWith(color: c.subtitle),
              ),
            );
          }

          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 120,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => context.push(
                      Routes.courseSearch(
                        courseId: widget.courseId,
                        courseName: course.name,
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(
                    left: 56,
                    bottom: 50,
                    right: 16,
                  ),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.name,
                        style: AppTypography.titleMedium.copyWith(
                          color: c.text,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (course.teacherName.isNotEmpty)
                        Text(
                          course.teacherName,
                          style: AppTypography.bodySmall.copyWith(
                            color: c.subtitle,
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
                          AppColors.primary.withAlpha(context.isDark ? 40 : 30),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: c.subtitle,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelStyle: AppTypography.labelLarge,
                  unselectedLabelStyle: AppTypography.labelMedium,
                  tabs: [_buildTab('通知'), _buildTab('文件'), _buildTab('作业')],
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                CourseNotificationsTab(
                  courseId: widget.courseId,
                  courseName: course.name,
                ),
                CourseFilesTab(
                  courseId: widget.courseId,
                  courseName: course.name,
                ),
                CourseHomeworksTab(
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

  Widget _buildTab(String label) {
    return Tab(text: label);
  }
}
