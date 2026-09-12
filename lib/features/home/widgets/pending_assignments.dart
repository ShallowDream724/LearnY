import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_materials.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/app_toast.dart';
import '../../../core/design/responsive.dart';
import '../../../core/router/router.dart';
import 'package:go_router/go_router.dart';
import '../../assignments/providers/assignments_providers.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/deadline_time.dart';

class PendingAssignments extends ConsumerWidget {
  const PendingAssignments({
    super.key,
    required this.assignments,
    required this.pendingAssignments,
    this.onTap,
    this.onLongPress,
  });

  final List<HomeworkSummary> assignments;
  final int pendingAssignments;
  final void Function(HomeworkSummary hw)? onTap;
  final Future<void> Function(HomeworkSummary hw, Offset anchor)? onLongPress;

  Future<void> _configure(BuildContext context, WidgetRef ref) async {
    final hours = await showDialog<int>(
      context: context,
      builder: (_) => _DeadlineThresholdDialog(
        hours: ref.read(deadlineThresholdHoursProvider),
      ),
    );
    if (hours != null && context.mounted) {
      try {
        await ref.read(deadlineThresholdHoursProvider.notifier).setHours(hours);
      } catch (_) {
        if (context.mounted) AppToast.showError(context, message: '提醒设置未能保存');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.colors;
    final titleColor = c.text;
    final threshold = ref.watch(deadlineThresholdHoursProvider);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 2,
          children: [
            Text(
              '待办作业',
              style: AppTypography.headlineSmall.copyWith(color: titleColor),
            ),
            Tooltip(
              message: '调整待办显示范围',
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                onPressed: () => _configure(context, ref),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 5,
                  children: [
                    const Icon(Icons.alarm_outlined, size: 16),
                    Text('$threshold 小时'),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (assignments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              pendingAssignments == 0 ? '暂无待交作业' : '近期没有截止项',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        for (final homework in assignments.take(4))
          GestureDetector(
            onLongPressStart: onLongPress == null
                ? null
                : (details) => onLongPress!(homework, details.globalPosition),
            onSecondaryTapDown: onLongPress == null
                ? null
                : (details) => onLongPress!(homework, details.globalPosition),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap == null ? null : () => onTap!(homework),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              homework.courseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              homework.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        fit: FlexFit.tight,
                        child: Text(
                          _deadlineLabel(homework),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: homework.isOverdue
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (onLongPress != null && usesDesktopControls(context))
                        Builder(
                          builder: (buttonContext) => IconButton(
                            tooltip: '作业提醒设置',
                            icon: const Icon(Icons.more_horiz, size: 19),
                            onPressed: () {
                              final box =
                                  buttonContext.findRenderObject()!
                                      as RenderBox;
                              onLongPress!(
                                homework,
                                box.localToGlobal(box.size.center(Offset.zero)),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (pendingAssignments > 0)
          TextButton.icon(
            onPressed: () {
              ref.read(homeworkFilterProvider.notifier).state =
                  HomeworkFilter.pending;
              context.go(Routes.assignments);
            },
            icon: const Icon(Icons.arrow_forward, size: 16),
            label: Text('查看待交作业 · $pendingAssignments'),
          ),
      ],
    );
    return StudySurface(
      tone: StudyTone.ochre,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
      child: content,
    );
  }

  String _deadlineLabel(HomeworkSummary homework) {
    if (homework.isOverdue) return '已截止';
    final deadline = tryParseEpochMillisToLocal(homework.deadline);
    if (deadline == null) return '';
    final now = nowInShanghai();
    final remaining = deadline.difference(now);
    if (remaining.isNegative) return '已截止';
    if (remaining.inHours < 24) {
      final hours = remaining.inHours;
      final minutes = remaining.inMinutes.remainder(60);
      return hours > 0 ? '$hours 小时后' : '$minutes 分钟后';
    }
    return formatRelativeDeadlineLabel(deadline, now: now);
  }
}

class _DeadlineThresholdDialog extends StatefulWidget {
  const _DeadlineThresholdDialog({required this.hours});
  final int hours;
  @override
  State<_DeadlineThresholdDialog> createState() =>
      _DeadlineThresholdDialogState();
}

class _DeadlineThresholdDialogState extends State<_DeadlineThresholdDialog> {
  final _form = GlobalKey<FormState>();
  late final _controller = TextEditingController(text: widget.hours.toString());
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState!.validate()) {
      Navigator.pop(context, int.parse(_controller.text));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('待办显示范围'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: '未来截止范围',
          suffixText: '小时',
          helperText: '逾期作业始终显示',
        ),
        validator: (text) =>
            (int.tryParse(text ?? '') ?? 0) > 0 ? null : '请输入大于 0 的小时数',
        onFieldSubmitted: (_) => _submit(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('确定')),
    ],
  );
}
