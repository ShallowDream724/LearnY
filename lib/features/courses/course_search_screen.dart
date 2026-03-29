import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/typography.dart';
import '../../core/router/router.dart';
import '../search/providers/search_models.dart';
import '../search/widgets/search_result_sections.dart';
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
  late final CourseSearchArgs _args;
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, bool> _collapsedSections = <String, bool>{};
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _args = CourseSearchArgs(
      courseId: widget.courseId,
      courseName: widget.courseName,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isCollapsed(String sectionId) => _collapsedSections[sectionId] ?? false;

  GlobalKey _keyForSection(String sectionId) {
    return _sectionKeys.putIfAbsent(sectionId, GlobalKey.new);
  }

  void _toggleSection(String sectionId) {
    setState(() {
      _collapsedSections[sectionId] = !_isCollapsed(sectionId);
    });
  }

  void _openResult(SearchResult result) {
    switch (result.navigationType) {
      case SearchNavigationType.notificationDetail:
        context.push(
          Routes.notificationDetail(
            notificationId: result.id,
            courseId: result.courseId,
            courseName: result.courseName,
          ),
        );
        break;
      case SearchNavigationType.homeworkDetail:
        context.push(
          Routes.homeworkDetail(
            homeworkId: result.id,
            courseId: result.courseId,
            courseName: result.courseName,
          ),
        );
        break;
      case SearchNavigationType.fileDetail:
        final routeData = result.fileRouteData;
        if (routeData != null) {
          context.push(Routes.fileDetailFromData(routeData));
        }
        break;
      case SearchNavigationType.courseDetail:
        context.go(Routes.courseDetail(result.courseId));
        break;
    }
  }

  Future<void> _openSectionMenu(List<SearchResultGroup> groups) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final c = context.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '跳转到结果分组',
                  style: AppTypography.titleMedium.copyWith(color: c.text),
                ),
                const SizedBox(height: 12),
                for (final group in groups)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      group.section.icon,
                      size: 18,
                      color: group.section.accentColor,
                    ),
                    title: Text(group.section.title),
                    trailing: Text(
                      '${group.results.length}',
                      style: AppTypography.labelMedium.copyWith(
                        color: c.tertiary,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(_jumpToSection(group.section.id, groups));
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _jumpToSection(
    String sectionId,
    List<SearchResultGroup> groups,
  ) async {
    setState(() => _collapsedSections[sectionId] = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_scrollToSection(sectionId, groups));
    });
  }

  Future<void> _scrollToSection(
    String sectionId,
    List<SearchResultGroup> groups,
  ) async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final visibleContext = _sectionKeys[sectionId]?.currentContext;
    if (visibleContext != null) {
      await Scrollable.ensureVisible(
        visibleContext,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
      return;
    }

    final items = _buildListItems(
      resultCount: 0,
      split: splitSearchResultGroups(groups),
    );
    final targetIndex = _indexOfSection(sectionId, items);
    if (targetIndex == null) {
      return;
    }

    final estimatedOffset = _estimateOffsetToIndex(targetIndex, items);
    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = estimatedOffset.clamp(0.0, maxScroll);
    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final targetContext = _sectionKeys[sectionId]?.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final searchState = ref.watch(courseSearchControllerProvider(_args));
    final groups = groupSearchResults(searchState.results);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: _CourseSearchField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (query) {
            setState(_collapsedSections.clear);
            ref
                .read(courseSearchControllerProvider(_args).notifier)
                .onQueryChanged(query);
          },
        ),
        actions: [
          if (groups.isNotEmpty)
            IconButton(
              tooltip: '结果分组',
              icon: Icon(Icons.list_alt_rounded, color: c.subtitle, size: 20),
              onPressed: () => _openSectionMenu(groups),
            ),
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: c.subtitle, size: 20),
              onPressed: () {
                _controller.clear();
                setState(_collapsedSections.clear);
                ref
                    .read(courseSearchControllerProvider(_args).notifier)
                    .onQueryChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(searchState, groups),
    );
  }

  Widget _buildBody(CourseSearchState state, List<SearchResultGroup> groups) {
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
              '搜索这门课的通知、作业、文件与附件',
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

    final split = splitSearchResultGroups(groups);
    final items = _buildListItems(
      resultCount: state.results.length,
      split: split,
    );

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _CourseSearchSummaryItem(:final count) => Text(
            '找到 $count 个结果',
            style: AppTypography.bodySmall.copyWith(color: c.tertiary),
          ),
          _CourseSearchSectionMarkerItem() => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '相关结果',
              style: AppTypography.labelMedium.copyWith(color: c.tertiary),
            ),
          ),
          _CourseSearchSpacerItem(:final height) => SizedBox(height: height),
          _CourseSearchGroupHeaderItem(:final group) => Container(
            key: _keyForSection(group.section.id),
            child: SearchSectionHeader(
              section: group.section,
              count: group.results.length,
              collapsed: _isCollapsed(group.section.id),
              onTap: () => _toggleSection(group.section.id),
            ),
          ),
          _CourseSearchResultItem(:final result) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SearchResultTile(
              result: result,
              onTap: () => _openResult(result),
            ),
          ),
        };
      },
    );
  }

  List<_CourseSearchListItem> _buildListItems({
    required int resultCount,
    required SearchResultGroupSplit split,
  }) {
    final items = <_CourseSearchListItem>[
      _CourseSearchSummaryItem(resultCount),
      const _CourseSearchSpacerItem(16),
    ];

    void appendGroups(List<SearchResultGroup> groups) {
      for (final group in groups) {
        items.add(_CourseSearchGroupHeaderItem(group));
        if (_isCollapsed(group.section.id)) {
          items.add(const _CourseSearchSpacerItem(8));
          continue;
        }
        items.add(const _CourseSearchSpacerItem(8));
        items.addAll(group.results.map(_CourseSearchResultItem.new));
        items.add(const _CourseSearchSpacerItem(12));
      }
    }

    appendGroups(split.keywordGroups);
    if (split.hasRelatedGroups) {
      items.add(const _CourseSearchSectionMarkerItem());
      appendGroups(split.relatedGroups);
    }

    return items;
  }

  int? _indexOfSection(String sectionId, List<_CourseSearchListItem> items) {
    for (var index = 0; index < items.length; index += 1) {
      final item = items[index];
      if (item is _CourseSearchGroupHeaderItem &&
          item.group.section.id == sectionId) {
        return index;
      }
    }
    return null;
  }

  double _estimateOffsetToIndex(
    int targetIndex,
    List<_CourseSearchListItem> items,
  ) {
    var offset = 0.0;
    for (var index = 0; index < targetIndex; index += 1) {
      offset += _estimatedItemHeight(items[index]);
    }
    return offset;
  }

  double _estimatedItemHeight(_CourseSearchListItem item) {
    return switch (item) {
      _CourseSearchSummaryItem() => 24,
      _CourseSearchSectionMarkerItem() => 30,
      _CourseSearchGroupHeaderItem() => 36,
      _CourseSearchResultItem(:final result) =>
        result.isFavorite || result.isDownloaded ? 92 : 80,
      _CourseSearchSpacerItem(:final height) => height,
    };
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textAlignVertical: TextAlignVertical.center,
        style: AppTypography.bodyMedium.copyWith(color: c.text),
        decoration: InputDecoration(
          isCollapsed: true,
          hintText: '搜索这门课的通知、作业、文件、附件或拼音...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: c.tertiary),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.search_rounded, size: 18, color: c.tertiary),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 38,
            minHeight: 18,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.only(right: 12),
        ),
      ),
    );
  }
}

sealed class _CourseSearchListItem {
  const _CourseSearchListItem();
}

final class _CourseSearchSummaryItem extends _CourseSearchListItem {
  const _CourseSearchSummaryItem(this.count);

  final int count;
}

final class _CourseSearchSectionMarkerItem extends _CourseSearchListItem {
  const _CourseSearchSectionMarkerItem();
}

final class _CourseSearchGroupHeaderItem extends _CourseSearchListItem {
  const _CourseSearchGroupHeaderItem(this.group);

  final SearchResultGroup group;
}

final class _CourseSearchResultItem extends _CourseSearchListItem {
  const _CourseSearchResultItem(this.result);

  final SearchResult result;
}

final class _CourseSearchSpacerItem extends _CourseSearchListItem {
  const _CourseSearchSpacerItem(this.height);

  final double height;
}
