import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
                      _jumpToSection(group.section.id);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _jumpToSection(String sectionId) {
    setState(() => _collapsedSections[sectionId] = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final targetContext = _sectionKeys[sectionId]?.currentContext;
      if (targetContext == null) {
        return;
      }
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 260),
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
    final children = <Widget>[
      Text(
        '找到 ${state.results.length} 个结果',
        style: AppTypography.bodySmall.copyWith(color: c.tertiary),
      ).animate().fadeIn(duration: 200.ms),
      const SizedBox(height: 16),
      ..._buildGroupCards(split.keywordGroups),
    ];

    if (split.hasRelatedGroups) {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '相关结果',
            style: AppTypography.labelMedium.copyWith(color: c.tertiary),
          ),
        ),
      );
      children.addAll(_buildGroupCards(split.relatedGroups));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: children,
    );
  }

  List<Widget> _buildGroupCards(List<SearchResultGroup> groups) {
    return groups
        .map((group) {
          return Container(
            key: _keyForSection(group.section.id),
            child: Column(
              children: [
                SearchSectionHeader(
                  section: group.section,
                  count: group.results.length,
                  collapsed: _isCollapsed(group.section.id),
                  onTap: () => _toggleSection(group.section.id),
                ),
                if (!_isCollapsed(group.section.id)) ...[
                  const SizedBox(height: 8),
                  ...group.results.asMap().entries.map((entry) {
                    final index = entry.key;
                    final result = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child:
                          SearchResultTile(
                                result: result,
                                onTap: () => _openResult(result),
                              )
                              .animate(delay: (24 * index).ms)
                              .fadeIn(duration: 180.ms),
                    );
                  }),
                  const SizedBox(height: 12),
                ] else
                  const SizedBox(height: 8),
              ],
            ),
          );
        })
        .toList(growable: false);
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
          hintText: '搜索这门课的通知、作业、文件、附件或拼音...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: c.tertiary),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.tertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
