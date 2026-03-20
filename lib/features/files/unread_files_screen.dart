/// UnreadFilesScreen — full list of all unread files with
/// search, sort (by time / by course), and file-type filter.
///
/// Accessed from home screen "查看全部" button.
library;

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/swipe_to_read.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
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
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncStateProvider.notifier).syncFilesOnly();
          final ss = ref.read(syncStateProvider);
          if (ss.status == SyncStatus.cooldown && context.mounted) {
            CooldownToast.show(context, seconds: ss.cooldownSeconds);
          }
        },
        color: AppColors.primary,
        child: filesAsync.when(
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

              // ── Sort toggle + type filter ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
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
                    Container(
                      width: 1,
                      height: 24,
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                    const SizedBox(width: 12),
                    _TypeFilterButton(
                      currentFilter: _typeFilter,
                      types: types,
                      allFiles: allFiles,
                      isDark: isDark,
                      onChanged: (v) => setState(() => _typeFilter = v),
                    ),
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
          key: ValueKey(f.id),
          padding: const EdgeInsets.only(bottom: 8),
          child: SwipeToRead(
            key: ValueKey('swipe_${f.id}'),
            exitOnSwipe: true,
            onSwipe: () => _markRead(f),
            child: FileCard(
              file: f,
              courseName: courseNames[f.courseId] ?? '',
              onTap: () {
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
                        key: ValueKey('swipe_${e.value.id}'),
                        exitOnSwipe: true,
                        onSwipe: () => _markRead(e.value),
                        child: FileCard(
                          file: e.value,
                          courseName: courseName,
                          hideCourseName: true,
                          onTap: () {
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
//  Type filter — compact pill + premium popup
// ---------------------------------------------------------------------------

class _TypeFilterButton extends StatefulWidget {
  final String? currentFilter;
  final Set<String> types;
  final List<db.CourseFile> allFiles;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _TypeFilterButton({
    required this.currentFilter,
    required this.types,
    required this.allFiles,
    required this.isDark,
    required this.onChanged,
  });

  @override
  State<_TypeFilterButton> createState() => _TypeFilterButtonState();
}

class _TypeFilterButtonState extends State<_TypeFilterButton> {
  final _buttonKey = GlobalKey();

  void _showMenu() {
    final renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Count files per type
    final counts = <String, int>{};
    for (final f in widget.allFiles) {
      final ext = _extractExt(f.title, f.fileType);
      if (ext.isNotEmpty) {
        counts[ext] = (counts[ext] ?? 0) + 1;
      }
    }

    final sorted = widget.types.toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));

    Navigator.of(context).push(
      _TypeFilterPopupRoute(
        buttonRect: Rect.fromLTWH(
          offset.dx,
          offset.dy + size.height + 8,
          size.width,
          size.height,
        ),
        types: sorted,
        counts: counts,
        currentFilter: widget.currentFilter,
        isDark: widget.isDark,
        totalCount: widget.allFiles.length,
        onSelected: (type) {
          widget.onChanged(type);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  static String _extractExt(String title, String fileType) {
    if (fileType.isNotEmpty) return fileType.toLowerCase();
    final dot = title.lastIndexOf('.');
    if (dot != -1 && dot < title.length - 1) {
      return title.substring(dot + 1).toLowerCase();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final isFiltered = widget.currentFilter != null;
    final label = isFiltered
        ? widget.currentFilter!.toUpperCase()
        : '全部类型';

    return GestureDetector(
      key: _buttonKey,
      onTap: _showMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isFiltered
              ? AppColors.primary.withAlpha(widget.isDark ? 40 : 25)
              : widget.isDark
                  ? AppColors.darkSurfaceHigh
                  : AppColors.lightSurfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: isFiltered
              ? Border.all(color: AppColors.primary.withAlpha(80), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              size: 14,
              color: isFiltered
                  ? AppColors.primary
                  : widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isFiltered ? FontWeight.w600 : FontWeight.w500,
                color: isFiltered
                    ? AppColors.primary
                    : widget.isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isFiltered
                  ? AppColors.primary
                  : widget.isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.lightTextTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Custom popup route — frosted glass overlay
// ---------------------------------------------------------------------------

class _TypeFilterPopupRoute extends PopupRoute<void> {
  final Rect buttonRect;
  final List<String> types;
  final Map<String, int> counts;
  final String? currentFilter;
  final bool isDark;
  final int totalCount;
  final ValueChanged<String?> onSelected;

  _TypeFilterPopupRoute({
    required this.buttonRect,
    required this.types,
    required this.counts,
    required this.currentFilter,
    required this.isDark,
    required this.totalCount,
    required this.onSelected,
  });

  @override
  Color? get barrierColor => Colors.black.withAlpha(30);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  static Color _extColor(String ext) {
    return switch (ext) {
      'pdf' => const Color(0xFFE53935),
      'doc' || 'docx' => const Color(0xFF1565C0),
      'xls' || 'xlsx' => const Color(0xFF2E7D32),
      'ppt' || 'pptx' => const Color(0xFFE65100),
      'zip' || 'rar' || '7z' => const Color(0xFF6A1B9A),
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' => const Color(0xFF00838F),
      'mp4' || 'mov' || 'avi' => const Color(0xFFAD1457),
      'txt' || 'md' => const Color(0xFF546E7A),
      _ => const Color(0xFF757575),
    };
  }

  static IconData _extIcon(String ext) {
    return switch (ext) {
      'pdf' => Icons.picture_as_pdf_rounded,
      'doc' || 'docx' => Icons.description_rounded,
      'xls' || 'xlsx' => Icons.table_chart_rounded,
      'ppt' || 'pptx' => Icons.slideshow_rounded,
      'zip' || 'rar' || '7z' => Icons.folder_zip_rounded,
      'png' || 'jpg' || 'jpeg' || 'gif' || 'svg' => Icons.image_rounded,
      'mp4' || 'mov' || 'avi' => Icons.videocam_rounded,
      'txt' || 'md' => Icons.text_snippet_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      ),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.92, end: 1.0).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
          ),
        ),
        alignment: Alignment.topLeft,
        child: child,
      ),
    );
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    final mq = MediaQuery.of(context);
    final menuWidth = 220.0;

    // Position: align left with button, clamp to screen
    var left = buttonRect.left;
    if (left + menuWidth > mq.size.width - 16) {
      left = mq.size.width - menuWidth - 16;
    }
    if (left < 16) left = 16;

    final surface = isDark
        ? const Color(0xFF1C1C1E) // iOS dark elevated surface
        : const Color(0xFFF9F9FB);
    final textPrimary =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final textSecondary =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final dividerColor =
        isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10);

    return Stack(
      children: [
        Positioned(
          left: left,
          top: buttonRect.top,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                width: menuWidth,
                constraints: BoxConstraints(
                  maxHeight: mq.size.height - buttonRect.top - 32,
                ),
                decoration: BoxDecoration(
                  color: surface.withAlpha(isDark ? 230 : 245),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 60 : 25),
                      blurRadius: 30,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 30 : 10),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // "All" option
                        _menuItem(
                          label: '全部类型',
                          count: totalCount,
                          icon: Icons.layers_rounded,
                          iconColor: AppColors.primary,
                          isSelected: currentFilter == null,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onTap: () => onSelected(null),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Divider(
                            height: 1,
                            thickness: 0.5,
                            color: dividerColor,
                          ),
                        ),
                        // Type items
                        ...types.map((t) => _menuItem(
                              label: t.toUpperCase(),
                              count: counts[t] ?? 0,
                              icon: _extIcon(t),
                              iconColor: _extColor(t),
                              isSelected: currentFilter == t,
                              textPrimary: textPrimary,
                              textSecondary: textSecondary,
                              onTap: () => onSelected(t),
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required String label,
    required int count,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(isDark ? 35 : 20),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: textPrimary,
                  letterSpacing: label == '全部类型' ? 0 : 0.5,
                ),
              ),
            ),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            if (isSelected)
              Icon(Icons.check_rounded, size: 16, color: AppColors.primary)
            else
              const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}

