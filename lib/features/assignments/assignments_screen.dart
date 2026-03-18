/// Assignments screen — dashboard panel + filterable homework list.
///
/// Panel: 4 stat cards (pending, submitted, graded, overdue)
/// Filter: all / pending / submitted / graded chips
/// List: grouped by deadline urgency
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/database/database.dart';
import '../../core/router/router.dart';

// ---------------------------------------------------------------------------
//  Filter enum
// ---------------------------------------------------------------------------

enum HomeworkFilter { all, pending, submitted, graded }

final _homeworkFilterProvider =
    StateProvider<HomeworkFilter>((ref) => HomeworkFilter.all);

// ---------------------------------------------------------------------------
//  Homework list provider
// ---------------------------------------------------------------------------

final _homeworkListProvider = FutureProvider<List<Homework>>((ref) async {
  final db = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) return [];

  final courses = await db.getCoursesBySemester(semesterId);
  final allHomeworks = <Homework>[];
  for (final c in courses) {
    allHomeworks.addAll(await db.getHomeworksByCourse(c.id));
  }

  // Sort by deadline descending (newest first)
  allHomeworks.sort((a, b) => b.deadline.compareTo(a.deadline));
  return allHomeworks;
});

// ---------------------------------------------------------------------------
//  Course name map
// ---------------------------------------------------------------------------

final _courseNameMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) return {};

  final courses = await db.getCoursesBySemester(semesterId);
  return {for (final c in courses) c.id: c.name};
});

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final filter = ref.watch(_homeworkFilterProvider);
    final homeworkAsync = ref.watch(_homeworkListProvider);
    final courseNameAsync = ref.watch(_courseNameMapProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            floating: true,
            snap: true,
            title: Text(
              '作业',
              style: AppTypography.headlineMedium.copyWith(color: textColor),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: homeworkAsync.when(
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
                          style: AppTypography.titleMedium.copyWith(
                              color: textColor)),
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
              data: (allHomeworks) {
                final courseNames =
                    courseNameAsync.valueOrNull ?? <String, String>{};

                // Count stats
                final now = DateTime.now();
                int pending = 0, submitted = 0, graded = 0, overdue = 0;
                for (final hw in allHomeworks) {
                  if (hw.graded) {
                    graded++;
                  } else if (hw.submitted) {
                    submitted++;
                  } else {
                    pending++;
                    final ms = int.tryParse(hw.deadline);
                    if (ms != null &&
                        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(now)) {
                      overdue++;
                    }
                  }
                }

                // Filter
                final filtered = allHomeworks.where((hw) {
                  switch (filter) {
                    case HomeworkFilter.pending:
                      return !hw.submitted && !hw.graded;
                    case HomeworkFilter.submitted:
                      return hw.submitted && !hw.graded;
                    case HomeworkFilter.graded:
                      return hw.graded;
                    case HomeworkFilter.all:
                      return true;
                  }
                }).toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Dashboard Panel ──
                    _DashboardPanel(
                      pending: pending,
                      submitted: submitted,
                      graded: graded,
                      overdue: overdue,
                      isDark: isDark,
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 20),

                    // ── Filter Chips ──
                    _FilterRow(
                      current: filter,
                      onChanged: (f) => ref
                          .read(_homeworkFilterProvider.notifier)
                          .state = f,
                      isDark: isDark,
                    ),

                    const SizedBox(height: 16),

                    // ── Homework List ──
                    if (filtered.isEmpty)
                      _buildEmpty(isDark)
                    else
                      ...filtered.asMap().entries.map((e) {
                        final hw = e.value;
                        final courseName =
                            courseNames[hw.courseId] ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _HomeworkCard(
                            hw: hw,
                            courseName: courseName,
                            isDark: isDark,
                            onTap: () => context.push(
                              Routes.homeworkDetail(
                                homeworkId: hw.id,
                                courseId: hw.courseId,
                                courseName: courseName,
                              ),
                            ),
                          )
                              .animate(delay: (50 * e.key).ms)
                              .fadeIn(duration: 250.ms)
                              .slideX(begin: 0.03, end: 0),
                        );
                      }),
                  ]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final color =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: color),
            const SizedBox(height: 12),
            Text('暂无作业',
                style: AppTypography.titleMedium.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Dashboard Panel
// ---------------------------------------------------------------------------

class _DashboardPanel extends StatelessWidget {
  final int pending, submitted, graded, overdue;
  final bool isDark;

  const _DashboardPanel({
    required this.pending,
    required this.submitted,
    required this.graded,
    required this.overdue,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          _MiniStat(
              value: pending.toString(),
              label: '待交',
              color: pending > 0 ? AppColors.warning : AppColors.success,
              textColor: textColor,
              subColor: subColor),
          _MiniStat(
              value: submitted.toString(),
              label: '已交',
              color: AppColors.info,
              textColor: textColor,
              subColor: subColor),
          _MiniStat(
              value: graded.toString(),
              label: '已批',
              color: AppColors.success,
              textColor: textColor,
              subColor: subColor),
          _MiniStat(
              value: overdue.toString(),
              label: '超期',
              color: overdue > 0 ? AppColors.error : AppColors.success,
              textColor: textColor,
              subColor: subColor),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final Color textColor;
  final Color subColor;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTypography.statMedium.copyWith(color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: AppTypography.bodySmall.copyWith(color: subColor)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Filter Row
// ---------------------------------------------------------------------------

class _FilterRow extends StatelessWidget {
  final HomeworkFilter current;
  final ValueChanged<HomeworkFilter> onChanged;
  final bool isDark;

  const _FilterRow({
    required this.current,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: HomeworkFilter.values.map((f) {
          final isSelected = f == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_label(f)),
              selected: isSelected,
              onSelected: (_) => onChanged(f),
              selectedColor: AppColors.primary.withAlpha(30),
              labelStyle: AppTypography.labelSmall.copyWith(
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.lightTextSecondary),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: isSelected
                    ? BorderSide(color: AppColors.primary.withAlpha(60))
                    : BorderSide.none,
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  String _label(HomeworkFilter f) => switch (f) {
        HomeworkFilter.all => '全部',
        HomeworkFilter.pending => '待提交',
        HomeworkFilter.submitted => '已提交',
        HomeworkFilter.graded => '已批改',
      };
}

// ---------------------------------------------------------------------------
//  Homework Card
// ---------------------------------------------------------------------------

class _HomeworkCard extends StatelessWidget {
  final Homework hw;
  final String courseName;
  final bool isDark;
  final VoidCallback? onTap;

  const _HomeworkCard({
    required this.hw,
    required this.courseName,
    required this.isDark,
    this.onTap,
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

    final statusColor = _statusColor();
    final statusText = _statusText();

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Course + status
          Row(
            children: [
              Expanded(
                child: Text(
                  courseName,
                  style: AppTypography.labelSmall
                      .copyWith(color: subColor, letterSpacing: 0.3),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusText,
                  style: AppTypography.labelSmall.copyWith(
                    color: statusColor,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Title
          Text(
            hw.title,
            style: AppTypography.titleMedium.copyWith(color: textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 8),

          // Bottom row: deadline + grade
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 14, color: tertiaryColor),
              const SizedBox(width: 4),
              Text(
                _formatDeadline(),
                style: AppTypography.bodySmall.copyWith(color: tertiaryColor),
              ),
              if (hw.graded && hw.grade != null) ...[
                const Spacer(),
                Text(
                  '${hw.grade}',
                  style: AppTypography.titleSmall.copyWith(
                    color: _gradeColor(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (hw.graded && hw.gradeContent != null && hw.gradeContent!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hw.gradeContent!,
                    style: AppTypography.bodySmall.copyWith(
                      color: subColor,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    )),
    );
  }

  Color _statusColor() {
    if (hw.graded) return AppColors.success;
    if (hw.submitted) return AppColors.info;
    // Check if overdue
    final ms = int.tryParse(hw.deadline);
    if (ms != null &&
        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now())) {
      return AppColors.error;
    }
    return AppColors.warning;
  }

  String _statusText() {
    if (hw.graded) return '已批改';
    if (hw.submitted) return '已提交';
    final ms = int.tryParse(hw.deadline);
    if (ms != null &&
        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now())) {
      return '已超期';
    }
    return '待提交';
  }

  String _formatDeadline() {
    final ms = int.tryParse(hw.deadline);
    if (ms == null) return hw.deadline;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Color _gradeColor() {
    // We DON'T know the max score, so we can't assume 百分制.
    // Use a neutral positive color for any numeric grade.
    if (hw.grade == null) return AppColors.success;
    return AppColors.primary;
  }
}
