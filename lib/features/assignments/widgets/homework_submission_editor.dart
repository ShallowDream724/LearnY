import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../submission/homework_submission_models.dart';
import 'homework_layout_tokens.dart';

/// One writing surface owns the sequence: compose, attach, review, submit.
/// Picking, confirmation and network state remain owned by the screen/controller.
class HomeworkSubmissionEditor extends StatelessWidget {
  const HomeworkSubmissionEditor({
    super.key,
    required this.state,
    required this.controller,
    required this.focusNode,
    required this.onPickFile,
    required this.onRemoveAttachment,
    required this.onSubmit,
  });

  final HomeworkSubmissionState state;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPickFile;
  final VoidCallback onRemoveAttachment;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final attachment = state.attachment;
    final hasAttachment = attachment != null || state.hasExistingAttachment;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(
            color: c.text.withValues(alpha: .035),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(homeworkContentInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '提交内容',
                    style: AppTypography.titleMedium.copyWith(color: c.text),
                  ),
                ),
                Text(
                  '${state.characterCount} 字',
                  style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              focusNode: focusNode,
              readOnly: state.isSubmitting,
              minLines: 7,
              maxLines: 16,
              scrollPadding: const EdgeInsets.all(32),
              style: AppTypography.bodyLarge.copyWith(
                color: c.text,
                height: 1.7,
              ),
              decoration: InputDecoration(
                hintText: '在这里填写作业内容…',
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: c.border.withValues(alpha: .65),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (hasAttachment) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.description_outlined, color: c.infoAccent),
                title: Text(
                  attachment?.name ?? '已提交的附件',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  attachment != null
                      ? _formatSize(attachment.sizeBytes)
                      : '保留上次提交的附件',
                ),
                trailing: IconButton(
                  tooltip: '移除附件',
                  onPressed: state.isSubmitting ? null : onRemoveAttachment,
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.isSubmitting ? null : onPickFile,
                icon: Icon(
                  hasAttachment
                      ? Icons.swap_horiz_rounded
                      : Icons.attach_file_rounded,
                  size: 20,
                ),
                label: Text(hasAttachment ? '更换附件' : '添加附件'),
              ),
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: c.border.withValues(alpha: .65)),
            const SizedBox(height: 16),
            if (state.errorMessage != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  state.errorMessage!,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 12,
              children: [
                Text(
                  '提交前请核对内容与附件',
                  style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                ),
                FilledButton.icon(
                  onPressed: state.isSubmitting ? null : onSubmit,
                  icon: state.isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.arrow_upward_rounded, size: 20),
                  label: Text(state.isSubmitting ? '正在提交' : '提交作业'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
