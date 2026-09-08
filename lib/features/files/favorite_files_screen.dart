import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surfaces.dart';
import '../../core/design/app_materials.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/router/router.dart';
import 'providers/file_bookmark_providers.dart';
import 'widgets/file_card.dart';
import 'widgets/file_search_field.dart';

class FavoriteFilesScreen extends ConsumerStatefulWidget {
  const FavoriteFilesScreen({super.key});
  @override
  ConsumerState<FavoriteFilesScreen> createState() =>
      _FavoriteFilesScreenState();
}

class _FavoriteFilesScreenState extends ConsumerState<FavoriteFilesScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoriteFileEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('收藏文件')),
      body: ReadingWidth(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FileSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            Expanded(
              child: favorites.when(
                loading: () => const ListSkeleton(),
                error: (_, _) => AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: '收藏文件加载失败',
                  action: FilledButton.tonalIcon(
                    onPressed: () =>
                        ref.invalidate(favoriteFileEntriesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ),
                data: (entries) {
                  final presentation = buildFavoriteFilesPresentation(
                    entries: entries,
                    searchQuery: _query,
                  );
                  if (presentation.filteredEntries.isEmpty) {
                    return AppEmptyState(
                      icon: _query.isEmpty
                          ? Icons.bookmark_border_rounded
                          : Icons.search_off_rounded,
                      title: _query.isEmpty ? '暂无收藏文件' : '没有匹配的收藏文件',
                      action: _query.isEmpty
                          ? null
                          : TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              child: const Text('清除搜索'),
                            ),
                    );
                  }
                  final rows = <Object>[
                    for (final section in presentation.sections) ...[
                      section,
                      ...section.entries,
                    ],
                  ];
                  return ListView.builder(
                    key: PageStorageKey('favorite-files-${_query.trim()}'),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is FavoriteFileCourseSection) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Row(
                            children: [
                              CourseSeal(courseId: row.courseId, size: 24),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  row.courseName.isEmpty
                                      ? '未知课程'
                                      : row.courseName,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('${row.entries.length}'),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Divider(color: context.colors.border),
                              ),
                            ],
                          ),
                        );
                      }
                      final entry = row as FavoriteFileEntry;
                      return Padding(
                        key: ValueKey(entry.assetKey),
                        padding: const EdgeInsets.only(bottom: 3),
                        child: FileCard(
                          item: entry.item,
                          hideCourseName: true,
                          isFavorite: true,
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
}
