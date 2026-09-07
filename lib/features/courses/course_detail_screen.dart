import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/router/router.dart';
import 'providers/course_queries.dart';
import 'widgets/course_detail_tabs.dart';

class CourseDetailScreen extends ConsumerStatefulWidget {
  const CourseDetailScreen({super.key, required this.courseId});
  final String courseId;

  @override
  ConsumerState<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends ConsumerState<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
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
      appBar: AppBar(
        title: const Text('课程详情'),
        actions: [
          if (courseAsync.valueOrNull case final course?)
            IconButton(
              tooltip: '搜索课程内容',
              icon: const Icon(Icons.search_rounded),
              onPressed: () => context.push(
                Routes.courseSearch(
                  courseId: widget.courseId,
                  courseName: course.name,
                ),
              ),
            ),
        ],
      ),
      body: courseAsync.when(
        loading: () => const Center(child: ListSkeleton()),
        error: (e, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: '课程加载失败',
          action: OutlinedButton.icon(
            onPressed: () =>
                ref.invalidate(courseDetailProvider(widget.courseId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
        data: (course) {
          if (course == null) {
            return const AppEmptyState(
              icon: Icons.school_outlined,
              title: '课程未找到',
            );
          }
          final tabHeight = MediaQuery.textScalerOf(context).scale(16) + 28;
          final tabs = TabBar(
            controller: _tabController,
            onTap: (index) => _tabController.animateTo(
              index,
              duration: AppMotion.duration(context),
            ),
            labelColor: c.infoAccent,
            unselectedLabelColor: c.subtitle,
            indicatorColor: c.infoAccent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: AppTypography.labelLarge,
            unselectedLabelStyle: AppTypography.labelMedium,
            tabs: [
              Tab(text: '通知', height: tabHeight),
              Tab(text: '文件', height: tabHeight),
              Tab(text: '作业', height: tabHeight),
            ],
          );
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(
                child: ReadingWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          course.name,
                          style: AppTypography.headlineSmall.copyWith(
                            color: c.text,
                          ),
                        ),
                        if (course.teacherName.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            course.teacherName,
                            style: AppTypography.bodyMedium.copyWith(
                              color: c.subtitle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _CourseTabsHeader(tabs),
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
}

class _CourseTabsHeader extends SliverPersistentHeaderDelegate {
  const _CourseTabsHeader(this.tabs);
  final TabBar tabs;

  @override
  double get minExtent => tabs.preferredSize.height;
  @override
  double get maxExtent => minExtent;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => SizedBox.expand(
    child: Material(
      color: context.colors.bg,
      child: ReadingWidth(child: tabs),
    ),
  );
  @override
  bool shouldRebuild(_CourseTabsHeader oldDelegate) => oldDelegate.tabs != tabs;
}
