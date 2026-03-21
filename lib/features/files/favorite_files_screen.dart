import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/router/router.dart';
import 'providers/file_bookmark_providers.dart';
import 'widgets/file_card.dart';

class FavoriteFilesScreen extends ConsumerStatefulWidget {
  const FavoriteFilesScreen({super.key});

  @override
  ConsumerState<FavoriteFilesScreen> createState() =>
      _FavoriteFilesScreenState();
}

class _FavoriteFilesScreenState extends ConsumerState<FavoriteFilesScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final favoritesAsync = ref.watch(favoriteFileEntriesProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          '收藏文件',
          style: AppTypography.titleLarge.copyWith(color: c.text),
        ),
      ),
      body: favoritesAsync.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => Center(
          child: Text(
            '加载失败',
            style: AppTypography.bodyMedium.copyWith(color: c.subtitle),
          ),
        ),
        data: (entries) {
          final presentation = buildFavoriteFilesPresentation(
            entries: entries,
            searchQuery: _searchQuery,
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: c.border, width: 0.5),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    style: TextStyle(fontSize: 14, color: c.text),
                    decoration: InputDecoration(
                      hintText: '搜索收藏文件或课程名...',
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    Text(
                      '${presentation.filteredEntries.length} 个收藏文件',
                      style: AppTypography.bodySmall.copyWith(
                        color: c.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: presentation.filteredEntries.isEmpty
                    ? _FavoriteEmptyState(searchQuery: _searchQuery)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: presentation.sections.length,
                        itemBuilder: (context, index) {
                          final section = presentation.sections[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _FavoriteCourseHeader(
                                  courseName: section.courseName,
                                  count: section.entries.length,
                                ),
                                const SizedBox(height: 8),
                                ...section.entries.asMap().entries.map((entry) {
                                  final itemIndex = entry.key;
                                  final favorite = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child:
                                        FileCard(
                                              item: favorite.item,
                                              hideCourseName: true,
                                              isFavorite: true,
                                              forceDownloaded: true,
                                              onTap: () => context.push(
                                                Routes.fileDetailFromData(
                                                  favorite.item.routeData,
                                                ),
                                              ),
                                            )
                                            .animate(
                                              delay: Duration(
                                                milliseconds: itemIndex * 24,
                                              ),
                                            )
                                            .fadeIn(duration: 180.ms),
                                  );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteCourseHeader extends StatelessWidget {
  const _FavoriteCourseHeader({required this.courseName, required this.count});

  final String courseName;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.warning,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            courseName.isEmpty ? '未知课程' : courseName,
            style: AppTypography.titleMedium.copyWith(color: c.text),
          ),
        ),
        Text(
          '$count 个',
          style: AppTypography.bodySmall.copyWith(color: c.tertiary),
        ),
      ],
    );
  }
}

class _FavoriteEmptyState extends StatelessWidget {
  const _FavoriteEmptyState({required this.searchQuery});

  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searchQuery.isEmpty
                ? Icons.bookmark_border_rounded
                : Icons.search_off_rounded,
            size: 48,
            color: c.tertiary,
          ),
          const SizedBox(height: 12),
          Text(
            searchQuery.isEmpty ? '还没有收藏文件' : '没有匹配的收藏文件',
            style: AppTypography.titleMedium.copyWith(color: c.subtitle),
          ),
          const SizedBox(height: 6),
          Text(
            searchQuery.isEmpty ? '打开文件后，就可以在详情页收藏它' : '试试其他关键词',
            style: AppTypography.bodySmall.copyWith(color: c.tertiary),
          ),
        ],
      ),
    );
  }
}
