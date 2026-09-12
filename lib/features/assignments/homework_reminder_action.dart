import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/homework_reminder_menu.dart';
import '../../core/providers/providers.dart';

Future<void> showAssignmentReminderAction({
  required BuildContext context,
  required WidgetRef ref,
  required Homework homework,
  required String courseName,
  required bool noSubmissionNeeded,
  required Offset anchor,
}) async {
  final action = await showHomeworkReminderMenu(
    context,
    title: homework.title,
    courseName: courseName,
    isNoSubmissionNeeded: noSubmissionNeeded,
    anchor: anchor,
  );
  if (action == null || !context.mounted) return;

  final value = action == HomeworkReminderMenuAction.markNoSubmissionNeeded;
  Future<void> save(bool next) => ref
      .read(homeworkReminderActionsProvider)
      .setNoSubmissionNeeded(homework.id, noSubmissionNeeded: next);

  try {
    await save(value);
    if (!context.mounted) return;
    AppToast.showInfo(
      context,
      message: value ? '已设为无需提交' : '已恢复提交提醒',
      actionLabel: '撤销',
      onAction: () => unawaited(
        save(!value).catchError((Object _) {
          if (context.mounted) {
            AppToast.showError(context, message: '提醒设置未能恢复');
          }
        }),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      AppToast.showError(context, message: '提醒设置未能保存');
    }
  }
}
