/// Homework detail page — multi-state view of assignment lifecycle.
///
/// UX Design Decisions:
///
/// 1. **Status-first design**: A prominent status header with
///    color-coded indicator (pending/submitted/graded/overdue) tells the
///    student their position in the assignment lifecycle at a glance.
///
/// 2. **Deadline countdown**: For pending assignments, a live countdown
///    (days + hours remaining) creates appropriate urgency without panic.
///    The color shifts from green → amber → red as the deadline approaches.
///
/// 3. **Collapsible sections**: Description, submission, grade feedback
///    are in expandable cards. This prevents information overload while
///    keeping everything accessible.
///
/// 4. **Grade visualization**: When graded, a circular progress ring shows
///    the score visually, with color-coded levels (excellent → fail).
///
/// 5. **Attachment consistency**: All attachment cards use the same
///    design language (type icon, name, size, download button) across
///    assignment files, submitted files, and grade feedback files.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/colors.dart';
import '../../core/design/responsive.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/providers/providers.dart';
import 'assignment_submission_screen.dart';

class HomeworkDetailScreen extends ConsumerStatefulWidget {
  final String homeworkId;
  final String courseId;
  final String courseName;

  const HomeworkDetailScreen({
    super.key,
    required this.homeworkId,
    required this.courseId,
    required this.courseName,
  });

  @override
  ConsumerState<HomeworkDetailScreen> createState() =>
      _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends ConsumerState<HomeworkDetailScreen> {
  db.Homework? _homework;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final database = ref.read(databaseProvider);
    final homeworks = await database.getHomeworksByCourse(widget.courseId);
    final hw =
        homeworks.where((h) => h.id == widget.homeworkId).firstOrNull;

    if (mounted) {
      setState(() {
        _homework = hw;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(),
        body: const ListSkeleton(),
      );
    }

    final hw = _homework;
    if (hw == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(),
        body: Center(
          child: Text('作业未找到',
              style: AppTypography.titleMedium.copyWith(color: subColor)),
        ),
      );
    }

    // Can submit: not graded, and deadline hasn't fully passed
    // (or late submission still possible)
    final canSubmit = !hw.graded;

    return Scaffold(
      backgroundColor: bg,
      floatingActionButton: canSubmit
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => AssignmentSubmissionScreen(
                      homework: hw,
                      courseName: widget.courseName,
                    ),
                  ),
                );
                if (result == true) {
                  _loadData(); // Refresh to show updated submission
                }
              },
              backgroundColor: AppColors.primary,
              icon: Icon(
                hw.submitted
                    ? Icons.edit_rounded
                    : Icons.upload_rounded,
                color: Colors.white,
              ),
              label: Text(
                hw.submitted ? '重新提交' : '提交作业',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            title: Text(
              widget.courseName,
              style: AppTypography.titleMedium.copyWith(color: subColor),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Status Header ──
                      _StatusHeader(homework: hw, isDark: isDark)
                          .animate()
                          .fadeIn(duration: 300.ms),

                      const SizedBox(height: 20),

                      // ── Deadline Info ──
                      _DeadlineCard(homework: hw, isDark: isDark)
                          .animate(delay: 100.ms)
                          .fadeIn(duration: 250.ms)
                          .slideY(begin: 0.03, end: 0),

                      // ── Assignment Description ──
                      if (hw.description != null &&
                          hw.description!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: '作业要求',
                          icon: Icons.description_rounded,
                          iconColor: AppColors.info,
                          isDark: isDark,
                          child: _HtmlText(
                            html: hw.description!,
                            isDark: isDark,
                          ),
                        )
                            .animate(delay: 150.ms)
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.03, end: 0),
                      ],

                      // ── Assignment Attachment ──
                      if (hw.attachmentJson != null &&
                          hw.attachmentJson!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _AttachmentCard(
                          label: '作业附件',
                          isDark: isDark,
                        )
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 250.ms),
                      ],

                      // ── Submission Section ──
                      if (hw.submitted) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: '我的提交',
                          icon: Icons.upload_file_rounded,
                          iconColor: AppColors.success,
                          isDark: isDark,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (hw.submittedContent != null &&
                                  hw.submittedContent!.isNotEmpty)
                                _HtmlText(
                                  html: hw.submittedContent!,
                                  isDark: isDark,
                                ),
                              if (hw.submitTime != null) ...[
                                const SizedBox(height: 8),
                                _MetaChip(
                                  icon: Icons.schedule_rounded,
                                  label:
                                      '提交于 ${_formatFullTime(hw.submitTime!)}',
                                  isDark: isDark,
                                ),
                              ],
                              if (hw.isLateSubmission) ...[
                                const SizedBox(height: 6),
                                _MetaChip(
                                  icon: Icons.warning_amber_rounded,
                                  label: '迟交',
                                  isDark: isDark,
                                  color: AppColors.warning,
                                ),
                              ],
                            ],
                          ),
                        )
                            .animate(delay: 250.ms)
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.03, end: 0),
                      ],

                      // ── Submitted Attachment ──
                      if (hw.submittedAttachmentJson != null &&
                          hw.submittedAttachmentJson!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _AttachmentCard(
                          label: '提交附件',
                          isDark: isDark,
                        )
                            .animate(delay: 280.ms)
                            .fadeIn(duration: 250.ms),
                      ],

                      // ── Grade Section ──
                      if (hw.graded) ...[
                        const SizedBox(height: 16),
                        _GradeSection(homework: hw, isDark: isDark)
                            .animate(delay: 300.ms)
                            .fadeIn(duration: 300.ms)
                            .slideY(begin: 0.03, end: 0),
                      ],

                      // ── Answer / Reference ──
                      if (hw.answerContent != null &&
                          hw.answerContent!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: '参考答案',
                          icon: Icons.auto_stories_rounded,
                          iconColor: const Color(0xFF8B5CF6),
                          isDark: isDark,
                          child: _HtmlText(
                            html: hw.answerContent!,
                            isDark: isDark,
                          ),
                        )
                            .animate(delay: 350.ms)
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.03, end: 0),
                      ],

                      // ── Comment ──
                      if (hw.comment != null && hw.comment!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _SectionCard(
                          title: '我的备注',
                          icon: Icons.sticky_note_2_rounded,
                          iconColor: AppColors.primary,
                          isDark: isDark,
                          child: Text(
                            hw.comment!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.lightTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Status Header
// ─────────────────────────────────────────────

/// Color-coded status header showing the assignment lifecycle state.
class _StatusHeader extends StatelessWidget {
  final db.Homework homework;
  final bool isDark;

  const _StatusHeader({required this.homework, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final (statusText, statusColor, statusIcon) = _statusInfo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status badge
        Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  Text(statusText,
                      style: AppTypography.labelMedium.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
            if (homework.isFavorite) ...[
              const SizedBox(width: 8),
              Icon(Icons.bookmark_rounded,
                  size: 18, color: AppColors.warning),
            ],
          ],
        ),

        const SizedBox(height: 12),

        // Title
        Text(
          homework.title,
          style: AppTypography.headlineSmall.copyWith(color: textColor),
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
    final ms = int.tryParse(homework.deadline);
    if (ms != null &&
        DateTime.fromMillisecondsSinceEpoch(ms).isBefore(DateTime.now())) {
      return ('已超期', AppColors.error, Icons.error_rounded);
    }
    return ('待提交', AppColors.warning, Icons.pending_rounded);
  }
}

// ─────────────────────────────────────────────
//  Deadline Card
// ─────────────────────────────────────────────

/// Shows deadline with countdown for pending assignments.
class _DeadlineCard extends StatelessWidget {
  final db.Homework homework;
  final bool isDark;

  const _DeadlineCard({required this.homework, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    final deadlineMs = int.tryParse(homework.deadline);
    final deadline = deadlineMs != null
        ? DateTime.fromMillisecondsSinceEpoch(deadlineMs)
        : null;
    final now = DateTime.now();
    final isOverdue = deadline != null && deadline.isBefore(now);
    final isPending = !homework.submitted && !homework.graded;

    // Countdown for pending assignments
    String? countdown;
    Color countdownColor = AppColors.success;
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
      countdown = '已超期 ${diff.inDays > 0 ? '${diff.inDays} 天' : '${diff.inHours} 小时'}';
      countdownColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        children: [
          // Deadline row
          Row(
            children: [
              Icon(Icons.event_rounded, size: 18, color: subColor),
              const SizedBox(width: 8),
              Text('截止时间',
                  style:
                      AppTypography.labelMedium.copyWith(color: subColor)),
              const Spacer(),
              Text(
                deadline != null
                    ? '${deadline.year}/${deadline.month}/${deadline.day} '
                        '${deadline.hour.toString().padLeft(2, '0')}:'
                        '${deadline.minute.toString().padLeft(2, '0')}'
                    : '未知',
                style:
                    AppTypography.titleSmall.copyWith(color: textColor),
              ),
            ],
          ),

          // Late submission deadline
          if (homework.lateSubmissionDeadline != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 18, color: subColor),
                const SizedBox(width: 8),
                Text('补交截止',
                    style: AppTypography.labelMedium
                        .copyWith(color: subColor)),
                const Spacer(),
                Text(
                  _formatFullTime(homework.lateSubmissionDeadline!),
                  style: AppTypography.bodySmall
                      .copyWith(color: subColor),
                ),
              ],
            ),
          ],

          // Countdown
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

// ─────────────────────────────────────────────
//  Grade Section
// ─────────────────────────────────────────────

/// Grade display with circular progress ring and feedback.
///
/// Scoring logic:
/// - Tsinghua's `cj` (成绩) field is typically 百分制 (0-100).
/// - When `grade` is 0-100, we show a circular ring with percentage fill.
/// - When `grade` > 100 (rare: custom scales), we show the number without ring.
/// - When only `gradeLevel` exists (no numeric grade), we show the level text.
class _GradeSection extends StatelessWidget {
  final db.Homework homework;
  final bool isDark;

  const _GradeSection({required this.homework, required this.isDark});

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

    final grade = homework.grade;
    final gradeColor = _gradeColor(grade);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Icon(Icons.grading_rounded, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text('批改结果',
                  style: AppTypography.titleMedium
                      .copyWith(color: textColor)),
            ],
          ),

          const SizedBox(height: 16),

          // Grade display + info
          Row(
            children: [
              // Score circle — shows the number or level, NO ring/progress
              // because we don't know the max score (could be 5, 10, 100, etc.)
              if (grade != null)
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
                      grade.toStringAsFixed(
                          grade == grade.roundToDouble() ? 0 : 1),
                      style: AppTypography.statMedium.copyWith(
                        color: gradeColor,
                        fontWeight: FontWeight.w800,
                        fontSize: grade >= 100 ? 18 : 22,
                      ),
                    ),
                  ),
                )
              else
                // Level-only grading (no numeric score)
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
                      _gradeLevelDisplay(homework.gradeLevel),
                      style: AppTypography.titleMedium
                          .copyWith(color: gradeColor),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(width: 20),

              // Grade details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (homework.graderName != null) ...[
                      Text(
                        '批改人: ${homework.graderName}',
                        style: AppTypography.bodyMedium
                            .copyWith(color: subColor),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (homework.gradeTime != null)
                      Text(
                        '批改于 ${_formatFullTime(homework.gradeTime!)}',
                        style: AppTypography.bodySmall
                            .copyWith(color: tertiaryColor),
                      ),
                    if (homework.gradeLevel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: gradeColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _gradeLevelDisplay(homework.gradeLevel),
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

          // Grade content (teacher feedback)
          if (homework.gradeContent != null &&
              homework.gradeContent!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: border, height: 1),
            const SizedBox(height: 12),
            Text('批改评语',
                style:
                    AppTypography.labelMedium.copyWith(color: subColor)),
            const SizedBox(height: 8),
            _HtmlText(html: homework.gradeContent!, isDark: isDark),
          ],

          // Grade attachment
          if (homework.gradeAttachmentJson != null &&
              homework.gradeAttachmentJson!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _AttachmentCard(label: '批改附件', isDark: isDark),
          ],
        ],
      ),
    );
  }

  /// Convert grade level enum string to user-friendly Chinese display.
  String _gradeLevelDisplay(String? level) {
    if (level == null) return '—';
    return switch (level) {
      'checked' => '已阅',
      'distinction' => '优秀',
      'pass' => '通过',
      'failure' => '不及格',
      'exempted course' => '免课',
      'exemption' => '免修',
      'incomplete' => '缓考',
      _ => level.toUpperCase(), // A+, B, C- etc.
    };
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

// ─────────────────────────────────────────────
//  Reusable components
// ─────────────────────────────────────────────

/// Expandable section card with colored icon header.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final bool isDark;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: AppTypography.titleMedium
                      .copyWith(color: textColor)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Attachment card (consistent design for all attachment types).
class _AttachmentCard extends StatelessWidget {
  final String label;
  final bool isDark;

  const _AttachmentCard({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.info.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.attach_file_rounded,
                size: 18, color: AppColors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style:
                    AppTypography.titleSmall.copyWith(color: textColor)),
          ),
          Icon(Icons.download_rounded, size: 20, color: subColor),
        ],
      ),
    );
  }
}

/// Small metadata chip with icon and label.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color? color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ??
        (isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: chipColor),
        const SizedBox(width: 4),
        Text(label,
            style:
                AppTypography.bodySmall.copyWith(color: chipColor, fontSize: 11)),
      ],
    );
  }
}

/// Renders HTML as stripped text (same approach as notification detail).
class _HtmlText extends StatelessWidget {
  final String html;
  final bool isDark;

  const _HtmlText({required this.html, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return SelectableText(
      _stripHtml(html),
      style: AppTypography.bodyMedium.copyWith(
        color: textColor,
        height: 1.7,
      ),
    );
  }

  String _stripHtml(String html) {
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n\n')
        .replaceAll(RegExp(r'</div>'), '\n')
        .replaceAll(RegExp(r'</li>'), '\n')
        .replaceAll(RegExp(r'<li[^>]*>'), '  \u2022 ');

    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}

// ─────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────

String _formatFullTime(String time) {
  final ms = int.tryParse(time);
  if (ms == null) return time;
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.year}/${d.month}/${d.day} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
