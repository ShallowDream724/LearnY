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

import '../../core/design/colors.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/database/database.dart';
import '../../core/router/router.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  Providers
// ═══════════════════════════════════════════════════════════════════════════

enum HomeworkFilter { all, pending, submitted, graded }

final _homeworkFilterProvider =
    StateProvider<HomeworkFilter>((ref) => HomeworkFilter.all);

final _homeworkListProvider = FutureProvider<List<Homework>>((ref) async {
  final db = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) return [];

  final courses = await db.getCoursesBySemester(semesterId);
  final all = <Homework>[];
  for (final c in courses) {
    all.addAll(await db.getHomeworksByCourse(c.id));
  }
  return all;
});

final _courseNameMapProvider =
    FutureProvider<Map<String, String>>((ref) async {
  final db = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) return {};

  final courses = await db.getCoursesBySemester(semesterId);
  return {for (final c in courses) c.id: c.name};
});

// ═══════════════════════════════════════════════════════════════════════════
//  Time-based grouping
// ═══════════════════════════════════════════════════════════════════════════

enum _TimeGroup { thisWeek, nextWeek, later, done }

class _GroupMeta {
  final String label;
  final Color color;
  _GroupMeta(this.label, this.color);
}

_GroupMeta _groupMeta(_TimeGroup g) => switch (g) {
      _TimeGroup.thisWeek => _GroupMeta('本周截止', const Color(0xFFFF3B30)),
      _TimeGroup.nextWeek => _GroupMeta('下周截止', const Color(0xFFFF9500)),
      _TimeGroup.later => _GroupMeta('更远', const Color(0xFF007AFF)),
      _TimeGroup.done => _GroupMeta('已完成', const Color(0xFF34C759)),
    };

_TimeGroup _classify(Homework hw) {
  if (hw.submitted || hw.graded) return _TimeGroup.done;

  final ms = int.tryParse(hw.deadline);
  if (ms == null) return _TimeGroup.later;

  final deadline = DateTime.fromMillisecondsSinceEpoch(ms);
  final now = DateTime.now();
  final remaining = deadline.difference(now);

  if (remaining.isNegative) return _TimeGroup.thisWeek; // overdue → urgent

  // Same ISO week?
  final nowMonday = now.subtract(Duration(days: now.weekday - 1));
  final dlMonday = deadline.subtract(Duration(days: deadline.weekday - 1));
  final sameWeek = nowMonday.year == dlMonday.year &&
      nowMonday.month == dlMonday.month &&
      nowMonday.day == dlMonday.day;

  if (sameWeek) return _TimeGroup.thisWeek;

  // Next week?
  final nextMonday = nowMonday.add(const Duration(days: 7));
  final nextSunday = nextMonday.add(const Duration(days: 6));
  if (!deadline.isBefore(nextMonday) &&
      deadline.isBefore(nextSunday.add(const Duration(days: 1)))) {
    return _TimeGroup.nextWeek;
  }

  return _TimeGroup.later;
}

/// Groups and sorts homework into timeline sections.
Map<_TimeGroup, List<Homework>> _groupHomeworks(List<Homework> homeworks) {
  final groups = <_TimeGroup, List<Homework>>{};
  for (final hw in homeworks) {
    final g = _classify(hw);
    (groups[g] ??= []).add(hw);
  }

  // Sort each group by deadline ascending (nearest first)
  for (final list in groups.values) {
    list.sort((a, b) {
      final aMs = int.tryParse(a.deadline) ?? 0;
      final bMs = int.tryParse(b.deadline) ?? 0;
      return aMs - bMs;
    });
  }

  return groups;
}

// ═══════════════════════════════════════════════════════════════════════════
//  Screen
// ═══════════════════════════════════════════════════════════════════════════

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
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(syncStateProvider.notifier).syncHomeworksOnly();
          final ss = ref.read(syncStateProvider);
          if (ss.status == SyncStatus.cooldown && context.mounted) {
            CooldownToast.show(context, seconds: ss.cooldownSeconds);
          }
          ref.invalidate(_homeworkListProvider);
          ref.invalidate(_courseNameMapProvider);
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
                style: AppTypography.headlineMedium.copyWith(color: textColor),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: homeworkAsync.when(
                loading: () =>
                    const SliverFillRemaining(child: ListSkeleton()),
                error: (e, _) => _buildError(isDark, textColor, ref),
                data: (allHomeworks) {
                  final courseNames =
                      courseNameAsync.valueOrNull ?? <String, String>{};

                  // Stats
                  final stats = _computeStats(allHomeworks);

                  // Filter
                  final filtered = _applyFilter(allHomeworks, filter);

                  // Group into timeline
                  final groups = _groupHomeworks(filtered);

                  // Ordered display
                  const order = [
                    _TimeGroup.thisWeek,
                    _TimeGroup.nextWeek,
                    _TimeGroup.later,
                    _TimeGroup.done,
                  ];

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      // Stats strip
                      _StatsStrip(stats: stats, isDark: isDark)
                          .animate()
                          .fadeIn(duration: 300.ms),
                      const SizedBox(height: 16),

                      // Filter pills
                      _FilterRow(
                        current: filter,
                        onChanged: (f) => ref
                            .read(_homeworkFilterProvider.notifier)
                            .state = f,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 20),

                      // Timeline groups
                      if (filtered.isEmpty)
                        _buildEmpty(isDark)
                      else
                        ...order
                            .where((g) => groups.containsKey(g))
                            .map((g) => _TimelineSection(
                                  group: g,
                                  homeworks: groups[g]!,
                                  courseNames: courseNames,
                                  isDark: isDark,
                                  onTapItem: (hw) {
                                    final name =
                                        courseNames[hw.courseId] ?? '';
                                    context.push(Routes.homeworkDetail(
                                      homeworkId: hw.id,
                                      courseId: hw.courseId,
                                      courseName: name,
                                    ));
                                  },
                                )),
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

  // ── Helpers ──

  _Stats _computeStats(List<Homework> all) {
    int pending = 0, submitted = 0, graded = 0, overdue = 0;
    final now = DateTime.now();
    for (final hw in all) {
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
    return _Stats(pending, submitted, graded, overdue);
  }

  List<Homework> _applyFilter(List<Homework> all, HomeworkFilter f) {
    return all.where((hw) => switch (f) {
          HomeworkFilter.pending => !hw.submitted && !hw.graded,
          HomeworkFilter.submitted => hw.submitted && !hw.graded,
          HomeworkFilter.graded => hw.graded,
          HomeworkFilter.all => true,
        }).toList();
  }

  SliverFillRemaining _buildError(
      bool isDark, Color textColor, WidgetRef ref) {
    final sub = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: sub),
            const SizedBox(height: 12),
            Text('加载失败',
                style: AppTypography.titleMedium.copyWith(color: textColor)),
            const SizedBox(height: 8),
            Text('请下拉刷新重试',
                style: AppTypography.bodySmall.copyWith(color: sub)),
          ],
        ),
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

// ═══════════════════════════════════════════════════════════════════════════
//  Stats model
// ═══════════════════════════════════════════════════════════════════════════

class _Stats {
  final int pending, submitted, graded, overdue;
  const _Stats(this.pending, this.submitted, this.graded, this.overdue);
}

// ═══════════════════════════════════════════════════════════════════════════
//  Stats Strip — compact inline stats
// ═══════════════════════════════════════════════════════════════════════════

class _StatsStrip extends StatelessWidget {
  final _Stats stats;
  final bool isDark;

  const _StatsStrip({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final sub =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          _StatChip(
              n: stats.pending,
              label: '待交',
              color: stats.pending > 0
                  ? const Color(0xFFFF9500)
                  : const Color(0xFF34C759),
              sub: sub),
          _StatChip(
              n: stats.submitted,
              label: '已交',
              color: const Color(0xFF007AFF),
              sub: sub),
          _StatChip(
              n: stats.graded,
              label: '已批',
              color: const Color(0xFF34C759),
              sub: sub),
          _StatChip(
              n: stats.overdue,
              label: '超期',
              color: stats.overdue > 0
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF34C759),
              sub: sub),
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
          final bg = isSelected
              ? const Color(0xFF007AFF)
              : (isDark
                  ? const Color(0xFF2C2C2E)
                  : const Color(0xFFF5F5F7));
          final fg = isSelected
              ? Colors.white
              : (isDark
                  ? AppColors.darkTextSecondary
                  : const Color(0xFF636366));

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onChanged(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark
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
  final _TimeGroup group;
  final List<Homework> homeworks;
  final Map<String, String> courseNames;
  final bool isDark;
  final void Function(Homework hw) onTapItem;

  const _TimelineSection({
    required this.group,
    required this.homeworks,
    required this.courseNames,
    required this.isDark,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _groupMeta(group);
    final isDone = group == _TimeGroup.done;

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
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : const Color(0xFF8E8E93),
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
                  color: isDark
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
                    isDark: isDark,
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
  final bool isDark;
  final bool isDone;
  final VoidCallback? onTap;

  const _HomeworkItem({
    required this.hw,
    required this.courseName,
    required this.isDark,
    required this.isDone,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGraded = hw.graded;
    final isSubmitted = hw.submitted;

    // Card background
    Color cardBg;
    BoxBorder? cardBorder;
    if (isGraded) {
      cardBg = isDark
          ? const Color(0xFF1A2E1A)
          : const Color(0xFFF0FFF4);
      cardBorder = Border.all(
        color: const Color(0xFF34C759).withAlpha(isDark ? 25 : 20),
        width: 0.5,
      );
    } else {
      cardBg = isDark ? AppColors.darkSurface : Colors.white;
      cardBorder = Border.all(
        color: isDark ? AppColors.darkBorder : const Color(0xFFF0F0F2),
        width: 0.5,
      );
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
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : const Color(0xFF8E8E93),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _StatusBadge(hw: hw, isDark: isDark),
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
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : const Color(0xFF1C1C1E),
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
                      color: isDark
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
    final ms = int.tryParse(hw.deadline);
    if (ms == null) return const Color(0xFF007AFF);
    final remaining =
        DateTime.fromMillisecondsSinceEpoch(ms).difference(DateTime.now());
    if (remaining.isNegative) return const Color(0xFFFF3B30);
    if (remaining.inHours < 24) return const Color(0xFFFF3B30);
    if (remaining.inHours < 72) return const Color(0xFFE8590C);
    return const Color(0xFF007AFF);
  }

  String _formatDeadline() {
    final ms = int.tryParse(hw.deadline);
    if (ms == null) return hw.deadline;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
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

    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final dayDiff = remaining.inDays;

    if (dayDiff == 0) return '今天 $timeStr';
    if (dayDiff == 1) return '明天 $timeStr';
    if (dayDiff == 2) return '后天 $timeStr';

    const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final nowMonday = now.subtract(Duration(days: now.weekday - 1));
    final dMonday = d.subtract(Duration(days: d.weekday - 1));
    final sameWeek = nowMonday.year == dMonday.year &&
        nowMonday.month == dMonday.month &&
        nowMonday.day == dMonday.day;

    if (dayDiff < 14) {
      final prefix = sameWeek ? '本' : '下';
      return '$prefix${weekdays[d.weekday]} $timeStr';
    }

    return '${d.month}/${d.day} $timeStr';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Status Badge — small pill showing submission state
// ═══════════════════════════════════════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final Homework hw;
  final bool isDark;

  const _StatusBadge({required this.hw, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final (text, color) = _data();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 30 : 20),
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
    final ms = int.tryParse(hw.deadline);
    if (ms != null &&
        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now())) {
      return ('已超期', const Color(0xFFFF3B30));
    }
    return ('待提交', const Color(0xFFFF9500));
  }
}
