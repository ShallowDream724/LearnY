import 'package:flutter/material.dart';

enum HomeworkReminderMenuAction { markNoSubmissionNeeded, restoreReminder }

Future<HomeworkReminderMenuAction?> showHomeworkReminderMenu(
  BuildContext context, {
  required String title,
  required String courseName,
  required bool isNoSubmissionNeeded,
  Offset? anchor,
}) {
  final overlay =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()!
          as RenderBox;
  final position = anchor == null
      ? overlay.size.center(Offset.zero)
      : overlay.globalToLocal(anchor);
  final action = isNoSubmissionNeeded
      ? HomeworkReminderMenuAction.restoreReminder
      : HomeworkReminderMenuAction.markNoSubmissionNeeded;
  return showMenu<HomeworkReminderMenuAction>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 1, 1),
      Offset.zero & overlay.size,
    ),
    constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
    items: [
      PopupMenuItem(
        enabled: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (courseName.isNotEmpty)
                Text(
                  courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: action,
        child: Row(
          children: [
            Icon(
              isNoSubmissionNeeded
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isNoSubmissionNeeded ? '恢复提醒' : '标记为无需提交'),
                    const SizedBox(height: 4),
                    Text(
                      isNoSubmissionNeeded ? '重新显示在待交作业中' : '仅调整本地提醒，不影响网络学堂',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
