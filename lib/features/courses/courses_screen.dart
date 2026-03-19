/// Courses screen — grid of course cards with notification badges.
///
/// Each card shows: course name, teacher, unread count badge,
/// pending homework indicator, and latest activity.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/design/responsive.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/database/database.dart';
import '../../core/router/router.dart';

// ---------------------------------------------------------------------------
//  Course stats
// ---------------------------------------------------------------------------

class CourseStats {
  final Course course;
  final int unreadNotifications;
  final int pendingHomeworks;
  final int totalFiles;

  const CourseStats({
    required this.course,
    this.unreadNotifications = 0,
    this.pendingHomeworks = 0,
    this.totalFiles = 0,
  });
}

final _courseStatsProvider = FutureProvider<List<CourseStats>>((ref) async {
  final db = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) return [];

  final courses = await db.getCoursesBySemester(semesterId);
  final stats = <CourseStats>[];

  for (final c in courses) {
    final notifications = await db.getNotificationsByCourse(c.id);
    final homeworks = await db.getHomeworksByCourse(c.id);
    final files = await db.getFilesByCourse(c.id);

    final unread = notifications.where((n) => !n.hasRead && !n.hasReadLocal).length;
    final pending = homeworks.where((h) => !h.submitted && !h.graded).length;

    stats.add(CourseStats(
      course: c,
      unreadNotifications: unread,
      pendingHomeworks: pending,
      totalFiles: files.length,
    ));
  }

  // Sort: put courses with pending items first
  stats.sort((a, b) {
    final aScore = a.unreadNotifications + a.pendingHomeworks * 2;
    final bScore = b.unreadNotifications + b.pendingHomeworks * 2;
    return bScore.compareTo(aScore);
  });

  return stats;
});

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final statsAsync = ref.watch(_courseStatsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncStateProvider.notifier).syncAll();
          ref.invalidate(_courseStatsProvider);
        },
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text(
              '课程',
              style: AppTypography.headlineMedium.copyWith(color: textColor),
            ),
          ),

          // ── Content ──
          statsAsync.when(
            loading: () => const SliverFillRemaining(
              child: ListSkeleton(),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded,
                        size: 48,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                    const SizedBox(height: 12),
                    Text('加载失败',
                        style: AppTypography.titleMedium
                            .copyWith(color: textColor)),
                    const SizedBox(height: 8),
                    Text('请下拉刷新重试',
                        style: AppTypography.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary)),
                  ],
                ),
              ),
            ),
            data: (stats) {
              if (stats.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.school_outlined,
                            size: 48,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.lightTextTertiary),
                        const SizedBox(height: 12),
                        Text('暂无课程',
                            style: AppTypography.titleMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.lightTextTertiary,
                            )),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, rowIndex) {
                      final cols = courseGridColumns(context);
                      final i1 = rowIndex * cols;
                      final i2 = i1 + 1;
                      final hasSecond = cols > 1 && i2 < stats.length;

                      Widget card(int index) {
                        return Expanded(
                          child: _CourseCard(
                            stats: stats[index],
                            isDark: isDark,
                            colorIndex: index,
                          )
                              .animate(delay: (60 * index).ms)
                              .fadeIn(duration: 300.ms)
                              .scale(
                                  begin: const Offset(0.95, 0.95),
                                  end: const Offset(1, 1)),
                        );
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              card(i1),
                              if (hasSecond) ...[
                                const SizedBox(width: 10),
                                card(i2),
                              ] else if (cols > 1)
                                const Expanded(child: SizedBox()),
                            ],
                          ),
                        ),
                      );
                    },
                    childCount: (stats.length + courseGridColumns(context) - 1) ~/
                        courseGridColumns(context),
                  ),
                ),
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Course Card
// ---------------------------------------------------------------------------

/// Predefined card accent colors.
const _cardColors = [
  AppColors.primary,
  Color(0xFF06B6D4), // cyan
  Color(0xFF8B5CF6), // violet
  Color(0xFFEC4899), // pink
  Color(0xFFF97316), // orange
  Color(0xFF14B8A6), // teal
  Color(0xFF6366F1), // indigo
  Color(0xFFEAB308), // yellow
];

class _CourseCard extends StatelessWidget {
  final CourseStats stats;
  final bool isDark;
  final int colorIndex;

  const _CourseCard({
    required this.stats,
    required this.isDark,
    required this.colorIndex,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;

    final accent = _cardColors[colorIndex % _cardColors.length];
    final course = stats.course;
    final hasBadge = stats.unreadNotifications > 0 || stats.pendingHomeworks > 0;

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          context.go(Routes.courseDetail(stats.course.id));
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: accent bar + badge
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withAlpha(180)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _initials(course.name),
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                if (hasBadge)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.unreadBadge,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${stats.unreadNotifications + stats.pendingHomeworks}',
                      style: AppTypography.labelSmall.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Course name
            Text(
              course.name,
              style: AppTypography.titleMedium.copyWith(color: textColor),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Teacher
            Text(
              course.teacherName ?? '',
              style: AppTypography.bodySmall.copyWith(color: subColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 8),

            // Bottom stats row
            Row(
              children: [
                _MicroStat(
                    icon: Icons.notifications_none_rounded,
                    count: stats.unreadNotifications,
                    color: stats.unreadNotifications > 0
                        ? AppColors.info
                        : tertiaryColor),
                const SizedBox(width: 12),
                _MicroStat(
                    icon: Icons.assignment_outlined,
                    count: stats.pendingHomeworks,
                    color: stats.pendingHomeworks > 0
                        ? AppColors.warning
                        : tertiaryColor),
                const SizedBox(width: 12),
                _MicroStat(
                    icon: Icons.folder_outlined,
                    count: stats.totalFiles,
                    color: tertiaryColor),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '';
    // For Chinese names, take first character
    // For English names, take first two letters
    final chars = name.runes.toList();
    if (chars.isNotEmpty && chars[0] > 127) {
      return String.fromCharCode(chars[0]);
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _MicroStat extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _MicroStat({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          count.toString(),
          style: AppTypography.bodySmall.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
