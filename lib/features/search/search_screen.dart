/// Global search screen — search across all courses' content.
///
/// UX Design Decisions:
///
/// 1. **Search-as-you-type** with 300ms debounce: responsive but not wasteful.
///    Searches local DB (Drift) so it's fast even offline.
///
/// 2. **Multi-category results**: grouped into courses, notifications, homework,
///    and files — each with a visual section header and distinct card style.
///    The user can immediately see which category the result belongs to.
///
/// 3. **Recent searches**: persisted in AppState (key-value store).
///    Shows up when the search field is empty, with a clear-all option.
///
/// 4. **Empty states**: differentiated between "start searching" (search icon),
///    "no results" (with suggestion), and "loading" states.
///
/// 5. **Result count badges**: each category header shows the count,
///    helping users gauge result distribution at a glance.
///
/// 6. **Navigation**: tapping a result navigates to the appropriate detail page.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/colors.dart';
import '../../core/design/responsive.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/providers/providers.dart';
import '../../core/router/router.dart';

// ---------------------------------------------------------------------------
//  Search result model
// ---------------------------------------------------------------------------

enum SearchCategory { course, notification, homework, file }

class SearchResult {
  final SearchCategory category;
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const SearchResult({
    required this.category,
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<SearchResult> _results = [];
  List<String> _recentSearches = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    // Auto-focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final database = ref.read(databaseProvider);
    final semesterId = ref.read(currentSemesterIdProvider);
    if (semesterId == null) {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
      });
      return;
    }

    final results = <SearchResult>[];
    final lowerQuery = query.toLowerCase();

    // Search courses
    final courses = await database.getCoursesBySemester(semesterId);
    for (final c in courses) {
      if (c.name.toLowerCase().contains(lowerQuery) ||
          (c.teacherName?.toLowerCase().contains(lowerQuery) ?? false)) {
        results.add(SearchResult(
          category: SearchCategory.course,
          id: c.id,
          courseId: c.id,
          courseName: c.name,
          title: c.name,
          subtitle: c.teacherName ?? '',
          icon: Icons.school_rounded,
          accentColor: AppColors.primary,
        ));
      }
    }

    // Search across all courses' content
    for (final c in courses) {
      // Notifications
      final notifications = await database.getNotificationsByCourse(c.id);
      for (final n in notifications) {
        if (n.title.toLowerCase().contains(lowerQuery) ||
            n.content.toLowerCase().contains(lowerQuery)) {
          results.add(SearchResult(
            category: SearchCategory.notification,
            id: n.id,
            courseId: c.id,
            courseName: c.name,
            title: n.title,
            subtitle: c.name,
            icon: Icons.notifications_rounded,
            accentColor: AppColors.info,
          ));
        }
      }

      // Homework
      final homeworks = await database.getHomeworksByCourse(c.id);
      for (final hw in homeworks) {
        if (hw.title.toLowerCase().contains(lowerQuery) ||
            (hw.description?.toLowerCase().contains(lowerQuery) ?? false)) {
          results.add(SearchResult(
            category: SearchCategory.homework,
            id: hw.id,
            courseId: c.id,
            courseName: c.name,
            title: hw.title,
            subtitle: c.name,
            icon: Icons.assignment_rounded,
            accentColor: AppColors.warning,
          ));
        }
      }

      // Files
      final files = await database.getFilesByCourse(c.id);
      for (final f in files) {
        if (f.title.toLowerCase().contains(lowerQuery) ||
            f.description.toLowerCase().contains(lowerQuery)) {
          results.add(SearchResult(
            category: SearchCategory.file,
            id: f.id,
            courseId: c.id,
            courseName: c.name,
            title: f.title,
            subtitle: '${c.name} · ${f.size}',
            icon: Icons.insert_drive_file_rounded,
            accentColor: const Color(0xFF8B5CF6),
          ));
        }
      }
    }

    // Save to recent
    _addToRecent(query);

    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }

  // ── Recent searches ──

  Future<void> _loadRecentSearches() async {
    final database = ref.read(databaseProvider);
    final raw = await database.getState('recent_searches');
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      setState(() {
        _recentSearches = list.cast<String>();
      });
    }
  }

  Future<void> _addToRecent(String query) async {
    final database = ref.read(databaseProvider);
    _recentSearches.remove(query);
    _recentSearches.insert(0, query);
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10);
    }
    await database.setState(
        'recent_searches', jsonEncode(_recentSearches));
  }

  Future<void> _clearRecent() async {
    final database = ref.read(databaseProvider);
    setState(() => _recentSearches = []);
    await database.setState('recent_searches', '[]');
  }

  void _onRecentTap(String query) {
    _controller.text = query;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: query.length));
    _onSearchChanged(query);
  }

  void _onResultTap(SearchResult result) {
    switch (result.category) {
      case SearchCategory.course:
        context.go(Routes.courseDetail(result.courseId));
      case SearchCategory.notification:
        context.push(Routes.notificationDetail(
          notificationId: result.id,
          courseId: result.courseId,
          courseName: result.courseName,
        ));
      case SearchCategory.homework:
        context.push(Routes.homeworkDetail(
          homeworkId: result.id,
          courseId: result.courseId,
          courseName: result.courseName,
        ));
      case SearchCategory.file:
        // Navigate to the course detail with files tab
        context.go(Routes.courseDetail(result.courseId));
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: _SearchField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          isDark: isDark,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: subColor, size: 20),
              onPressed: () {
                _controller.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: ResponsiveContent(
        child: _buildBody(
            isDark, textColor, subColor, tertiaryColor, surface, border),
      ),
    );
  }

  Widget _buildBody(bool isDark, Color textColor, Color subColor,
      Color tertiaryColor, Color surface, Color border) {
    // Loading
    if (_isSearching) {
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
            Text('搜索中...', style: AppTypography.bodySmall.copyWith(color: tertiaryColor)),
          ],
        ),
      );
    }

    // No query yet — show recent searches
    if (!_hasSearched) {
      return _buildRecentSearches(
          isDark, textColor, subColor, tertiaryColor, surface, border);
    }

    // No results
    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48, color: tertiaryColor),
            const SizedBox(height: 12),
            Text('未找到相关内容',
                style:
                    AppTypography.titleMedium.copyWith(color: subColor)),
            const SizedBox(height: 6),
            Text('试试其他关键词',
                style: AppTypography.bodySmall
                    .copyWith(color: tertiaryColor)),
          ],
        ),
      );
    }

    // Results grouped by category
    return _buildResults(
        isDark, textColor, subColor, tertiaryColor, surface, border);
  }

  // ── Recent searches ──

  Widget _buildRecentSearches(bool isDark, Color textColor, Color subColor,
      Color tertiaryColor, Color surface, Color border) {
    if (_recentSearches.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_rounded, size: 48, color: tertiaryColor),
            const SizedBox(height: 12),
            Text('搜索课程、通知、作业、文件',
                style: AppTypography.bodyMedium
                    .copyWith(color: tertiaryColor)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          children: [
            Text('最近搜索',
                style:
                    AppTypography.labelMedium.copyWith(color: subColor)),
            const Spacer(),
            GestureDetector(
              onTap: _clearRecent,
              child: Text('清除',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _recentSearches.map((q) {
            return Material(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () => _onRecentTap(q),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Text(q,
                      style: AppTypography.bodySmall
                          .copyWith(color: textColor)),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ── Search results ──

  Widget _buildResults(bool isDark, Color textColor, Color subColor,
      Color tertiaryColor, Color surface, Color border) {
    // Group by category
    final grouped = <SearchCategory, List<SearchResult>>{};
    for (final r in _results) {
      grouped.putIfAbsent(r.category, () => []).add(r);
    }

    final categoryOrder = [
      SearchCategory.course,
      SearchCategory.notification,
      SearchCategory.homework,
      SearchCategory.file,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // Total results count
        Text(
          '找到 ${_results.length} 个结果',
          style: AppTypography.bodySmall.copyWith(color: tertiaryColor),
        )
            .animate()
            .fadeIn(duration: 200.ms),
        const SizedBox(height: 16),

        for (final category in categoryOrder)
          if (grouped.containsKey(category)) ...[
            _CategoryHeader(
              category: category,
              count: grouped[category]!.length,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            ...grouped[category]!.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _onResultTap(result),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        // Category icon
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: result.accentColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(result.icon,
                              size: 17, color: result.accentColor),
                        ),
                        const SizedBox(width: 12),

                        // Title + subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                result.title,
                                style: AppTypography.titleSmall
                                    .copyWith(color: textColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                result.subtitle,
                                style: AppTypography.bodySmall
                                    .copyWith(color: tertiaryColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // Chevron
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: tertiaryColor),
                      ],
                    ),
                  ),
                )
                    .animate(delay: (30 * index).ms)
                    .fadeIn(duration: 200.ms),
              );
            }),
            const SizedBox(height: 16),
          ],
      ],
    );
  }
}

// ─────────────────────────────────────────────
//  Search field
// ─────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _SearchField({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final hintColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: AppTypography.bodyMedium.copyWith(color: textColor),
        decoration: InputDecoration(
          hintText: '搜索课程、通知、作业、文件...',
          hintStyle: AppTypography.bodyMedium.copyWith(color: hintColor),
          prefixIcon:
              Icon(Icons.search_rounded, size: 20, color: hintColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Category header
// ─────────────────────────────────────────────

class _CategoryHeader extends StatelessWidget {
  final SearchCategory category;
  final int count;
  final bool isDark;

  const _CategoryHeader({
    required this.category,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    final (label, icon, color) = switch (category) {
      SearchCategory.course => ('课程', Icons.school_rounded, AppColors.primary),
      SearchCategory.notification =>
        ('通知', Icons.notifications_rounded, AppColors.info),
      SearchCategory.homework =>
        ('作业', Icons.assignment_rounded, AppColors.warning),
      SearchCategory.file =>
        ('文件', Icons.insert_drive_file_rounded, const Color(0xFF8B5CF6)),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label,
            style: AppTypography.labelMedium
                .copyWith(color: subColor, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count',
              style: AppTypography.labelSmall
                  .copyWith(color: color, fontSize: 10)),
        ),
      ],
    );
  }
}
