import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_materials.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/utils/deadline_time.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification, this.onTap});
  final NotificationSummary notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final published = tryParseEpochMillisToLocal(notification.publishTime);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notification.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall.copyWith(
                        color: StudyPalette.of(
                          context,
                          StudyPalette.course(context, notification.courseId),
                        ).accent,
                      ),
                    ),
                  ),
                  if (published != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${published.month}/${published.day}',
                      style: AppTypography.bodySmall.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                  ],
                  if (notification.markedImportant) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: '重要通知',
                      child: Text(
                        '重要',
                        style: AppTypography.labelMedium.copyWith(
                          color: c.infoAccent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                notification.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.titleMedium.copyWith(color: c.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
