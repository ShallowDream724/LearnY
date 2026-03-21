import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/router/router.dart';
import '../search/providers/search_models.dart';
import 'providers/course_search_controller.dart';

class CourseSearchScreen extends ConsumerStatefulWidget {
  const CourseSearchScreen({
    super.key,
    required this.courseId,
    required this.courseName,
  });

  final String courseId;
  final String courseName;

  @override
  ConsumerState<CourseSearchScreen> createState() => _CourseSearchScreenState();
}

class _CourseSearchScreenState extends ConsumerState<CourseSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  late final CourseSearchArgs _args = CourseSearchArgs(
    courseId: widget.courseId,
    courseName: widget.courseName,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final searchState = ref.watch(courseSearchControllerProvider(_args));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: _CourseSearchField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (query) => ref
              .read(courseSearchControllerProvider(_args).notifier)
              .onQueryChanged(query),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: c.subtitle, size: 20),
              onPressed: () {
                _controller.clear();
                ref
                    .read(courseSearchControllerProvider(_args).notifier)
                    .onQueryChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(searchState),
    );
  }

  Widget _buildBody(CourseSearchState state) {
    final c = context.colors;
    if (state.isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(
              '搜索中...',
              style: AppTypography.bodySmall.copyWith(color: c.tertiary),
            ),
          ],
        ),
      );
    }

    if (!state.hasSearched) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: c.tertiary),
            const SizedBox(height: 12),
            Text(
              '搜索这门课的通知、作业、文件',
              style: AppTypography.bodyMedium.copyWith(color: c.tertiary),
            ),
          ],
        ),
      );
    }

    if (state.results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: c.tertiary),
            const SizedBox(height: 12),
            Text(
              '未找到相关内容',
              style: AppTypography.titleMedium.copyWith(color: c.subtitle),
            ),
          ],
        ),
      );
    }

    final grouped = <SearchCategory, List<SearchResult>>{};
    for (final result in state.results) {
      grouped.putIfAbsent(result.category, () => []).add(result);
    }
    final categories = const [
      SearchCategory.notification,
      SearchCategory.homework,
      SearchCategory.file,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          '找到 ${state.results.length} 个结果',
          style: AppTypography.bodySmall.copyWith(color: c.tertiary),
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: 16),
        for (final category in categories)
          if (grouped.containsKey(category)) ...[
            _CourseSearchCategoryHeader(
              category: category,
              count: grouped[category]!.length,
            ),
            const SizedBox(height: 8),
            ...grouped[category]!.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CourseSearchResultTile(
                  result: result,
                  onTap: () => _openResult(result),
                ).animate(delay: (30 * index).ms).fadeIn(duration: 200.ms),
              );
            }),
            const SizedBox(height: 16),
          ],
      ],
    );
  }

  void _openResult(SearchResult result) {
    switch (result.category) {
      case SearchCategory.notification:
        context.push(
          Routes.notificationDetail(
            notificationId: result.id,
            courseId: result.courseId,
            courseName: result.courseName,
          ),
        );
        break;
      case SearchCategory.homework:
        context.push(
          Routes.homeworkDetail(
            homeworkId: result.id,
            courseId: result.courseId,
            courseName: result.courseName,
          ),
        );
        break;
      case SearchCategory.file:
        context.push(
          Routes.fileDetail(
            fileId: result.id,
            courseId: result.courseId,
            courseName: result.courseName,
          ),
        );
        break;
      case SearchCategory.course:
        context.go(Routes.courseDetail(result.courseId));
        break;
    }
  }
}

class _CourseSearchField extends StatelessWidget {
  const _CourseSearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: AppTypography.bodyMedium.copyWith(color: c.text),
        decoration: InputDecoration(
          hintText: '搜索这门课的通知、作业、文件...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: c.tertiary),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.tertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _CourseSearchCategoryHeader extends StatelessWidget {
  const _CourseSearchCategoryHeader({
    required this.category,
    required this.count,
  });

  final SearchCategory category;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (label, icon, color) = searchCategoryPresentation(category);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTypography.labelMedium.copyWith(
            color: c.subtitle,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

class _CourseSearchResultTile extends StatelessWidget {
  const _CourseSearchResultTile({required this.result, required this.onTap});

  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: result.accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(result.icon, size: 17, color: result.accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: AppTypography.titleSmall.copyWith(color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.isFavorite &&
                        result.category == SearchCategory.file)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.bookmark_rounded,
                              size: 12,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '已收藏',
                              style: AppTypography.labelSmall.copyWith(
                                color: AppColors.warning,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      result.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: c.tertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.tertiary),
            ],
          ),
        ),
      ),
    );
  }
}
