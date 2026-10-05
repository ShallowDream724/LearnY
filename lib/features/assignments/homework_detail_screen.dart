import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/urls.dart' as urls;
import '../../core/database/database.dart' as db;
import '../../core/design/app_surfaces.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/files/file_models.dart';
import '../../core/files/widgets/file_attachment_card.dart';
import '../../core/router/router.dart';
import 'assignment_submission_screen.dart';
import 'providers/assignments_providers.dart';
import 'widgets/homework_detail_sections.dart';
import 'widgets/homework_workspace.dart';

class HomeworkDetailScreen extends ConsumerWidget {
  const HomeworkDetailScreen({
    super.key,
    required this.homeworkId,
    required this.courseId,
    required this.courseName,
  });

  final String homeworkId;
  final String courseId;
  final String courseName;

  Future<void> _openSubmission(
    BuildContext context,
    db.Homework homework,
  ) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AssignmentSubmissionScreen(
          homework: homework,
          courseName: courseName,
        ),
      ),
    );
  }

  Widget _attachment(
    BuildContext context, {
    required String label,
    required String? rawJson,
    required FileAttachmentKind kind,
  }) {
    final entry = FileAttachmentEntry.fromJson(
      label: label,
      rawJson: rawJson,
      courseId: courseId,
      courseName: courseName,
      fallbackKind: kind,
    );
    return FileAttachmentCard(
      entry: entry,
      onTap: () {
        final routeData = entry.routeData;
        if (routeData != null) {
          context.push(Routes.fileDetailFromData(routeData));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final homeworkAsync = ref.watch(homeworkDetailProvider(homeworkId));
    final homework = homeworkAsync.valueOrNull;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(courseName, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      bottomNavigationBar: homework != null && !homework.graded
          ? Material(
              color: c.surface,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ReadingWidth(
                      maxWidth: 1240,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Align(
                          alignment: Alignment.centerRight,
                          heightFactor: 1,
                          child: FilledButton.icon(
                            onPressed: () => _openSubmission(context, homework),
                            icon: Icon(
                              homework.submitted
                                  ? Icons.edit_outlined
                                  : Icons.upload_rounded,
                            ),
                            label: Text(homework.submitted ? '重新提交' : '提交作业'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: homeworkAsync.when(
        loading: () => const ListSkeleton(),
        error: (_, _) => AppEmptyState(
          icon: Icons.error_outline_rounded,
          title: '作业加载失败',
          action: OutlinedButton.icon(
            onPressed: () => ref.invalidate(homeworkDetailProvider(homeworkId)),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ),
        data: (hw) {
          if (hw == null) {
            return const AppEmptyState(
              icon: Icons.assignment_outlined,
              title: '作业未找到',
            );
          }
          final baseUri = Uri.parse(urls.learnHomeworkPage(courseId, hw.id));
          final showDescription = hasMeaningfulHomeworkHtml(hw.description);
          final showSubmittedContent = hasMeaningfulHomeworkHtml(
            hw.submittedContent,
          );
          final showAnswerContent = hasMeaningfulHomeworkHtml(hw.answerContent);
          final hasAttachment = hw.attachmentJson?.isNotEmpty == true;
          final hasSubmittedAttachment =
              hw.submittedAttachmentJson?.isNotEmpty == true;
          final hasAnswerAttachment =
              hw.answerAttachmentJson?.isNotEmpty == true;

          final requirements = <Widget>[
            HomeworkSectionCard(
              title: '作业要求',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDescription)
                    HomeworkHtmlText(html: hw.description!, baseUri: baseUri)
                  else if (!hasAttachment)
                    Text(
                      '暂无文字要求',
                      style: AppTypography.bodyMedium.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                  if (hasAttachment) ...[
                    if (showDescription) const SizedBox(height: 16),
                    _attachment(
                      context,
                      label: '作业附件',
                      rawJson: hw.attachmentJson,
                      kind: FileAttachmentKind.homeworkAttachment,
                    ),
                  ],
                ],
              ),
            ),
          ];
          final submission = <Widget>[
            HomeworkSectionCard(
              title: '当前提交',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!hw.submitted)
                    Text(
                      '尚未提交',
                      style: AppTypography.bodyMedium.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                  if (hw.submitted && hw.submitTime != null)
                    HomeworkMetaChip(
                      icon: Icons.schedule_rounded,
                      label: '提交于 ${formatHomeworkFullTime(hw.submitTime!)}',
                    ),
                  if (hw.submitted && hw.isLateSubmission) ...[
                    const SizedBox(height: 8),
                    const HomeworkMetaChip(
                      icon: Icons.warning_amber_rounded,
                      label: '迟交',
                      color: AppColors.warning,
                    ),
                  ],
                  if (hw.submitted && showSubmittedContent) ...[
                    if (hw.submitTime != null || hw.isLateSubmission)
                      const SizedBox(height: 16),
                    HomeworkHtmlText(
                      html: hw.submittedContent!,
                      baseUri: baseUri,
                    ),
                  ],
                  if (hw.submitted && hasSubmittedAttachment) ...[
                    const SizedBox(height: 16),
                    _attachment(
                      context,
                      label: '提交附件',
                      rawJson: hw.submittedAttachmentJson,
                      kind: FileAttachmentKind.homeworkSubmitted,
                    ),
                  ],
                  if (hw.submitted &&
                      !showSubmittedContent &&
                      !hasSubmittedAttachment &&
                      hw.submitTime == null)
                    Text(
                      '已提交',
                      style: AppTypography.bodyMedium.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                ],
              ),
            ),
            if (hw.graded)
              HomeworkGradeSection(
                homework: hw,
                courseId: courseId,
                courseName: courseName,
                htmlBaseUri: baseUri,
              ),
            if (showAnswerContent || hasAnswerAttachment)
              HomeworkSectionCard(
                title: '参考答案',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showAnswerContent)
                      HomeworkHtmlText(
                        html: hw.answerContent!,
                        baseUri: baseUri,
                      ),
                    if (hasAnswerAttachment) ...[
                      if (showAnswerContent) const SizedBox(height: 16),
                      _attachment(
                        context,
                        label: '答案附件',
                        rawJson: hw.answerAttachmentJson,
                        kind: FileAttachmentKind.homeworkAnswer,
                      ),
                    ],
                  ],
                ),
              ),
            if (hw.comment?.isNotEmpty == true)
              HomeworkSectionCard(
                title: '我的备注',
                child: Text(
                  hw.comment!,
                  style: AppTypography.bodyMedium.copyWith(color: c.text),
                ),
              ),
          ];
          return HomeworkWorkspace(
            identity: 'homework-$homeworkId',
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HomeworkStatusHeader(homework: hw),
                const SizedBox(height: 12),
                HomeworkDeadlineCard(homework: hw),
              ],
            ),
            requirements: _SectionList(children: requirements),
            work: _SectionList(children: submission),
          );
        },
      ),
    );
  }
}

class _SectionList extends StatelessWidget {
  const _SectionList({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(height: 24),
        children[index],
      ],
    ],
  );
}
