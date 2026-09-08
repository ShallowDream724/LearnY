import 'package:flutter/material.dart';

import '../../../core/database/database.dart';
import '../../../core/design/app_materials.dart';
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
    final course = StudyPalette.of(
      context,
      StudyPalette.course(homework.courseId),
    );
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
    final stateTone = overdue
        ? StudyTone.rose
        : homework.submitted || homework.graded
        ? StudyTone.jade
        : noSubmissionNeeded
        ? StudyTone.slate
        : StudyTone.ochre;
    final state = StudyPalette.of(context, stateTone);
    final deadlineLabel = deadline == null
        ? '截止时间待定'
        : formatRelativeDeadlineLabel(deadline, now: now);
    final hasReminder =
        onReminder != null && !homework.graded && !homework.submitted;

    Widget title() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (courseName.isNotEmpty) ...[
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: course.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall.copyWith(color: course.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
        ],
        Text(
          homework.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.titleMedium.copyWith(
            color: c.text,
            fontSize: 15,
            height: 1.45,
          ),
        ),
      ],
    );
    Widget deadlineText() => Text(
      deadlineLabel,
      style: AppTypography.bodySmall.copyWith(
        color: overdue ? state.accent : c.subtitle,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    Widget statusBadge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: state.fill,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        homework.graded && grade.hasDisplayValue
            ? '$status · ${grade.primaryLabel}'
            : status,
        style: AppTypography.labelSmall.copyWith(
          color: state.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );

    return GestureDetector(
      onSecondaryTapDown: hasReminder
          ? (details) => onReminder!(details.globalPosition)
          : null,
      onLongPressStart: hasReminder
          ? (details) => onReminder!(details.globalPosition)
          : null,
      child: Material(
        color: c.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 660 &&
                    MediaQuery.textScalerOf(context).scale(14) < 20;
                final menu = hasReminder
                    ? Builder(
                        builder: (buttonContext) => IconButton(
                          tooltip: '作业提醒设置',
                          icon: Icon(
                            Icons.more_horiz,
                            size: 20,
                            color: c.subtitle,
                          ),
                          onPressed: () {
                            final box =
                                buttonContext.findRenderObject()! as RenderBox;
                            onReminder!(
                              box.localToGlobal(box.size.center(Offset.zero)),
                            );
                          },
                        ),
                      )
                    : SizedBox(width: wide ? 40 : 0);
                return Row(
                  crossAxisAlignment: wide
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: wide
                          ? title()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                title(),
                                const SizedBox(height: 10),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 12,
                                  runSpacing: 6,
                                  children: [deadlineText(), statusBadge()],
                                ),
                              ],
                            ),
                    ),
                    if (wide) ...[
                      const SizedBox(width: 24),
                      SizedBox(width: 152, child: deadlineText()),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 116,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: statusBadge(),
                        ),
                      ),
                    ],
                    menu,
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
