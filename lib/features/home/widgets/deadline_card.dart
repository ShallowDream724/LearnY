/// Deadline card — shows an assignment with urgency indication.
import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/deadline_time.dart';

class DeadlineCard extends StatelessWidget {
  final HomeworkSummary hw;
  final VoidCallback? onTap;

  const DeadlineCard({super.key, required this.hw, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final urgencyColor = _urgencyColor(hw.timeRemaining, hw.isOverdue);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              // Urgency indicator
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(
                  color: urgencyColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Course name
                    Text(
                      hw.courseName,
                      style: AppTypography.labelSmall.copyWith(
                        color: c.subtitle,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    // Assignment title
                    Text(
                      hw.title,
                      style: AppTypography.titleMedium.copyWith(color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Time remaining badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: urgencyColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: urgencyColor.withAlpha(60)),
                ),
                child: Text(
                  _formatRemaining(hw.timeRemaining, hw.isOverdue),
                  style: AppTypography.labelSmall.copyWith(
                    color: urgencyColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _urgencyColor(Duration remaining, bool isOverdue) {
    if (isOverdue) return AppColors.deadlineOverdue;
    if (remaining.inHours < 24) return AppColors.deadlineUrgent;
    if (remaining.inDays <= 3) return AppColors.deadlineSoon;
    return AppColors.deadlineComfortable;
  }

  String _formatRemaining(Duration remaining, bool isOverdue) {
    if (isOverdue) {
      final abs = remaining.abs();
      if (abs.inDays > 0) return '已超 ${abs.inDays}天';
      return '已超 ${abs.inHours}时';
    }
    if (remaining.inMinutes < 60) return '${remaining.inMinutes}分钟';
    if (remaining.inHours < 24) return '${remaining.inHours}小时';
    final deadline = tryParseEpochMillisToLocal(hw.deadline);
    if (deadline == null) return '${remaining.inDays}天';
    return formatRelativeDayCountLabel(deadline, now: nowInShanghai());
  }
}
