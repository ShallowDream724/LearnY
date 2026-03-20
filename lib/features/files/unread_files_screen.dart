/// UnreadFilesScreen — full list of all unread files with
/// search, sort (by time / by course), and file-type filter.
///
/// Accessed from home screen "查看全部" button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/colors.dart';
import '../../core/design/swipe_to_read.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/providers/providers.dart';
import '../../core/router/router.dart';
import '../files/widgets/file_card.dart';

// ---------------------------------------------------------------------------
//  Providers
// ---------------------------------------------------------------------------

/// Reactive unread files — auto-updates when DB changes.
final _unreadFilesProvider = StreamProvider<List<db.CourseFile>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchUnreadFiles();
});

/// Course names lookup.
final _courseNamesProvider = FutureProvider<Map<String, String>>((ref) async {
  final database = ref.watch(databaseProvider);
  final semId = ref.watch(currentSemesterIdProvider);
  if (semId == null) return {};
  final courses = await database.getCoursesBySemester(semId);
  return {for (final c in courses) c.id: c.name};
});

// ---------------------------------------------------------------------------
//  Sort modes
// ---------------------------------------------------------------------------

enum _SortMode { byTime, byCourse }

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class UnreadFilesScreen extends ConsumerStatefulWidget {
  const UnreadFilesScreen({super.key});

  @override
  ConsumerState<UnreadFilesScreen> createState() => _UnreadFilesScreenState();
}

class _UnreadFilesScreenState extends ConsumerState<UnreadFilesScreen> {
  _SortMode _sort = _SortMode.byTime;
  String _search = '';
  String? _typeFilter; // null = all
  final _searchController = TextEditingController();

  // Track collapsed courses in byCourse mode
  final Set<String> _collapsedCourses = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<db.CourseFile> _filter(List<db.CourseFile> files) {
    var result = files;
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      result = result
          .where((f) =>
              f.title.toLowerCase().contains(q) ||
              f.description.toLowerCase().contains(q))
          .toList();
    }
    if (_typeFilter != null) {
      result = result
          .where((f) => _extractExt(f.title, f.fileType) == _typeFilter)
          .toList();
    }
    return result;
  }

  Set<String> _extractAllTypes(List<db.CourseFile> files) {
    return files.map((f) => _extractExt(f.title, f.fileType)).where((e) => e.isNotEmpty).toSet();
  }

  static String _extractExt(String title, String fileType) {
    if (fileType.isNotEmpty) return fileType.toLowerCase();
    final dot = title.lastIndexOf('.');
    if (dot != -1 && dot < title.length - 1) {
      return title.substring(dot + 1).toLowerCase();
    }
    return '';
  }

  void _markRead(db.CourseFile f) {
    ref.read(databaseProvider).markFileRead(f.id);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final sub = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    final filesAsync = ref.watch(_unreadFilesProvider);
    final courseNamesAsync = ref.watch(_courseNamesProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        title: Text('未读文件', style: AppTypography.headlineSmall.copyWith(color: textColor)),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: filesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
            child: Text('加载失败', style: TextStyle(color: tertiary))),
        data: (allFiles) {
          final courseNames = courseNamesAsync.valueOrNull ?? {};
          final types = _extractAllTypes(allFiles);
          final filtered = _filter(allFiles);

          return Column(
            children: [
              // ── Search bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: '搜索文件...',
                    hintStyle: TextStyle(color: tertiary, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.search_rounded, color: tertiary, size: 20),
                    suffixIcon: _search.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.close_rounded,
                                color: tertiary, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _search = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                  ),
                ),
              ),

              // ── Sort toggle + type filter chips ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Sort pills
                    _SortPill(
                      label: '按时间',
                      icon: Icons.schedule_rounded,
                      isActive: _sort == _SortMode.byTime,
                      isDark: isDark,
                      onTap: () => setState(() => _sort = _SortMode.byTime),
                    ),
                    const SizedBox(width: 8),
                    _SortPill(
                      label: '按课程',
                      icon: Icons.folder_rounded,
                      isActive: _sort == _SortMode.byCourse,
                      isDark: isDark,
                      onTap: () => setState(() => _sort = _SortMode.byCourse),
                    ),
                    const SizedBox(width: 12),
                    // Divider
                    Container(
                      width: 1,
                      height: 24,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    const SizedBox(width: 12),
                    // Type filter
                    _TypeChip(
                      label: '全部',
                      isActive: _typeFilter == null,
                      isDark: isDark,
                      onTap: () => setState(() => _typeFilter = null),
                    ),
                    ...types.map((t) => Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _TypeChip(
                            label: t.toUpperCase(),
                            isActive: _typeFilter == t,
                            isDark: isDark,
                            onTap: () => setState(
                                () => _typeFilter = _typeFilter == t ? null : t),
                          ),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── Count + sort info ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      '${filtered.length} 个未读文件',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500, color: sub),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // ── File list ──
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 48, color: tertiary),
                            const SizedBox(height: 12),
                            Text(
                              _search.isNotEmpty
                                  ? '没有找到匹配的文件'
                                  : '所有文件已读',
                              style: TextStyle(color: sub, fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : _sort == _SortMode.byTime
                        ? _buildTimeList(filtered, courseNames, isDark)
                        : _buildCourseList(filtered, courseNames, isDark, textColor, sub),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTimeList(
      List<db.CourseFile> files, Map<String, String> courseNames, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: files.length,
      itemBuilder: (context, i) {
        final f = files[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SwipeToRead(
            onRead: () => _markRead(f),
            child: FileCard(
              file: f,
              courseName: courseNames[f.courseId] ?? '',
              onTap: () {
                _markRead(f);
                context.push(Routes.fileDetail(
                  fileId: f.id,
                  courseId: f.courseId,
                  courseName: courseNames[f.courseId] ?? '',
                ));
              },
            ),
          ),
        ).animate(delay: (30 * i).ms).fadeIn(duration: 200.ms);
      },
    );
  }

  Widget _buildCourseList(List<db.CourseFile> files,
      Map<String, String> courseNames, bool isDark, Color textColor, Color sub) {
    // Group by courseId
    final grouped = <String, List<db.CourseFile>>{};
    for (final f in files) {
      grouped.putIfAbsent(f.courseId, () => []).add(f);
    }

    final courseIds = grouped.keys.toList()
      ..sort((a, b) =>
          (courseNames[a] ?? '').compareTo(courseNames[b] ?? ''));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: courseIds.length,
      itemBuilder: (context, i) {
        final courseId = courseIds[i];
        final courseName = courseNames[courseId] ?? '未知课程';
        final courseFiles = grouped[courseId]!;
        final isCollapsed = _collapsedCourses.contains(courseId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Course header — tappable to expand/collapse
            GestureDetector(
              onTap: () {
                setState(() {
                  if (isCollapsed) {
                    _collapsedCourses.remove(courseId);
                  } else {
                    _collapsedCourses.add(courseId);
                  }
                });
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: EdgeInsets.only(bottom: 8, top: i > 0 ? 8 : 0),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? AppColors.darkBorder
                        : AppColors.lightBorder,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: isCollapsed ? -0.25 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.folder_rounded,
                        size: 18, color: AppColors.primary.withAlpha(180)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        courseName,
                        style: AppTypography.titleSmall
                            .copyWith(color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(isDark ? 40 : 25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${courseFiles.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate(delay: (60 * i).ms).fadeIn(duration: 200.ms),

            // Files under this course
            if (!isCollapsed)
              ...courseFiles.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SwipeToRead(
                        onRead: () => _markRead(e.value),
                        child: FileCard(
                          file: e.value,
                          courseName: courseName,
                          hideCourseName: true,
                          onTap: () {
                            _markRead(e.value);
                            context.push(Routes.fileDetail(
                              fileId: e.value.id,
                              courseId: courseId,
                              courseName: courseName,
                            ));
                          },
                        ),
                      ),
                    )
                        .animate(delay: (30 * e.key).ms)
                        .fadeIn(duration: 200.ms),
                  ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
//  Sort pills
// ---------------------------------------------------------------------------

class _SortPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _SortPill({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withAlpha(isDark ? 40 : 25)
              : isDark
                  ? AppColors.darkSurfaceHigh
                  : AppColors.lightSurfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: AppColors.primary.withAlpha(80), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 14,
                color: isActive
                    ? AppColors.primary
                    : isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive
                    ? AppColors.primary
                    : isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Type filter chips
// ---------------------------------------------------------------------------

class _TypeChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _TypeChip({
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withAlpha(isDark ? 40 : 25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.primary.withAlpha(80)
                : isDark
                    ? AppColors.darkBorder
                    : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? AppColors.primary
                : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }
}
