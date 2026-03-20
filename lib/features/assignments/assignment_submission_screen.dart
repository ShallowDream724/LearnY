/// Assignment submission screen — Apple-level modal for submitting homework.
///
/// Design philosophy:
///   - Clean, focused interface: only what you need to submit
///   - Generous multiline text area with live character count
///   - Attachment: tap to add, shows file preview card, tap × to remove
///   - Submit confirmation with Apple-style action sheet
///   - Upload progress overlay with smooth animation
///   - Success → haptic + checkmark → auto-dismiss
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';

class AssignmentSubmissionScreen extends ConsumerStatefulWidget {
  final db.Homework homework;
  final String courseName;

  const AssignmentSubmissionScreen({
    super.key,
    required this.homework,
    required this.courseName,
  });

  @override
  ConsumerState<AssignmentSubmissionScreen> createState() =>
      _AssignmentSubmissionScreenState();
}

class _AssignmentSubmissionScreenState
    extends ConsumerState<AssignmentSubmissionScreen> {
  final _contentController = TextEditingController();
  final _contentFocus = FocusNode();

  PlatformFile? _attachment;
  bool _removeExistingAttachment = false;

  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Pre-fill with existing submission content if resubmitting
    if (widget.homework.submittedContent != null &&
        widget.homework.submittedContent!.isNotEmpty) {
      _contentController.text = _stripHtml(widget.homework.submittedContent!);
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  bool get _hasContent =>
      _contentController.text.trim().isNotEmpty ||
      _attachment != null ||
      _removeExistingAttachment;

  bool get _hasExistingAttachment =>
      widget.homework.submittedAttachmentJson != null &&
      widget.homework.submittedAttachmentJson!.isNotEmpty &&
      !_removeExistingAttachment;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _attachment = result.files.first;
        _removeExistingAttachment = true; // replace existing
      });
    }
  }

  void _removeAttachment() {
    setState(() {
      _attachment = null;
      if (widget.homework.submittedAttachmentJson != null) {
        _removeExistingAttachment = true;
      }
    });
  }

  Future<void> _submit() async {
    // Confirmation dialog
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ConfirmSheet(isResubmit: widget.homework.submitted),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.submitHomework(
        widget.homework.id,
        content: _contentController.text.trim(),
        attachmentPath: _attachment?.path,
        attachmentName: _attachment?.name,
        removeAttachment: _removeExistingAttachment && _attachment == null,
      );

      // Sync homework data to reflect new submission
      ref.read(syncStateProvider.notifier).syncHomeworksOnly();

      if (!mounted) return;

      // Haptic feedback
      HapticFeedback.mediumImpact();

      // Show success and dismiss
      await _showSuccess();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = '提交失败: $e';
      });
    }
  }

  Future<void> _showSuccess() async {
    // Brief success overlay, then pop
    setState(() => _submitting = false);
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _SuccessOverlay(),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => _confirmDiscard(),
        ),
        title: Text(
          widget.homework.submitted ? '重新提交' : '提交作业',
          style: AppTypography.titleMedium.copyWith(color: c.text),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withAlpha(100),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              child: Text(
                _submitting ? '提交中…' : '提交',
                style: AppTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Assignment info ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: c.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.assignment_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.homework.title,
                                style: AppTypography.titleSmall.copyWith(
                                  color: c.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.courseName,
                                style: AppTypography.bodySmall.copyWith(
                                  color: c.subtitle,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 200.ms),

                  const SizedBox(height: 20),

                  // ── Text input ──
                  Text(
                    '作业内容',
                    style: AppTypography.labelMedium.copyWith(
                      color: c.subtitle,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border, width: 0.5),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: _contentController,
                          focusNode: _contentFocus,
                          maxLines: 10,
                          minLines: 6,
                          style: AppTypography.bodyLarge.copyWith(
                            color: c.text,
                            height: 1.6,
                          ),
                          decoration: InputDecoration(
                            hintText: '输入作业内容…',
                            hintStyle: AppTypography.bodyLarge.copyWith(
                              color: c.tertiary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        // Character count
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_contentController.text.length} 字',
                            style: AppTypography.bodySmall.copyWith(
                              color: c.tertiary,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 100.ms).fadeIn(duration: 200.ms),

                  const SizedBox(height: 24),

                  // ── Attachment section ──
                  Text(
                    '附件',
                    style: AppTypography.labelMedium.copyWith(
                      color: c.subtitle,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (_attachment != null)
                    _FileCard(
                          name: _attachment!.name,
                          size: _attachment!.size,
                          onRemove: _removeAttachment,
                        )
                        .animate()
                        .fadeIn(duration: 200.ms)
                        .slideY(begin: 0.05, end: 0)
                  else if (_hasExistingAttachment)
                    _ExistingAttachmentCard(
                      onRemove: () =>
                          setState(() => _removeExistingAttachment = true),
                    ).animate().fadeIn(duration: 200.ms)
                  else
                    _AddFileButton(
                      onTap: _pickFile,
                    ).animate(delay: 150.ms).fadeIn(duration: 200.ms),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withAlpha(40),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: AppColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Submitting overlay ──
          if (_submitting)
            Container(
              color: Colors.black.withAlpha(80),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(30),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '正在提交…',
                        style: AppTypography.titleSmall.copyWith(color: c.text),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 150.ms),
        ],
      ),
    );
  }

  void _confirmDiscard() {
    if (!_hasContent ||
        _contentController.text.trim() ==
            _stripHtml(widget.homework.submittedContent ?? '')) {
      Navigator.of(context).pop();
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          '确定放弃编辑？',
                          style: AppTypography.titleSmall.copyWith(
                            color: c.text,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          '已输入的内容将不会保存',
                          style: AppTypography.bodySmall.copyWith(
                            color: c.subtitle,
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      InkWell(
                        onTap: () {
                          Navigator.of(ctx).pop();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            '放弃',
                            textAlign: TextAlign.center,
                            style: AppTypography.titleSmall.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        '继续编辑',
                        textAlign: TextAlign.center,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }
}

// ─────────────────────────────────────────────
//  File card (selected attachment)
// ─────────────────────────────────────────────

class _FileCard extends StatelessWidget {
  final String name;
  final int size;
  final VoidCallback onRemove;

  const _FileCard({
    required this.name,
    required this.size,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final ext = p.extension(name).replaceAll('.', '').toUpperCase();
    final sizeStr = _formatSize(size);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          // File type icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                ext.isNotEmpty ? ext : 'FILE',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: ext.length > 3 ? 8 : 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.titleSmall.copyWith(color: c.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  sizeStr,
                  style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, size: 20, color: c.subtitle),
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────
//  Existing attachment indicator
// ─────────────────────────────────────────────

class _ExistingAttachmentCard extends StatelessWidget {
  final VoidCallback onRemove;

  const _ExistingAttachmentCard({required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 20,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '已有附件',
                  style: AppTypography.titleSmall.copyWith(color: c.text),
                ),
                const SizedBox(height: 2),
                Text(
                  '上次提交的附件将保留',
                  style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: AppColors.error.withAlpha(180),
            ),
            onPressed: onRemove,
            tooltip: '删除附件',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Add file button
// ─────────────────────────────────────────────

class _AddFileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AddFileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: c.border,
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 28, color: c.subtitle),
            const SizedBox(height: 6),
            Text(
              '选择文件',
              style: AppTypography.labelMedium.copyWith(color: c.subtitle),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  Confirm sheet
// ─────────────────────────────────────────────

class _ConfirmSheet extends StatelessWidget {
  final bool isResubmit;

  const _ConfirmSheet({required this.isResubmit});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      isResubmit ? '确认重新提交？' : '确认提交？',
                      style: AppTypography.titleSmall.copyWith(color: c.text),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      isResubmit ? '将覆盖上次提交的内容' : '提交后仍可重新提交',
                      style: AppTypography.bodySmall.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  InkWell(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        isResubmit ? '重新提交' : '提交',
                        textAlign: TextAlign.center,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: () => Navigator.of(context).pop(false),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    '取消',
                    textAlign: TextAlign.center,
                    style: AppTypography.titleSmall.copyWith(color: c.text),
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

// ─────────────────────────────────────────────
//  Success overlay
// ─────────────────────────────────────────────

class _SuccessOverlay extends StatefulWidget {
  const _SuccessOverlay();

  @override
  State<_SuccessOverlay> createState() => _SuccessOverlayState();
}

class _SuccessOverlayState extends State<_SuccessOverlay> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child:
          Container(
                padding: const EdgeInsets.all(36),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(30),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.success.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: AppColors.success,
                        size: 32,
                      ),
                    ).animate().scale(
                      begin: const Offset(0.5, 0.5),
                      end: const Offset(1, 1),
                      curve: Curves.elasticOut,
                      duration: 600.ms,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '提交成功',
                      style: AppTypography.titleMedium.copyWith(color: c.text),
                    ),
                  ],
                ),
              )
              .animate()
              .fadeIn(duration: 200.ms)
              .scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                curve: Curves.easeOutBack,
                duration: 300.ms,
              ),
    );
  }
}
