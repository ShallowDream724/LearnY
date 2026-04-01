import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/files/file_models.dart';
import '../../../core/files/widgets/file_attachment_card.dart';
import '../../../core/html/authenticated_html_content.dart';
import '../../../core/router/router.dart';
import '../../../core/utils/deadline_time.dart';
import '../../../core/utils/homework_grade_display.dart';

class HomeworkStatusHeader extends StatelessWidget {
  const HomeworkStatusHeader({super.key, required this.homework});

  final db.Homework homework;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (statusText, statusColor, statusIcon) = _statusInfo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withAlpha(60)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 5),
                  Text(
                    statusText,
                    style: AppTypography.labelMedium.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (homework.isFavorite) ...[
              const SizedBox(width: 8),
              Icon(Icons.bookmark_rounded, size: 18, color: AppColors.warning),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Text(
          homework.title,
          style: AppTypography.headlineSmall.copyWith(color: c.text),
        ),
      ],
    );
  }

  (String, Color, IconData) _statusInfo() {
    if (homework.graded) {
      return ('已批改', AppColors.success, Icons.check_circle_rounded);
    }
    if (homework.submitted) {
      return ('已提交', AppColors.info, Icons.cloud_done_rounded);
    }
    final deadline = tryParseEpochMillisToLocal(homework.deadline);
    if (deadline != null && deadline.isBefore(nowInShanghai())) {
      return ('已超期', AppColors.error, Icons.error_rounded);
    }
    return ('待提交', AppColors.warning, Icons.pending_rounded);
  }
}

class HomeworkDeadlineCard extends StatelessWidget {
  const HomeworkDeadlineCard({super.key, required this.homework});

  final db.Homework homework;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final deadline = tryParseEpochMillisToLocal(homework.deadline);
    final now = nowInShanghai();
    final isOverdue = deadline != null && deadline.isBefore(now);
    final isPending = !homework.submitted && !homework.graded;

    String? countdown;
    var countdownColor = AppColors.success;
    if (deadline != null && isPending && !isOverdue) {
      final diff = deadline.difference(now);
      if (diff.inDays > 3) {
        countdown = '剩余 ${diff.inDays} 天';
        countdownColor = AppColors.success;
      } else if (diff.inDays > 1) {
        countdown = '剩余 ${diff.inDays} 天 ${diff.inHours % 24} 小时';
        countdownColor = AppColors.warning;
      } else if (diff.inHours > 0) {
        countdown = '剩余 ${diff.inHours} 小时 ${diff.inMinutes % 60} 分';
        countdownColor = AppColors.error;
      } else {
        countdown = '剩余 ${diff.inMinutes} 分钟';
        countdownColor = AppColors.error;
      }
    } else if (deadline != null && isOverdue && isPending) {
      final diff = now.difference(deadline);
      countdown =
          '已超期 ${diff.inDays > 0 ? '${diff.inDays} 天' : '${diff.inHours} 小时'}';
      countdownColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded, size: 18, color: c.subtitle),
              const SizedBox(width: 8),
              Text(
                '截止时间',
                style: AppTypography.labelMedium.copyWith(color: c.subtitle),
              ),
              const Spacer(),
              Text(
                deadline != null
                    ? '${deadline.year}/${deadline.month}/${deadline.day} '
                          '${formatHourMinuteLabel(deadline)}'
                    : '未知',
                style: AppTypography.titleSmall.copyWith(color: c.text),
              ),
            ],
          ),
          if (homework.lateSubmissionDeadline != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: c.subtitle),
                const SizedBox(width: 8),
                Text(
                  '补交截止',
                  style: AppTypography.labelMedium.copyWith(color: c.subtitle),
                ),
                const Spacer(),
                Text(
                  formatHomeworkFullTime(homework.lateSubmissionDeadline!),
                  style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                ),
              ],
            ),
          ],
          if (countdown != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: countdownColor.withAlpha(12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  countdown,
                  style: AppTypography.titleSmall.copyWith(
                    color: countdownColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HomeworkGradeSection extends StatelessWidget {
  const HomeworkGradeSection({
    super.key,
    required this.homework,
    required this.courseId,
    required this.courseName,
    this.htmlBaseUri,
  });

  final db.Homework homework;
  final String courseId;
  final String courseName;
  final Uri? htmlBaseUri;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final gradeAttachmentEntry = FileAttachmentEntry.fromJson(
      label: '批改附件',
      rawJson: homework.gradeAttachmentJson,
      courseId: courseId,
      courseName: courseName,
      fallbackKind: FileAttachmentKind.homeworkGrade,
    );

    final gradeDisplay = resolveHomeworkGradeDisplay(
      grade: homework.grade,
      gradeLevel: homework.gradeLevel,
    );
    final grade = gradeDisplay.numericGrade;
    final gradeColor = _gradeColor(grade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grading_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                '批改结果',
                style: AppTypography.titleMedium.copyWith(color: c.text),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (gradeDisplay.hasDisplayValue)
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: gradeColor.withAlpha(15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: gradeColor.withAlpha(50),
                      width: 2,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        gradeDisplay.compactBadgeLabel ?? '已批',
                        style: AppTypography.statMedium.copyWith(
                          color: gradeColor,
                          fontWeight: FontWeight.w800,
                          fontSize: gradeDisplay.isNumeric
                              ? ((grade ?? 0) >= 100 ? 18 : 22)
                              : 18,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: gradeColor.withAlpha(15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: gradeColor.withAlpha(50),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      gradeDisplay.compactBadgeLabel ?? '已批',
                      style: AppTypography.titleMedium.copyWith(
                        color: gradeColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (homework.graderName != null) ...[
                      Text(
                        '批改人: ${homework.graderName}',
                        style: AppTypography.bodyMedium.copyWith(
                          color: c.subtitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (homework.gradeTime != null)
                      Text(
                        '批改于 ${formatHomeworkFullTime(homework.gradeTime!)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: c.tertiary,
                        ),
                      ),
                    if (gradeDisplay.gradeLevelLabel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: gradeColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          gradeDisplay.gradeLevelLabel!,
                          style: AppTypography.labelSmall.copyWith(
                            color: gradeColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasMeaningfulHomeworkHtml(homework.gradeContent)) ...[
            const SizedBox(height: 16),
            Divider(color: c.border, height: 1),
            const SizedBox(height: 12),
            Text(
              '批改评语',
              style: AppTypography.labelMedium.copyWith(color: c.subtitle),
            ),
            const SizedBox(height: 8),
            HomeworkHtmlText(
              html: homework.gradeContent!,
              baseUri: htmlBaseUri,
            ),
          ],
          if (homework.gradeAttachmentJson != null &&
              homework.gradeAttachmentJson!.isNotEmpty) ...[
            const SizedBox(height: 12),
            FileAttachmentCard(
              entry: gradeAttachmentEntry,
              onTap: () {
                final routeData = gradeAttachmentEntry.routeData;
                if (routeData == null) {
                  return;
                }
                context.push(Routes.fileDetailFromData(routeData));
              },
            ),
          ],
        ],
      ),
    );
  }

  Color _gradeColor(double? grade) {
    if (grade == null) return AppColors.info;
    if (grade >= 90) return AppColors.gradeExcellent;
    if (grade >= 80) return AppColors.gradeGood;
    if (grade >= 70) return AppColors.gradeAverage;
    if (grade >= 60) return AppColors.gradePoor;
    return AppColors.gradeFail;
  }
}

class HomeworkSectionCard extends StatelessWidget {
  const HomeworkSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.titleMedium.copyWith(color: c.text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class HomeworkMetaChip extends StatelessWidget {
  const HomeworkMetaChip({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? context.colors.tertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: chipColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: chipColor,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class HomeworkHtmlText extends StatelessWidget {
  const HomeworkHtmlText({super.key, required this.html, this.baseUri});

  final String html;
  final Uri? baseUri;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AuthenticatedHtmlContent(
      html: html,
      baseUri: baseUri,
      textStyle: AppTypography.bodyMedium.copyWith(color: c.text, height: 1.7),
    );
  }
}

bool hasMeaningfulHomeworkHtml(String? html) {
  return hasVisibleHtmlContent(
    html,
    placeholderOnly: RegExp(r'^[\s\u00A0\u200B>\-–—→➡➔➜➝]+$'),
  );
}

String formatHomeworkFullTime(String time) {
  final d = tryParseEpochMillisToLocal(time);
  if (d == null) return time;
  return '${d.year}/${d.month}/${d.day} '
      '${formatHourMinuteLabel(d)}';
}
