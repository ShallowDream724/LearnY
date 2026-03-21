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
import 'package:go_router/go_router.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/responsive.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/files/file_models.dart';
import '../../core/files/widgets/file_attachment_card.dart';
import '../../core/router/router.dart';
import 'assignment_submission_screen.dart';
import 'providers/assignments_providers.dart';
import 'widgets/homework_detail_sections.dart';

class HomeworkDetailScreen extends ConsumerWidget {
  final String homeworkId;
  final String courseId;
  final String courseName;

  const HomeworkDetailScreen({
    super.key,
    required this.homeworkId,
    required this.courseId,
    required this.courseName,
  });

  FileAttachmentEntry _attachmentEntry({
    required String label,
    required String? rawJson,
  }) {
    return FileAttachmentEntry.fromJson(
      label: label,
      rawJson: rawJson,
      courseId: courseId,
      courseName: courseName,
    );
  }

  void _openAttachment(BuildContext context, FileAttachmentEntry entry) {
    final routeData = entry.routeData;
    if (routeData == null) {
      return;
    }

    context.push(Routes.fileDetailFromData(routeData));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final homeworkAsync = ref.watch(homeworkDetailProvider(homeworkId));

    return homeworkAsync.when(
      loading: () => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(),
        body: const ListSkeleton(),
      ),
      error: (_, _) => Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(),
        body: Center(
          child: Text(
            '作业加载失败',
            style: AppTypography.titleMedium.copyWith(color: c.subtitle),
          ),
        ),
      ),
      data: (hw) {
        if (hw == null) {
          return Scaffold(
            backgroundColor: c.bg,
            appBar: AppBar(),
            body: Center(
              child: Text(
                '作业未找到',
                style: AppTypography.titleMedium.copyWith(color: c.subtitle),
              ),
            ),
          );
        }

        final canSubmit = !hw.graded;
        final hasHomeworkAttachment =
            hw.attachmentJson != null && hw.attachmentJson!.isNotEmpty;
        final hasSubmittedAttachment =
            hw.submittedAttachmentJson != null &&
            hw.submittedAttachmentJson!.isNotEmpty;
        final hasAnswerAttachment =
            hw.answerAttachmentJson != null &&
            hw.answerAttachmentJson!.isNotEmpty;
        final showRequirementSection =
            (hw.description != null && hw.description!.isNotEmpty) ||
            hasHomeworkAttachment;
        final showSubmittedContent = hasMeaningfulHomeworkHtml(
          hw.submittedContent,
        );
        final showSubmissionSection =
            hw.submitted &&
            (showSubmittedContent ||
                hw.submitTime != null ||
                hw.isLateSubmission ||
                hasSubmittedAttachment);
        final showAnswerSection =
            (hw.answerContent != null && hw.answerContent!.isNotEmpty) ||
            hasAnswerAttachment;
        final homeworkAttachmentEntry = _attachmentEntry(
          label: '作业附件',
          rawJson: hw.attachmentJson,
        );
        final submittedAttachmentEntry = _attachmentEntry(
          label: '提交附件',
          rawJson: hw.submittedAttachmentJson,
        );
        final answerAttachmentEntry = _attachmentEntry(
          label: '答案附件',
          rawJson: hw.answerAttachmentJson,
        );

        return Scaffold(
          backgroundColor: c.bg,
          floatingActionButton: canSubmit
              ? FloatingActionButton.extended(
                  onPressed: () async {
                    await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => AssignmentSubmissionScreen(
                          homework: hw,
                          courseName: courseName,
                        ),
                      ),
                    );
                  },
                  backgroundColor: AppColors.primary,
                  icon: Icon(
                    hw.submitted ? Icons.edit_rounded : Icons.upload_rounded,
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
              SliverAppBar(
                pinned: true,
                title: Text(
                  courseName,
                  style: AppTypography.titleMedium.copyWith(color: c.subtitle),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HomeworkStatusHeader(
                            homework: hw,
                          ).animate().fadeIn(duration: 300.ms),
                          const SizedBox(height: 20),
                          HomeworkDeadlineCard(homework: hw)
                              .animate(delay: 100.ms)
                              .fadeIn(duration: 250.ms)
                              .slideY(begin: 0.03, end: 0),
                          if (showRequirementSection) ...[
                            const SizedBox(height: 16),
                            HomeworkSectionCard(
                                  title: '作业要求',
                                  icon: Icons.description_rounded,
                                  iconColor: AppColors.info,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (hw.description != null &&
                                          hw.description!.isNotEmpty)
                                        HomeworkHtmlText(html: hw.description!),
                                      if (hasHomeworkAttachment) ...[
                                        if (hw.description != null &&
                                            hw.description!.isNotEmpty)
                                          const SizedBox(height: 12),
                                        FileAttachmentCard(
                                          entry: homeworkAttachmentEntry,
                                          onTap: () => _openAttachment(
                                            context,
                                            homeworkAttachmentEntry,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                                .animate(delay: 150.ms)
                                .fadeIn(duration: 250.ms)
                                .slideY(begin: 0.03, end: 0),
                          ],
                          if (showSubmissionSection) ...[
                            const SizedBox(height: 16),
                            HomeworkSectionCard(
                                  title: '我的提交',
                                  icon: Icons.upload_file_rounded,
                                  iconColor: AppColors.success,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (showSubmittedContent)
                                        HomeworkHtmlText(
                                          html: hw.submittedContent!,
                                        ),
                                      if (hw.submitTime != null) ...[
                                        if (showSubmittedContent)
                                          const SizedBox(height: 8),
                                        HomeworkMetaChip(
                                          icon: Icons.schedule_rounded,
                                          label:
                                              '提交于 ${formatHomeworkFullTime(hw.submitTime!)}',
                                        ),
                                      ],
                                      if (hw.isLateSubmission) ...[
                                        const SizedBox(height: 6),
                                        const HomeworkMetaChip(
                                          icon: Icons.warning_amber_rounded,
                                          label: '迟交',
                                          color: AppColors.warning,
                                        ),
                                      ],
                                      if (hasSubmittedAttachment) ...[
                                        if (showSubmittedContent ||
                                            hw.submitTime != null ||
                                            hw.isLateSubmission)
                                          const SizedBox(height: 12),
                                        FileAttachmentCard(
                                          entry: submittedAttachmentEntry,
                                          onTap: () => _openAttachment(
                                            context,
                                            submittedAttachmentEntry,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                                .animate(delay: 250.ms)
                                .fadeIn(duration: 250.ms)
                                .slideY(begin: 0.03, end: 0),
                          ],
                          if (hw.graded) ...[
                            const SizedBox(height: 16),
                            HomeworkGradeSection(
                                  homework: hw,
                                  courseId: courseId,
                                  courseName: courseName,
                                )
                                .animate(delay: 300.ms)
                                .fadeIn(duration: 300.ms)
                                .slideY(begin: 0.03, end: 0),
                          ],
                          if (showAnswerSection) ...[
                            const SizedBox(height: 16),
                            HomeworkSectionCard(
                                  title: '参考答案',
                                  icon: Icons.auto_stories_rounded,
                                  iconColor: const Color(0xFF8B5CF6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (hw.answerContent != null &&
                                          hw.answerContent!.isNotEmpty)
                                        HomeworkHtmlText(
                                          html: hw.answerContent!,
                                        ),
                                      if (hasAnswerAttachment) ...[
                                        if (hw.answerContent != null &&
                                            hw.answerContent!.isNotEmpty)
                                          const SizedBox(height: 12),
                                        FileAttachmentCard(
                                          entry: answerAttachmentEntry,
                                          onTap: () => _openAttachment(
                                            context,
                                            answerAttachmentEntry,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                )
                                .animate(delay: 350.ms)
                                .fadeIn(duration: 250.ms)
                                .slideY(begin: 0.03, end: 0),
                          ],
                          if (hw.comment != null && hw.comment!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            HomeworkSectionCard(
                              title: '我的备注',
                              icon: Icons.sticky_note_2_rounded,
                              iconColor: AppColors.primary,
                              child: Text(
                                hw.comment!,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: c.text,
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
      },
    );
  }
}
