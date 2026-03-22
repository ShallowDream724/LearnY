// Global files screen — all files across courses with timeline groups.
//
// Features:
// - Time groups: 今天新增 / 本周 / 更早
// - Filter pills: 全部 / 未读(新) / 收藏 / 已下载
// - Search bar (title + course name fuzzy match)
// - Tap → FileDetailScreen
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/router/router.dart';
import 'providers/file_queries.dart';
import 'widgets/file_card.dart';

// ---------------------------------------------------------------------------
//  Filter
// ---------------------------------------------------------------------------

String _timeGroupLabel(FileFeedTimeGroup group) {
  switch (group) {
    case FileFeedTimeGroup.today:
      return '今日新增';
    case FileFeedTimeGroup.thisWeek:
      return '本周';
    case FileFeedTimeGroup.earlier:
      return '更早';
  }
}

IconData _timeGroupIcon(FileFeedTimeGroup group) {
  switch (group) {
    case FileFeedTimeGroup.today:
      return Icons.today_rounded;
    case FileFeedTimeGroup.thisWeek:
      return Icons.date_range_rounded;
    case FileFeedTimeGroup.earlier:
      return Icons.history_rounded;
  }
}

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  FileFeedFilter _filter = FileFeedFilter.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final filesAsync = ref.watch(allFileFeedEntriesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          // App bar
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text(
              '文件',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Column(
                children: [
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        style: TextStyle(fontSize: 14, color: c.text),
                        decoration: InputDecoration(
                          hintText: '搜索文件名或课程名...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: c.subtitle.withAlpha(150),
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: c.subtitle,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: c.subtitle,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                        ),
                        onChanged: (v) => setState(() => _searchQuery = v),
                      ),
                    ),
                  ),

                  // Filter pills
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: FileFeedFilter.values.map((f) {
                        final isActive = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(_filterLabel(f)),
                            selected: isActive,
                            onSelected: (_) => setState(() => _filter = f),
                            showCheckmark: false,
                            labelStyle: TextStyle(
                              fontSize: 12,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isActive ? Colors.white : c.subtitle,
                            ),
                            backgroundColor: c.surface,
                            selectedColor: c.infoAccent,
                            side: BorderSide(
                              color: isActive ? Colors.transparent : c.border,
                              width: 0.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // Content
          filesAsync.when(
            loading: () => const SliverFillRemaining(child: ListSkeleton()),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 40,
                      color: c.subtitle,
                    ),
                    const SizedBox(height: 10),
                    Text('加载失败', style: TextStyle(color: c.text, fontSize: 15)),
                  ],
                ),
              ),
            ),
            data: (allFiles) {
              final presentation = buildFilesPresentation(
                entries: allFiles,
                filter: _filter,
                searchQuery: _searchQuery,
              );
              final filtered = presentation.filteredEntries;

              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.folder_open_rounded,
                          size: 48,
                          color: c.subtitle.withAlpha(100),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? '没有匹配的文件'
                              : _filter != FileFeedFilter.all
                              ? '暂无${_filterLabel(_filter)}文件'
                              : '暂无文件',
                          style: TextStyle(color: c.subtitle, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final sections = presentation.sections;

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    int cursor = 0;
                    for (final section in sections) {
                      final items = section.entries;
                      if (index == cursor) {
                        return _SectionHeader(
                          group: section.group,
                          count: items.length,
                        );
                      }
                      cursor++;
                      if (index < cursor + items.length) {
                        final itemIndex = index - cursor;
                        final item = items[itemIndex];
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child:
                              FileCard(
                                item: item.item,
                                isFavorite: item.isFavorite,
                                onTap: () => _navigateToDetail(item),
                              ).animate().fadeIn(
                                delay: Duration(milliseconds: itemIndex * 30),
                                duration: 200.ms,
                              ),
                        );
                      }
                      cursor += items.length;
                    }
                    return const SizedBox(height: 32);
                  },
                  childCount:
                      sections.fold<int>(
                        0,
                        (sum, section) => sum + section.entries.length + 1,
                      ) +
                      1,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToDetail(FileFeedEntry entry) {
    context.push(Routes.fileDetailFromData(entry.item.routeData));
  }

  String _filterLabel(FileFeedFilter f) {
    switch (f) {
      case FileFeedFilter.all:
        return '全部';
      case FileFeedFilter.unread:
        return '未读';
      case FileFeedFilter.favorite:
        return '收藏';
      case FileFeedFilter.downloaded:
        return '已下载';
    }
  }
}

// ---------------------------------------------------------------------------
//  Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final FileFeedTimeGroup group;
  final int count;

  const _SectionHeader({required this.group, required this.count});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Icon(_timeGroupIcon(group), size: 18, color: c.subtitle),
          const SizedBox(width: 8),
          Text(
            _timeGroupLabel(group),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: (context.isDark ? Colors.white : Colors.black).withAlpha(
                15,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: c.subtitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
