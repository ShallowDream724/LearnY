import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/responsive.dart';
import '../../core/design/typography.dart';
import '../../core/router/router.dart';
import '../search/widgets/search_result_sections.dart';
import 'providers/search_controller.dart';
import 'providers/search_models.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final Map<String, bool> _collapsedSections = <String, bool>{};
  final Map<String, GlobalKey> _sectionKeys = <String, GlobalKey>{};

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
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(_collapsedSections.clear);
    ref.read(searchControllerProvider.notifier).onQueryChanged(query);
  }

  void _onRecentTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    setState(_collapsedSections.clear);
    ref.read(searchControllerProvider.notifier).searchImmediately(query);
  }

  void _onResultTap(SearchResult result) {
    switch (result.navigationType) {
      case SearchNavigationType.courseDetail:
        context.go(Routes.courseDetail(result.courseId));
        break;
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
        if (routeData == null) {
          return;
        }
        context.push(Routes.fileDetailFromData(routeData));
        break;
    }
  }

  bool _isCollapsed(String sectionId) => _collapsedSections[sectionId] ?? false;

  void _toggleSection(String sectionId) {
    setState(() {
      _collapsedSections[sectionId] = !_isCollapsed(sectionId);
    });
  }

  GlobalKey _keyForSection(String sectionId) {
    return _sectionKeys.putIfAbsent(sectionId, GlobalKey.new);
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
    final searchState = ref.watch(searchControllerProvider);
    final groups = groupSearchResults(searchState.results);

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
                ref.read(searchControllerProvider.notifier).onQueryChanged('');
              },
            ),
        ],
      ),
      body: ResponsiveContent(child: _buildBody(searchState, groups)),
    );
  }

  Widget _buildBody(SearchState searchState, List<SearchResultGroup> groups) {
    final c = context.colors;

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

    if (!searchState.hasSearched) {
      return _buildRecentSearches(searchState);
    }

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
              '试试课程名、文件类型、附件或拼音',
              style: AppTypography.bodySmall.copyWith(color: c.tertiary),
            ),
          ],
        ),
      );
    }

    return _buildResults(searchState, groups);
  }

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
              '搜索课程、通知、作业、文件与附件',
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
          children: searchState.recentSearches.map((query) {
            return Material(
              color: c.surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _onRecentTap(query),
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
                    query,
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

  Widget _buildResults(
    SearchState searchState,
    List<SearchResultGroup> groups,
  ) {
    final c = context.colors;
    final split = splitSearchResultGroups(groups);

    final children = <Widget>[
      Text(
        '找到 ${searchState.results.length} 个结果',
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
      controller: _scrollController,
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
                                onTap: () => _onResultTap(result),
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

class _SearchField extends StatelessWidget {
  const _SearchField({
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
          hintText: '搜索课程、通知、作业、文件、附件或拼音...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: c.tertiary),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.tertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
