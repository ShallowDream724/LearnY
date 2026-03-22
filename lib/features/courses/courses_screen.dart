// Courses screen — grid of course cards with notification badges.
//
// Each card shows: course name, teacher, unread count badge,
// pending homework indicator, and latest activity.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/responsive.dart';
import '../../core/design/typography.dart';
import '../../core/providers/sync_models.dart';
import '../../core/router/router.dart';
import '../../core/sync/sync_actions.dart';
import 'providers/course_queries.dart';

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final statsAsync = ref.watch(courseStatsProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final ss = (await ref.read(syncActionsProvider).refreshAll()).state;
          if (ss.status == SyncStatus.cooldown && context.mounted) {
            CooldownToast.show(context, seconds: ss.cooldownSeconds);
          }
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
                style: AppTypography.headlineMedium.copyWith(color: c.text),
              ),
            ),

            // ── Content ──
            statsAsync.when(
              skipLoadingOnReload: true,
              skipLoadingOnRefresh: true,
              loading: () => const SliverFillRemaining(child: ListSkeleton()),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 48,
                        color: c.subtitle,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '加载失败',
                        style: AppTypography.titleMedium.copyWith(
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请下拉刷新重试',
                        style: AppTypography.bodySmall.copyWith(
                          color: c.tertiary,
                        ),
                      ),
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
                          Icon(
                            Icons.school_outlined,
                            size: 48,
                            color: c.tertiary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无课程',
                            style: AppTypography.titleMedium.copyWith(
                              color: c.tertiary,
                            ),
                          ),
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
                            child:
                                _CourseCard(
                                      stats: stats[index],
                                      colorIndex: index,
                                    )
                                    .animate(delay: (60 * index).ms)
                                    .fadeIn(duration: 300.ms)
                                    .scale(
                                      begin: const Offset(0.95, 0.95),
                                      end: const Offset(1, 1),
                                    ),
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
                      childCount:
                          (stats.length + courseGridColumns(context) - 1) ~/
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
  final int colorIndex;

  const _CourseCard({required this.stats, required this.colorIndex});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final accent = _cardColors[colorIndex % _cardColors.length];
    final course = stats.course;
    final hasBadge =
        stats.unreadNotifications > 0 || stats.pendingHomeworks > 0;

    return Material(
      color: c.surface,
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
            border: Border.all(color: c.border, width: 0.5),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
                style: AppTypography.titleMedium.copyWith(color: c.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Teacher
              Text(
                course.teacherName,
                style: AppTypography.bodySmall.copyWith(color: c.subtitle),
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
                        : c.tertiary,
                  ),
                  const SizedBox(width: 12),
                  _MicroStat(
                    icon: Icons.assignment_outlined,
                    count: stats.pendingHomeworks,
                    color: stats.pendingHomeworks > 0
                        ? AppColors.warning
                        : c.tertiary,
                  ),
                  const SizedBox(width: 12),
                  _MicroStat(
                    icon: Icons.folder_outlined,
                    count: stats.totalFiles,
                    color: c.tertiary,
                  ),
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
