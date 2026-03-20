/// Urgent deadline banner — premium "X个作业即将截止" card
/// with live countdown timers (<24h), 本周/下周 date text,
/// sequence number urgency indicators, and configurable threshold.
///
/// Design: warm cream gradient background, three urgency tiers
///   critical (<24h): #FF3B30 red
///   warning  (24-72h): #E8590C burnt orange
///   normal   (>72h):   #007AFF Apple blue
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_provider.dart';

class UrgentDeadlineBanner extends ConsumerStatefulWidget {
  final List<HomeworkSummary> assignments;
  final void Function(HomeworkSummary hw)? onTap;

  const UrgentDeadlineBanner({
    super.key,
    required this.assignments,
    this.onTap,
  });

  @override
  ConsumerState<UrgentDeadlineBanner> createState() =>
      _UrgentDeadlineBannerState();
}

class _UrgentDeadlineBannerState extends ConsumerState<UrgentDeadlineBanner>
    with SingleTickerProviderStateMixin {
  Timer? _countdownTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Urgency tier ──

  _UrgencyTier _tier(HomeworkSummary hw) {
    if (hw.isOverdue) return _UrgencyTier.critical;
    if (hw.timeRemaining.inHours < 24) return _UrgencyTier.critical;
    if (hw.timeRemaining.inHours < 72) return _UrgencyTier.warning;
    return _UrgencyTier.normal;
  }

  Color _tierColor(_UrgencyTier t) => switch (t) {
    _UrgencyTier.critical => const Color(0xFFFF3B30),
    _UrgencyTier.warning => const Color(0xFFE8590C),
    _UrgencyTier.normal => const Color(0xFF007AFF),
  };

  // ── Time formatting ──

  String _formatCountdown(HomeworkSummary hw) {
    if (hw.isOverdue) return '已截止';

    final deadlineMs = int.tryParse(hw.deadline);
    if (deadlineMs == null) return '';
    final deadline = DateTime.fromMillisecondsSinceEpoch(deadlineMs);
    final now = DateTime.now();
    final remaining = deadline.difference(now);

    if (remaining.isNegative) return '已截止';

    if (remaining.inHours < 24) {
      final h = remaining.inHours;
      final m = remaining.inMinutes.remainder(60);
      if (h > 0) {
        return '剩余 ${h}h ${m}m';
      } else {
        return '剩余 ${m}分钟';
      }
    }

    final dayDiff = remaining.inDays;
    final time =
        '${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';

    if (dayDiff == 0) return '今天 $time';
    if (dayDiff == 1) return '明天 $time';
    if (dayDiff == 2) return '后天 $time';

    // 本周 vs 下周
    final nowWeekday = now.weekday; // 1=Mon 7=Sun
    final deadlineWeekday = deadline.weekday;
    const names = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final nowMonday = now.subtract(Duration(days: nowWeekday - 1));
    final deadlineMonday = deadline.subtract(
      Duration(days: deadlineWeekday - 1),
    );
    final sameWeek =
        nowMonday.year == deadlineMonday.year &&
        nowMonday.month == deadlineMonday.month &&
        nowMonday.day == deadlineMonday.day;

    if (sameWeek) {
      return '本${names[deadlineWeekday]} $time';
    } else if (dayDiff < 14) {
      return '下${names[deadlineWeekday]} $time';
    }
    return '${deadline.month}/${deadline.day} $time';
  }

  String _formatDateSub(HomeworkSummary hw) {
    if (hw.isOverdue) return '';
    final deadlineMs = int.tryParse(hw.deadline);
    if (deadlineMs == null) return '';
    final deadline = DateTime.fromMillisecondsSinceEpoch(deadlineMs);
    final remaining = deadline.difference(DateTime.now());
    if (remaining.inHours < 24) {
      return '今天 ${deadline.hour.toString().padLeft(2, '0')}:${deadline.minute.toString().padLeft(2, '0')}';
    }
    return '${deadline.month}月${deadline.day}日';
  }

  // ── Threshold dialog ──

  void _showThresholdDialog() {
    final controller = TextEditingController(
      text: ref.read(deadlineThresholdHoursProvider).toString(),
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设置截止提醒阈值'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('显示多少小时内即将截止的作业：'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                suffixText: '小时',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(controller.text);
              if (v != null && v > 0) {
                ref.read(deadlineThresholdHoursProvider.notifier).setHours(v);
              }
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final assignments = widget.assignments;
    if (assignments.isEmpty) return const SizedBox.shrink();

    final thresholdHours = ref.watch(deadlineThresholdHoursProvider);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF2A2218), const Color(0xFF2C2116)]
              : [const Color(0xFFFFF7EE), const Color(0xFFFFF3E4)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC8A064).withAlpha(isDark ? 0 : 8),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFC8A064).withAlpha(isDark ? 25 : 30),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                // Pulsing dot
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) => Opacity(
                    opacity: 0.5 + 0.5 * _pulseController.value,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * _pulseController.value,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF9F0A),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Title
                Text(
                  '${assignments.length} 个作业即将截止',
                  style: AppTypography.labelMedium.copyWith(
                    color: isDark
                        ? const Color(0xFFFFBB5C)
                        : const Color(0xFFB5710D),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // Threshold badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB4783C).withAlpha(18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${thresholdHours}h',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFD0A878)
                          : const Color(0xFFC09060),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Settings gear
                GestureDetector(
                  onTap: _showThresholdDialog,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFB4783C).withAlpha(18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      size: 14,
                      color: isDark
                          ? const Color(0xFFD0A878)
                          : const Color(0xFFB5710D),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Assignment items — ALL shown, no folding ──
          ...assignments.asMap().entries.map((entry) {
            final index = entry.key;
            final hw = entry.value;
            final isLast = index == assignments.length - 1;
            final tier = _tier(hw);
            final color = _tierColor(tier);
            final dateSub = _formatDateSub(hw);

            return InkWell(
              onTap: () => widget.onTap?.call(hw),
              child: Container(
                padding: EdgeInsets.fromLTRB(16, 11, 16, isLast ? 14 : 11),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: const Color(0xFFB4783C).withAlpha(15),
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    // Sequence number
                    SizedBox(
                      width: 18,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontFamilyFallback: const ['monospace'],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: color.withAlpha(
                            tier == _UrgencyTier.critical
                                ? 153 // 0.6
                                : tier == _UrgencyTier.warning
                                ? 128 // 0.5
                                : 89, // 0.35
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hw.courseName,
                            style: AppTypography.bodySmall.copyWith(
                              color: isDark
                                  ? const Color(0xFF98989D)
                                  : const Color(0xFFA08060),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hw.title,
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark
                                  ? context.colors.text
                                  : const Color(0xFF1C1C1E),
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Time display
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCountdown(hw),
                          style: TextStyle(
                            fontFamily: 'JetBrains Mono',
                            fontFamilyFallback: const ['monospace'],
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                            color: color,
                          ),
                        ),
                        if (dateSub.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            dateSub,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark
                                  ? const Color(0xFF98989D)
                                  : const Color(0xFFB09880),
                            ),
                          ),
                        ],
                        // Progress bar for critical items
                        if (tier == _UrgencyTier.critical && !hw.isOverdue) ...[
                          const SizedBox(height: 3),
                          _ProgressBar(remaining: hw.timeRemaining),
                        ],
                      ],
                    ),
                    const SizedBox(width: 4),
                    // Chevron
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isDark
                          ? const Color(0xFF48484A)
                          : const Color(0xFFD0C0B0),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

enum _UrgencyTier { critical, warning, normal }

/// Thin progress bar showing how much time has elapsed.
/// 24h = full width. Shows gradient from blue to orange to red.
class _ProgressBar extends StatelessWidget {
  final Duration remaining;

  const _ProgressBar({required this.remaining});

  @override
  Widget build(BuildContext context) {
    // Fraction elapsed out of 24h
    final fraction = (1.0 - remaining.inSeconds / (24 * 3600)).clamp(0.0, 1.0);

    return SizedBox(
      width: 56,
      height: 2,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: Stack(
          children: [
            Container(color: const Color(0xFFB4783C).withAlpha(18)),
            FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFD4A574),
                      Color(0xFFC97030),
                      Color(0xFFC93400),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
