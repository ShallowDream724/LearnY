import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_surfaces.dart';
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
  final Map<String, double> _groupScrollOffsets = <String, double>{};
  String? _selectedGroupId;
  int _queryVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
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
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    setState(() {
      _collapsedSections.clear();
      _groupScrollOffsets.clear();
      _selectedGroupId = null;
      _queryVersion++;
    });
    ref.read(searchControllerProvider.notifier).onQueryChanged(query);
  }

  void _onRecentTap(String query) {
    _controller.text = query;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _onSearchChanged(query);
    ref.read(searchControllerProvider.notifier).searchImmediately(query);
  }

  void _onResultTap(SearchResult result) {
    _focusNode.unfocus();
    switch (result.navigationType) {
      case SearchNavigationType.courseDetail:
        context.push(Routes.courseDetail(result.courseId));
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

  void _selectGroup(String? id) {
    if (_selectedGroupId == id) return;
    if (_scrollController.hasClients) {
      _groupScrollOffsets[_selectedGroupId ?? 'all'] = _scrollController.offset;
    }
    final version = _queryVersion;
    setState(() {
      _selectedGroupId = id;
      if (id != null) _collapsedSections[id] = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          version == _queryVersion &&
          _selectedGroupId == id &&
          _scrollController.hasClients) {
        _scrollController.jumpTo(
          (_groupScrollOffsets[id ?? 'all'] ?? 0).clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final searchState = ref.watch(searchControllerProvider);
    ref.listen(searchControllerProvider, (previous, next) {
      if (next.query.isEmpty &&
          previous?.query.isNotEmpty == true &&
          _controller.text.isNotEmpty) {
        _controller.clear();
        setState(() {
          _selectedGroupId = null;
          _collapsedSections.clear();
          _groupScrollOffsets.clear();
          _queryVersion++;
        });
      }
    });
    final groups = groupSearchResults(searchState.results);
    final selectedGroups = groups
        .where((group) => group.section.id == _selectedGroupId)
        .toList();
    final visibleGroups = selectedGroups.isEmpty ? groups : selectedGroups;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text('搜索'),
        actions: [
          if (groups.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: '筛选结果分组',
              icon: Icon(Icons.list_alt_rounded, color: c.subtitle, size: 20),
              onSelected: (id) => _selectGroup(id == 'all' ? null : id),
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'all', child: Text('全部结果')),
                for (final group in groups)
                  PopupMenuItem(
                    value: group.section.id,
                    child: Text(
                      '${group.section.title} (${group.results.length})',
                    ),
                  ),
              ],
            ),
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: '清除搜索',
              icon: Icon(Icons.clear_rounded, color: c.subtitle, size: 20),
              onPressed: () {
                _controller.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: ReadingWidth(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: _SearchField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onSearchChanged,
                onSubmitted: (query) => ref
                    .read(searchControllerProvider.notifier)
                    .searchImmediately(query),
              ),
            ),
            if (selectedGroups.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InputChip(
                    label: Text(selectedGroups.single.section.title),
                    onDeleted: () => _selectGroup(null),
                    deleteButtonTooltipMessage: '返回全部结果',
                  ),
                ),
              ),
            Expanded(child: _buildBody(searchState, visibleGroups)),
          ],
        ),
      ),
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
                color: c.infoAccent,
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

    if (searchState.errorMessage != null) {
      return AppEmptyState(
        icon: Icons.error_outline_rounded,
        title: searchState.errorMessage!,
        action: FilledButton.tonalIcon(
          onPressed: () => ref
              .read(searchControllerProvider.notifier)
              .searchImmediately(_controller.text),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('重试'),
        ),
      );
    }

    if (searchState.results.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_off_rounded,
        title: '未找到相关内容',
      );
    }

    return _buildResults(searchState, groups);
  }

  Widget _buildRecentSearches(SearchState searchState) {
    final c = context.colors;

    if (searchState.recentSearches.isEmpty) {
      return const AppEmptyState(
        icon: Icons.search_rounded,
        title: '找到需要的学习内容',
        message: '输入课程名、标题或关键词',
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
            IconButton(
              tooltip: '清除搜索记录',
              onPressed: () => ref
                  .read(searchControllerProvider.notifier)
                  .clearRecentSearches(),
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: searchState.recentSearches.map((query) {
            return ActionChip(
              label: Text(query),
              onPressed: () => _onRecentTap(query),
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
    final items = _buildListItems(
      resultCount: groups.fold(
        0,
        (count, group) => count + group.results.length,
      ),
      split: split,
    );

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return switch (item) {
          _SearchSummaryItem(:final count) => Text(
            '找到 $count 个结果',
            style: AppTypography.bodySmall.copyWith(color: c.tertiary),
          ),
          _SearchSectionMarkerItem() => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '相关结果',
              style: AppTypography.labelMedium.copyWith(color: c.tertiary),
            ),
          ),
          _SearchSpacerItem(:final height) => SizedBox(height: height),
          _SearchGroupHeaderItem(:final group) => SearchSectionHeader(
            section: group.section,
            count: group.results.length,
            collapsed: _isCollapsed(group.section.id),
            onTap: () => _toggleSection(group.section.id),
          ),
          _SearchResultItem(:final result) => Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: SearchResultTile(
              result: result,
              onTap: () => _onResultTap(result),
            ),
          ),
        };
      },
    );
  }

  List<_SearchListItem> _buildListItems({
    required int resultCount,
    required SearchResultGroupSplit split,
  }) {
    final items = <_SearchListItem>[
      _SearchSummaryItem(resultCount),
      const _SearchSpacerItem(16),
    ];

    void appendGroups(List<SearchResultGroup> groups) {
      for (final group in groups) {
        items.add(_SearchGroupHeaderItem(group));
        if (_isCollapsed(group.section.id)) {
          items.add(const _SearchSpacerItem(8));
          continue;
        }
        items.add(const _SearchSpacerItem(8));
        items.addAll(group.results.map(_SearchResultItem.new));
        items.add(const _SearchSpacerItem(12));
      }
    }

    appendGroups(split.keywordGroups);
    if (split.hasRelatedGroups) {
      items.add(const _SearchSectionMarkerItem());
      appendGroups(split.relatedGroups);
    }

    return items;
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyMedium.copyWith(color: c.text),
      decoration: InputDecoration(
        hintText: '课程、通知、作业或文件',
        hintStyle: AppTypography.bodyMedium.copyWith(color: c.tertiary),
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.tertiary),
      ),
    );
  }
}

sealed class _SearchListItem {
  const _SearchListItem();
}

final class _SearchSummaryItem extends _SearchListItem {
  const _SearchSummaryItem(this.count);

  final int count;
}

final class _SearchSectionMarkerItem extends _SearchListItem {
  const _SearchSectionMarkerItem();
}

final class _SearchGroupHeaderItem extends _SearchListItem {
  const _SearchGroupHeaderItem(this.group);

  final SearchResultGroup group;
}

final class _SearchResultItem extends _SearchListItem {
  const _SearchResultItem(this.result);

  final SearchResult result;
}

final class _SearchSpacerItem extends _SearchListItem {
  const _SearchSpacerItem(this.height);

  final double height;
}
