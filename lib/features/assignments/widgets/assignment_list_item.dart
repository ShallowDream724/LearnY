import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/utils/deadline_time.dart';
import '../../../core/utils/homework_grade_display.dart';

class AssignmentListItem extends StatelessWidget {
  const AssignmentListItem({
    super.key,
    required this.homework,
    required this.courseName,
    required this.now,
    required this.onTap,
    this.noSubmissionNeeded = false,
    this.onReminder,
  });

  final Homework homework;
  final String courseName;
  final DateTime now;
  final bool noSubmissionNeeded;
  final VoidCallback onTap;
  final ValueChanged<Offset>? onReminder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final deadline = tryParseEpochMillisToLocal(homework.deadline);
    final overdue =
        !homework.submitted &&
        !homework.graded &&
        !noSubmissionNeeded &&
        deadline != null &&
        deadline.isBefore(now);
    final grade = resolveHomeworkGradeDisplay(
      grade: homework.grade,
      gradeLevel: homework.gradeLevel,
    );
    final status = homework.graded
        ? '已批改'
        : homework.submitted
        ? '已提交'
        : noSubmissionNeeded
        ? '无需提交'
        : overdue
        ? '已超期'
        : '待提交';
    final statusColor = overdue
        ? Theme.of(context).colorScheme.error
        : homework.submitted || homework.graded
        ? c.infoAccent
        : c.subtitle;
    final deadlineLabel = deadline == null
        ? '截止时间待定'
        : formatRelativeDeadlineLabel(deadline, now: now);
    final hasReminder =
        onReminder != null && !homework.graded && !homework.submitted;

    Widget details() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homework.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleLarge.copyWith(color: c.text),
        ),
        const SizedBox(height: 4),
        Text(
          courseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodySmall.copyWith(color: c.subtitle),
        ),
      ],
    );
    Widget state({bool wide = false}) => Column(
      crossAxisAlignment: wide
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          homework.graded && grade.hasDisplayValue
              ? '$status · ${grade.primaryLabel}'
              : status,
          style: AppTypography.labelMedium.copyWith(color: statusColor),
        ),
        const SizedBox(height: 4),
        Text(
          deadlineLabel,
          style: AppTypography.bodySmall.copyWith(
            color: overdue ? statusColor : c.subtitle,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );

    return GestureDetector(
      onSecondaryTapDown: hasReminder
          ? (details) => onReminder!(details.globalPosition)
          : null,
      onLongPressStart: hasReminder
          ? (details) => onReminder!(details.globalPosition)
          : null,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 640 &&
                    MediaQuery.textScalerOf(context).scale(14) < 20;
                return Row(
                  children: [
                    Expanded(
                      child: wide
                          ? details()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                details(),
                                const SizedBox(height: 10),
                                state(),
                              ],
                            ),
                    ),
                    if (wide) ...[const SizedBox(width: 20), state(wide: true)],
                    const SizedBox(width: 8),
                    if (hasReminder)
                      Builder(
                        builder: (buttonContext) => IconButton(
                          tooltip: '作业提醒设置',
                          icon: const Icon(Icons.more_horiz, size: 20),
                          onPressed: () {
                            final box =
                                buttonContext.findRenderObject()! as RenderBox;
                            onReminder!(
                              box.localToGlobal(box.size.center(Offset.zero)),
                            );
                          },
                        ),
                      )
                    else
                      SizedBox(
                        width: 44,
                        child: Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: c.tertiary,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
