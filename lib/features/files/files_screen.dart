import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surfaces.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/providers/app_providers.dart';
import '../../core/router/router.dart';
import '../../core/semester/semester_models.dart';
import 'providers/file_queries.dart';
import 'widgets/file_card.dart';
import 'widgets/file_search_field.dart';

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});
  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  FileFeedFilter _filter = FileFeedFilter.all;
  String _query = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _filter = FileFeedFilter.all;
      _query = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(allFileFeedEntriesProvider);
    final semesterId = ref.watch(currentSemesterIdProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('文件')),
      body: ReadingWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                semesterId == null ? '尚未选择学习学期' : semesterLabel(semesterId),
                style: TextStyle(color: context.colors.subtitle),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FileSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (files.valueOrNull?.isNotEmpty == true ||
                _filter != FileFeedFilter.all)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final filter in FileFeedFilter.values)
                      FilterChip(
                        label: Text(_filterLabel(filter)),
                        selected: _filter == filter,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _filter = filter),
                      ),
                  ],
                ),
              ),
            Expanded(
              child: files.when(
                loading: () => const ListSkeleton(),
                error: (_, _) => AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: '文件加载失败',
                  action: FilledButton.tonalIcon(
                    onPressed: () => ref.invalidate(allFileFeedEntriesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ),
                data: (entries) {
                  final presentation = buildFilesPresentation(
                    entries: entries,
                    filter: _filter,
                    searchQuery: _query,
                  );
                  if (presentation.filteredEntries.isEmpty) {
                    final filtered =
                        _query.isNotEmpty || _filter != FileFeedFilter.all;
                    return AppEmptyState(
                      icon: filtered
                          ? Icons.search_off_rounded
                          : Icons.folder_open_rounded,
                      title: filtered
                          ? '没有符合条件的文件'
                          : semesterId == null
                          ? '暂无学习学期'
                          : '本学期暂无文件',
                      action: filtered
                          ? TextButton(
                              onPressed: _clearFilters,
                              child: const Text('清除筛选'),
                            )
                          : null,
                    );
                  }
                  final rows = <Object>[
                    for (final section in presentation.sections) ...[
                      section,
                      ...section.entries,
                    ],
                  ];
                  return ListView.builder(
                    key: PageStorageKey(
                      'files-${_filter.name}-${_query.trim()}',
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is FileFeedSection) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _sectionLabel(row.group),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              Text(
                                '${row.entries.length}',
                                style: TextStyle(
                                  color: context.colors.subtitle,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final entry = row as FileFeedEntry;
                      return Padding(
                        key: ValueKey(entry.item.cacheKey),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: FileCard(
                          item: entry.item,
                          isFavorite: entry.isFavorite,
                          onTap: () => context.push(
                            Routes.fileDetailFromData(entry.item.routeData),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _filterLabel(FileFeedFilter filter) => switch (filter) {
    FileFeedFilter.all => '全部',
    FileFeedFilter.unread => '未读',
    FileFeedFilter.favorite => '收藏',
    FileFeedFilter.downloaded => '已下载',
  };
  String _sectionLabel(FileFeedTimeGroup group) => switch (group) {
    FileFeedTimeGroup.today => '今日新增',
    FileFeedTimeGroup.thisWeek => '本周',
    FileFeedTimeGroup.earlier => '更早',
  };
}
