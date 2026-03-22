// Global search screen — search across all courses' content.
//
// UX Design Decisions:
//
// 1. **Search-as-you-type** with 300ms debounce: responsive but not wasteful.
//    Searches local DB (Drift) so it's fast even offline.
//
// 2. **Multi-category results**: grouped into courses, notifications, homework,
//    and files — each with a visual section header and distinct card style.
//    The user can immediately see which category the result belongs to.
//
// 3. **Recent searches**: persisted in AppState (key-value store).
//    Shows up when the search field is empty, with a clear-all option.
//
// 4. **Empty states**: differentiated between "start searching" (search icon),
//    "no results" (with suggestion), and "loading" states.
//
// 5. **Result count badges**: each category header shows the count,
//    helping users gauge result distribution at a glance.
//
// 6. **Navigation**: tapping a result navigates to the appropriate detail page.

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/responsive.dart';
import '../../core/design/typography.dart';
import '../../core/router/router.dart';
import 'providers/search_controller.dart';
import 'providers/search_models.dart';

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search field
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

  void _onSearchChanged(String query) {
    ref.read(searchControllerProvider.notifier).onQueryChanged(query);
  }

  void _onRecentTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    ref.read(searchControllerProvider.notifier).searchImmediately(query);
  }

  void _onResultTap(SearchResult result) {
    switch (result.category) {
      case SearchCategory.course:
        context.go(Routes.courseDetail(result.courseId));
        break;
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
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final searchState = ref.watch(searchControllerProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: _SearchField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: c.subtitle, size: 20),
              onPressed: () {
                _controller.clear();
                ref.read(searchControllerProvider.notifier).onQueryChanged('');
              },
            ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody(searchState)),
    );
  }

  Widget _buildBody(SearchState searchState) {
    final c = context.colors;

    // Loading
    if (searchState.isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
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

    // No query yet — show recent searches
    if (!searchState.hasSearched) {
      return _buildRecentSearches(searchState);
    }

    // No results
    if (searchState.results.isEmpty) {
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
            const SizedBox(height: 6),
            Text(
              '试试其他关键词',
              style: AppTypography.bodySmall.copyWith(color: c.tertiary),
            ),
          ],
        ),
      );
    }

    // Results grouped by category
    return _buildResults(searchState);
  }

  // ── Recent searches ──

  Widget _buildRecentSearches(SearchState searchState) {
    final c = context.colors;

    if (searchState.recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: c.tertiary),
            const SizedBox(height: 12),
            Text(
              '搜索课程、通知、作业、文件',
              style: AppTypography.bodyMedium.copyWith(color: c.tertiary),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Text(
              '最近搜索',
              style: AppTypography.labelMedium.copyWith(color: c.subtitle),
            ),
            const Spacer(),
            InkWell(
              onTap: () => ref
                  .read(searchControllerProvider.notifier)
                  .clearRecentSearches(),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Text(
                  '清除',
                  style: AppTypography.labelSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: searchState.recentSearches.map((q) {
            return Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _onRecentTap(q),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: c.border, width: 0.5),
                  ),
                  child: Text(
                    q,
                    style: AppTypography.bodySmall.copyWith(color: c.text),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Search results ──

  Widget _buildResults(SearchState searchState) {
    final c = context.colors;

    // Group by category
    final grouped = <SearchCategory, List<SearchResult>>{};
    for (final r in searchState.results) {
      grouped.putIfAbsent(r.category, () => []).add(r);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Total results count
        Text(
          '找到 ${searchState.results.length} 个结果',
          style: AppTypography.bodySmall.copyWith(color: c.tertiary),
        ).animate().fadeIn(duration: 200.ms),
        const SizedBox(height: 16),

        for (final category in searchCategoryOrder)
          if (grouped.containsKey(category)) ...[
            _CategoryHeader(
              category: category,
              count: grouped[category]!.length,
            ),
            const SizedBox(height: 8),
            ...grouped[category]!.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _onResultTap(result),
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
                            child: Icon(
                              result.icon,
                              size: 17,
                              color: result.accentColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.title,
                                  style: AppTypography.titleSmall.copyWith(
                                    color: c.text,
                                  ),
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
                                          style: AppTypography.labelSmall
                                              .copyWith(
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
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: c.tertiary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate(delay: (30 * index).ms).fadeIn(duration: 200.ms);
            }),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Search field
// ─────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

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
          hintText: '搜索课程、通知、作业、文件...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: c.tertiary),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.tertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Category header
// ─────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final SearchCategory category;
  final int count;

  const _CategoryHeader({required this.category, required this.count});

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
