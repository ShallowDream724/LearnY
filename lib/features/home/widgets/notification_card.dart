/// Notification card — compact unread notification item.
import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/sync_provider.dart';

class NotificationCard extends StatelessWidget {
  final NotificationSummary notification;
  final VoidCallback? onTap;

  const NotificationCard({super.key, required this.notification, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Unread dot
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: notification.markedImportant
                    ? AppColors.warning
                    : AppColors.info,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Course + time
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notification.courseName,
                        style: AppTypography.labelSmall.copyWith(
                          color: c.subtitle,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatTime(notification.publishTime),
                      style: AppTypography.bodySmall.copyWith(
                        color: c.tertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Notification title
                Text(
                  notification.title,
                  style: AppTypography.titleMedium.copyWith(color: c.text),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (notification.publisher.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    notification.publisher,
                    style: AppTypography.bodySmall.copyWith(
                      color: c.tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Important marker
          if (notification.markedImportant) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '重要',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.warning,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    )),
    );
  }

  String _formatTime(String publishTime) {
    final ms = int.tryParse(publishTime);
    if (ms == null) return publishTime;

    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${date.month}/${date.day}';
  }
}
