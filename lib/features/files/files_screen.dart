/// Global files screen — all files across courses with timeline groups.
///
/// Features:
/// - Time groups: 今天新增 / 本周 / 更早
/// - Filter pills: 全部 / 未读(新) / 收藏 / 已下载
/// - Search bar (title + course name fuzzy match)
/// - Tap → FileDetailScreen
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/providers/providers.dart';
import '../../core/database/database.dart' as db;
import '../../core/router/router.dart';
import 'widgets/file_card.dart';

// ---------------------------------------------------------------------------
//  Filter
// ---------------------------------------------------------------------------

enum _FileFilter { all, unread, favorite, downloaded }

// ---------------------------------------------------------------------------
//  Time group
// ---------------------------------------------------------------------------

enum _TimeGroup { today, thisWeek, earlier }

String _timeGroupLabel(_TimeGroup group) {
  switch (group) {
    case _TimeGroup.today:
      return '今日新增';
    case _TimeGroup.thisWeek:
      return '本周';
    case _TimeGroup.earlier:
      return '更早';
  }
}

IconData _timeGroupIcon(_TimeGroup group) {
  switch (group) {
    case _TimeGroup.today:
      return Icons.today_rounded;
    case _TimeGroup.thisWeek:
      return Icons.date_range_rounded;
    case _TimeGroup.earlier:
      return Icons.history_rounded;
  }
}

_TimeGroup _classifyByTime(String uploadTime) {
  try {
    final dt = DateTime.parse(uploadTime);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: now.weekday - 1));

    if (dt.isAfter(today)) return _TimeGroup.today;
    if (dt.isAfter(weekStart)) return _TimeGroup.thisWeek;
    return _TimeGroup.earlier;
  } catch (_) {
    return _TimeGroup.earlier;
  }
}

// ---------------------------------------------------------------------------
//  Provider — all files joined with course names
// ---------------------------------------------------------------------------

class _FileWithCourse {
  final db.CourseFile file;
  final String courseName;

  const _FileWithCourse({required this.file, required this.courseName});
}

final _allFilesWithCourseProvider = StreamProvider<List<_FileWithCourse>>((
  ref,
) {
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) return Stream.value([]);

  // Watch both files and courses
  return database.watchAllFiles().asyncMap((files) async {
    final courses = await database.getCoursesBySemester(semesterId);
    final courseMap = {for (final c in courses) c.id: c.name};

    return files
        .where((f) => courseMap.containsKey(f.courseId))
        .map(
          (f) =>
              _FileWithCourse(file: f, courseName: courseMap[f.courseId] ?? ''),
        )
        .toList();
  });
});

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  _FileFilter _filter = _FileFilter.all;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<_FileWithCourse> _applyFilter(List<_FileWithCourse> files) {
    var result = files;

    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (f) =>
                f.file.title.toLowerCase().contains(q) ||
                f.courseName.toLowerCase().contains(q),
          )
          .toList();
    }

    // Filter
    switch (_filter) {
      case _FileFilter.all:
        break;
      case _FileFilter.unread:
        result = result.where((f) => f.file.isNew).toList();
        break;
      case _FileFilter.favorite:
        result = result.where((f) => f.file.isFavorite == true).toList();
        break;
      case _FileFilter.downloaded:
        result = result
            .where((f) => f.file.localDownloadState == 'downloaded')
            .toList();
        break;
    }

    return result;
  }

  Map<_TimeGroup, List<_FileWithCourse>> _groupByTime(
    List<_FileWithCourse> files,
  ) {
    final groups = <_TimeGroup, List<_FileWithCourse>>{};
    for (final f in files) {
      final group = _classifyByTime(f.file.uploadTime);
      groups.putIfAbsent(group, () => []).add(f);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final filesAsync = ref.watch(_allFilesWithCourseProvider);

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
                      children: _FileFilter.values.map((f) {
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
                            selectedColor: context.isDark
                                ? AppColors.info
                                : const Color(0xFF007AFF),
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
              final filtered = _applyFilter(allFiles);

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
                              : _filter != _FileFilter.all
                              ? '暂无${_filterLabel(_filter)}文件'
                              : '暂无文件',
                          style: TextStyle(color: c.subtitle, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final groups = _groupByTime(filtered);
              final orderedGroups = _TimeGroup.values
                  .where((g) => groups.containsKey(g))
                  .toList();

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Calculate which group and item
                    int cursor = 0;
                    for (final group in orderedGroups) {
                      final items = groups[group]!;
                      // Group header
                      if (index == cursor) {
                        return _SectionHeader(
                          group: group,
                          count: items.length,
                        );
                      }
                      cursor++;
                      // Items
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
                                file: item.file,
                                courseName: item.courseName,
                                onTap: () => _navigateToDetail(item),
                              ).animate().fadeIn(
                                delay: Duration(milliseconds: itemIndex * 30),
                                duration: 200.ms,
                              ),
                        );
                      }
                      cursor += items.length;
                    }
                    // Bottom padding
                    return const SizedBox(height: 32);
                  },
                  childCount:
                      orderedGroups.fold<int>(
                        0,
                        (sum, g) => sum + groups[g]!.length + 1,
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

  void _navigateToDetail(_FileWithCourse item) {
    context.push(
      Routes.fileDetail(
        fileId: item.file.id,
        courseId: item.file.courseId,
        courseName: item.courseName,
      ),
    );
  }

  String _filterLabel(_FileFilter f) {
    switch (f) {
      case _FileFilter.all:
        return '全部';
      case _FileFilter.unread:
        return '未读';
      case _FileFilter.favorite:
        return '收藏';
      case _FileFilter.downloaded:
        return '已下载';
    }
  }
}

// ---------------------------------------------------------------------------
//  Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final _TimeGroup group;
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
