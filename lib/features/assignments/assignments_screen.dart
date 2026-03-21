/// Assignments screen — timeline-grouped homework list.
///
/// Design: assignments grouped by deadline proximity:
///   本周截止 → 下周截止 → 更远 → 已完成
/// Left-side timeline connector with urgency dots.
///
/// Architecture:
///   - Providers          : data fetching + filtering
///   - _TimeGroup enum    : grouping logic
///   - _StatsStrip        : compact stats bar
///   - _FilterRow         : filter pills
///   - _TimelineSection   : group header + connector + children
///   - _HomeworkItem      : individual assignment card
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart';
import '../../core/providers/sync_models.dart';
import '../../core/router/router.dart';
import '../../core/sync/sync_actions.dart';
import '../../core/utils/deadline_time.dart';
import 'providers/assignments_providers.dart';

class _GroupMeta {
  final String label;
  final Color color;
  _GroupMeta(this.label, this.color);
}

_GroupMeta _groupMeta(AssignmentTimelineGroup g) => switch (g) {
  AssignmentTimelineGroup.thisWeek => _GroupMeta(
    '本周截止',
    const Color(0xFFFF3B30),
  ),
  AssignmentTimelineGroup.nextWeek => _GroupMeta(
    '下周截止',
    const Color(0xFFFF9500),
  ),
  AssignmentTimelineGroup.later => _GroupMeta('更远', const Color(0xFF007AFF)),
  AssignmentTimelineGroup.done => _GroupMeta('已完成', const Color(0xFF34C759)),
};

// ═══════════════════════════════════════════════════════════════════════════
//  Screen
// ═══════════════════════════════════════════════════════════════════════════

class AssignmentsScreen extends ConsumerWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final filter = ref.watch(homeworkFilterProvider);
    final homeworkAsync = ref.watch(assignmentHomeworksProvider);
    final courseNameAsync = ref.watch(assignmentCourseNameMapProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final ss =
              (await ref.read(syncActionsProvider).refreshHomeworksOnly())
                  .state;
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
                '作业',
                style: AppTypography.headlineMedium.copyWith(color: c.text),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: homeworkAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                loading: () => const SliverFillRemaining(child: ListSkeleton()),
                error: (e, _) => _buildError(context),
                data: (allHomeworks) {
                  final courseNames =
                      courseNameAsync.valueOrNull ?? <String, String>{};
                  final presentation = buildAssignmentsPresentation(
                    homeworks: allHomeworks,
                    filter: filter,
                  );

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // Stats strip
                      _StatsStrip(
                        stats: presentation.stats,
                      ).animate().fadeIn(duration: 300.ms),
                      const SizedBox(height: 16),

                      // Filter pills
                      _FilterRow(
                        current: filter,
                        onChanged: (f) =>
                            ref.read(homeworkFilterProvider.notifier).state = f,
                      ),
                      const SizedBox(height: 20),

                      // Timeline groups
                      if (presentation.isEmpty)
                        _buildEmpty(context)
                      else
                        ...presentation.sections.map(
                          (section) => _TimelineSection(
                            group: section.group,
                            homeworks: section.homeworks,
                            courseNames: courseNames,
                            onTapItem: (hw) {
                              final name = courseNames[hw.courseId] ?? '';
                              context.push(
                                Routes.homeworkDetail(
                                  homeworkId: hw.id,
                                  courseId: hw.courseId,
                                  courseName: name,
                                ),
                              );
                            },
                          ),
                        ),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  SliverFillRemaining _buildError(BuildContext context) {
    final c = context.colors;
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: c.subtitle),
            const SizedBox(height: 12),
            Text(
              '加载失败',
              style: AppTypography.titleMedium.copyWith(color: c.text),
            ),
            const SizedBox(height: 8),
            Text(
              '请下拉刷新重试',
              style: AppTypography.bodySmall.copyWith(color: c.subtitle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_rounded, size: 48, color: c.tertiary),
            const SizedBox(height: 12),
            Text(
              '暂无作业',
              style: AppTypography.titleMedium.copyWith(color: c.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Stats Strip — compact inline stats
// ═══════════════════════════════════════════════════════════════════════════

class _StatsStrip extends StatelessWidget {
  final AssignmentStats stats;

  const _StatsStrip({required this.stats});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          _StatChip(
            n: stats.pending,
            label: '待交',
            color: stats.pending > 0
                ? const Color(0xFFFF9500)
                : const Color(0xFF34C759),
            sub: c.subtitle,
          ),
          _StatChip(
            n: stats.submitted,
            label: '已交',
            color: const Color(0xFF007AFF),
            sub: c.subtitle,
          ),
          _StatChip(
            n: stats.graded,
            label: '已批',
            color: const Color(0xFF34C759),
            sub: c.subtitle,
          ),
          _StatChip(
            n: stats.overdue,
            label: '超期',
            color: stats.overdue > 0
                ? const Color(0xFFFF3B30)
                : const Color(0xFF34C759),
            sub: c.subtitle,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final int n;
  final String label;
  final Color color;
  final Color sub;

  const _StatChip({
    required this.n,
    required this.label,
    required this.color,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            n.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.2,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: sub,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Filter Row
// ═══════════════════════════════════════════════════════════════════════════

class _FilterRow extends StatelessWidget {
  final HomeworkFilter current;
  final ValueChanged<HomeworkFilter> onChanged;

  const _FilterRow({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: HomeworkFilter.values.map((f) {
          final isSelected = f == current;
          final bg = isSelected
              ? const Color(0xFF007AFF)
              : (context.isDark
                    ? const Color(0xFF2C2C2E)
                    : const Color(0xFFF5F5F7));
          final fg = isSelected
              ? Colors.white
              : (context.isDark ? c.subtitle : const Color(0xFF636366));

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (context.isDark
                              ? const Color(0xFF3A3A3C)
                              : const Color(0xFFE5E5EA)),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  _label(f),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
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

// ═══════════════════════════════════════════════════════════════════════════
//  Timeline Section — one time group with header + connector + items
// ═══════════════════════════════════════════════════════════════════════════

class _TimelineSection extends StatelessWidget {
  final AssignmentTimelineGroup group;
  final List<Homework> homeworks;
  final Map<String, String> courseNames;
  final void Function(Homework hw) onTapItem;

  const _TimelineSection({
    required this.group,
    required this.homeworks,
    required this.courseNames,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final meta = _groupMeta(group);
    final isDone = group == AssignmentTimelineGroup.done;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Group header ──
          Row(
            children: [
              // Dot with halo
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: meta.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: meta.color.withAlpha(38),
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                meta.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: meta.color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${homeworks.length} 项',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: c.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Items with timeline connector ──
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.only(left: 18),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: context.isDark
                      ? const Color(0xFF3A3A3C)
                      : const Color(0xFFE5E5EA),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: homeworks.asMap().entries.map((entry) {
                final hw = entry.value;
                final courseName = courseNames[hw.courseId] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _HomeworkItem(
                    hw: hw,
                    courseName: courseName,
                    isDone: isDone,
                    onTap: () => onTapItem(hw),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Homework Item — compact timeline card
// ═══════════════════════════════════════════════════════════════════════════

class _HomeworkItem extends StatelessWidget {
  final Homework hw;
  final String courseName;
  final bool isDone;
  final VoidCallback? onTap;

  const _HomeworkItem({
    required this.hw,
    required this.courseName,
    required this.isDone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isGraded = hw.graded;
    final isSubmitted = hw.submitted;

    // Card background
    Color cardBg;
    BoxBorder? cardBorder;
    if (isGraded) {
      cardBg = context.isDark
          ? const Color(0xFF1A2E1A)
          : const Color(0xFFF0FFF4);
      cardBorder = Border.all(
        color: const Color(0xFF34C759).withAlpha(context.isDark ? 25 : 20),
        width: 0.5,
      );
    } else {
      cardBg = c.surface;
      cardBorder = Border.all(color: c.border, width: 0.5);
    }

    final opacity = (isSubmitted && !isGraded) ? 0.85 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: cardBorder,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top: course + status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        courseName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: c.tertiary,
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusBadge(hw: hw),
                  ],
                ),
                const SizedBox(height: 4),

                // Mid: title + time/grade
                Row(
                  children: [
                    if (isSubmitted && !isGraded) ...[
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: const Color(0xFF007AFF).withAlpha(180),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        hw.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                          decoration: null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (isGraded && hw.grade != null)
                      Text(
                        hw.grade! == hw.grade!.roundToDouble()
                            ? hw.grade!.toInt().toString()
                            : hw.grade!.toStringAsFixed(1),
                        style: const TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontFamilyFallback: ['monospace'],
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF34C759),
                        ),
                      )
                    else if (!isDone)
                      Text(
                        _formatDeadline(),
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontFamilyFallback: const ['monospace'],
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                          color: _deadlineColor(),
                        ),
                      ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: context.isDark
                          ? const Color(0xFF48484A)
                          : const Color(0xFFC7C7CC),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Deadline formatting ──

  Color _deadlineColor() {
    final deadline = tryParseEpochMillisToLocal(hw.deadline);
    if (deadline == null) return const Color(0xFF007AFF);
    final remaining = deadline.difference(nowInShanghai());
    if (remaining.isNegative) return const Color(0xFFFF3B30);
    if (remaining.inHours < 24) return const Color(0xFFFF3B30);
    if (remaining.inHours < 72) return const Color(0xFFE8590C);
    return const Color(0xFF007AFF);
  }

  String _formatDeadline() {
    final d = tryParseEpochMillisToLocal(hw.deadline);
    if (d == null) return hw.deadline;
    final now = nowInShanghai();
    final remaining = d.difference(now);

    if (remaining.isNegative) {
      final abs = remaining.abs();
      if (abs.inDays > 0) return '${abs.inDays}天前';
      if (abs.inHours > 0) return '${abs.inHours}小时前';
      return '${abs.inMinutes}分钟前';
    }

    if (remaining.inHours < 24) {
      return '还剩${remaining.inHours}h${remaining.inMinutes.remainder(60)}m';
    }

    return formatRelativeDeadlineLabel(d, now: now);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Status Badge — small pill showing submission state
// ═══════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final Homework hw;

  const _StatusBadge({required this.hw});

  @override
  Widget build(BuildContext context) {
    final (text, color) = _data();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(context.isDark ? 30 : 20),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  (String, Color) _data() {
    if (hw.graded) return ('已批改', const Color(0xFF34C759));
    if (hw.submitted) return ('已提交', const Color(0xFF007AFF));
    final deadline = tryParseEpochMillisToLocal(hw.deadline);
    if (deadline != null && deadline.isBefore(nowInShanghai())) {
      return ('已超期', const Color(0xFFFF3B30));
    }
    return ('待提交', const Color(0xFFFF9500));
  }
}
