import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/urls.dart' as urls;
import '../../core/database/database.dart' as db;
import '../../core/design/action_sheet.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/files/file_models.dart';
import '../../core/files/widgets/file_attachment_card.dart';
import '../../core/router/router.dart';
import 'submission/homework_submission_controller.dart';
import 'submission/homework_submission_models.dart';
import 'widgets/homework_detail_sections.dart';
import 'widgets/homework_workspace.dart';

class AssignmentSubmissionScreen extends ConsumerStatefulWidget {
  const AssignmentSubmissionScreen({
    super.key,
    required this.homework,
    required this.courseName,
  });
  final db.Homework homework;
  final String courseName;

  @override
  ConsumerState<AssignmentSubmissionScreen> createState() =>
      _AssignmentSubmissionScreenState();
}

class _AssignmentSubmissionScreenState
    extends ConsumerState<AssignmentSubmissionScreen> {
  final _contentController = TextEditingController();
  final _contentFocus = FocusNode();
  late final HomeworkSubmissionSeed _submissionSeed;
  bool _allowPop = false;
  bool _confirmationOpen = false;

  @override
  void initState() {
    super.initState();
    _submissionSeed = HomeworkSubmissionSeed.fromHomework(widget.homework);
    _contentController.text = _submissionSeed.initialContent;
    _contentController.addListener(_handleContentChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_handleContentChanged);
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  AutoDisposeStateNotifierProvider<
    HomeworkSubmissionController,
    HomeworkSubmissionState
  >
  get _submissionProvider =>
      homeworkSubmissionControllerProvider(_submissionSeed);

  void _handleContentChanged() => ref
      .read(_submissionProvider.notifier)
      .updateContent(_contentController.text);

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final path = file.path;
    if (path == null || path.isEmpty) return;
    ref
        .read(_submissionProvider.notifier)
        .selectAttachment(
          HomeworkSubmissionAttachment(
            path: path,
            name: file.name,
            sizeBytes: file.size,
          ),
        );
  }

  Future<void> _submit() async {
    if (_confirmationOpen || ref.read(_submissionProvider).isSubmitting) return;
    setState(() => _confirmationOpen = true);
    final confirmed = await AppActionSheet.show(
      context,
      title: widget.homework.submitted ? '确认重新提交？' : '确认提交？',
      subtitle: widget.homework.submitted ? '将覆盖上次提交的内容' : '提交后仍可重新提交',
      confirmLabel: widget.homework.submitted ? '重新提交' : '提交',
    );
    if (!mounted) return;
    setState(() => _confirmationOpen = false);
    if (confirmed != true) return;
    _contentFocus.unfocus();
    final success = await ref.read(_submissionProvider.notifier).submit();
    if (mounted && success) HapticFeedback.mediumImpact();
  }

  void _leave([bool? result]) {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(result);
    });
  }

  Future<void> _confirmDiscard() async {
    final state = ref.read(_submissionProvider);
    if (state.isSubmitting || _confirmationOpen) return;
    if (state.status == HomeworkSubmissionStatus.success) {
      _leave(true);
      return;
    }
    if (!state.hasUnsavedChanges) {
      _leave();
      return;
    }
    setState(() => _confirmationOpen = true);
    final discard = await AppActionSheet.show(
      context,
      title: '放弃本次修改？',
      subtitle: '本次输入的内容与附件选择将不会保存。',
      confirmLabel: '放弃修改',
      confirmColor: AppColors.error,
      cancelLabel: '继续编辑',
    );
    if (!mounted) return;
    setState(() => _confirmationOpen = false);
    if (discard == true) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final state = ref.watch(_submissionProvider);
    final complete = state.status == HomeworkSubmissionStatus.success;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          leading: IconButton(
            tooltip: complete ? '返回作业' : '关闭',
            icon: const Icon(Icons.close_rounded),
            onPressed: state.isSubmitting ? null : _confirmDiscard,
          ),
          title: Text(
            complete
                ? '提交成功'
                : widget.homework.submitted
                ? '重新提交'
                : '提交作业',
          ),
        ),
        bottomNavigationBar: Material(
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
                        onPressed: complete
                            ? () => _leave(true)
                            : state.isSubmitting || _confirmationOpen
                            ? null
                            : _submit,
                        icon: state.isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                complete
                                    ? Icons.arrow_back_rounded
                                    : Icons.upload_rounded,
                              ),
                        label: Text(
                          complete
                              ? '返回作业'
                              : state.isSubmitting
                              ? '正在提交'
                              : '提交',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        body: complete
            ? AppEmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: '提交成功',
                message: widget.homework.title,
              )
            : HomeworkWorkspace(
                identity: 'submit-${widget.homework.id}',
                header: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.homework.title,
                      style: AppTypography.headlineSmall.copyWith(
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.courseName,
                      style: AppTypography.bodyMedium.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                    const SizedBox(height: 12),
                    HomeworkDeadlineCard(homework: widget.homework),
                  ],
                ),
                requirements: HomeworkSectionCard(
                  title: '作业要求',
                  child: _buildRequirements(),
                ),
                work: _buildEditor(state),
              ),
      ),
    );
  }

  Widget _buildRequirements() {
    final hw = widget.homework;
    final baseUri = Uri.parse(urls.learnHomeworkPage(hw.courseId, hw.id));
    final entry = FileAttachmentEntry.fromJson(
      label: '作业附件',
      rawJson: hw.attachmentJson,
      courseId: hw.courseId,
      courseName: widget.courseName,
      fallbackKind: FileAttachmentKind.homeworkAttachment,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasMeaningfulHomeworkHtml(hw.description)) ...[
          HomeworkHtmlText(html: hw.description!, baseUri: baseUri),
        ] else if (hw.attachmentJson?.isNotEmpty != true) ...[
          const Text('暂无文字要求'),
        ],
        if (hw.attachmentJson?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          FileAttachmentCard(
            entry: entry,
            onTap: () {
              final routeData = entry.routeData;
              if (routeData != null) {
                context.push(Routes.fileDetailFromData(routeData));
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildEditor(HomeworkSubmissionState state) {
    final c = context.colors;
    final attachment = state.attachment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('提交内容', style: AppTypography.titleMedium.copyWith(color: c.text)),
        const SizedBox(height: 12),
        TextField(
          controller: _contentController,
          focusNode: _contentFocus,
          readOnly: state.isSubmitting,
          minLines: 8,
          maxLines: 16,
          style: AppTypography.bodyLarge.copyWith(color: c.text, height: 1.6),
          decoration: InputDecoration(
            hintText: '输入作业内容',
            counterText: '${state.characterCount} 字',
            filled: true,
            fillColor: c.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                '提交附件',
                style: AppTypography.titleMedium.copyWith(color: c.text),
              ),
            ),
            if (attachment != null || state.hasExistingAttachment)
              TextButton.icon(
                onPressed: state.isSubmitting ? null : _pickFile,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('更换'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (attachment != null || state.hasExistingAttachment)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: c.border),
            ),
            leading: const Icon(Icons.attach_file_rounded),
            title: Text(attachment?.name ?? '已提交的附件'),
            subtitle: Text(
              attachment != null
                  ? _formatSize(attachment.sizeBytes)
                  : '保留上次提交的附件',
            ),
            trailing: IconButton(
              tooltip: '移除附件',
              onPressed: state.isSubmitting
                  ? null
                  : () => ref
                        .read(_submissionProvider.notifier)
                        .removeAttachment(),
              icon: const Icon(Icons.close_rounded),
            ),
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: state.isSubmitting ? null : _pickFile,
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('选择文件'),
            ),
          ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 20),
          Semantics(
            liveRegion: true,
            child: Text(
              state.errorMessage!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
