import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/deadline_time.dart';

class UrgentDeadlineBanner extends ConsumerWidget {
  const UrgentDeadlineBanner({
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
      await ref.read(deadlineThresholdHoursProvider.notifier).setHours(hours);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final threshold = ref.watch(deadlineThresholdHoursProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              assignments.isEmpty
                  ? Icons.assignment_turned_in_outlined
                  : Icons.assignment_late_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                assignments.isNotEmpty
                    ? '${assignments.length} 项作业即将截止'
                    : pendingAssignments == 0
                    ? '暂无待交作业'
                    : '$pendingAssignments 项待交作业，近期无截止',
                style: assignments.isEmpty
                    ? theme.textTheme.bodySmall
                    : theme.textTheme.titleSmall,
              ),
            ),
            IconButton(
              tooltip: '截止提醒：${threshold}h',
              onPressed: () => _configure(context, ref),
              icon: const Icon(Icons.tune, size: 18),
            ),
          ],
        ),
        for (final homework in assignments)
          GestureDetector(
            onLongPressStart: onLongPress == null
                ? null
                : (details) => onLongPress!(homework, details.globalPosition),
            onSecondaryTapDown: onLongPress == null
                ? null
                : (details) => onLongPress!(homework, details.globalPosition),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap == null ? null : () => onTap!(homework),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
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
                      const Icon(Icons.chevron_right, size: 16),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
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
      return hours > 0 ? '剩余 ${hours}h ${minutes}m' : '剩余 $minutes 分钟';
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
    title: const Text('截止提醒'),
    content: Form(
      key: _form,
      child: TextFormField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(labelText: '提前提醒', suffixText: '小时'),
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
