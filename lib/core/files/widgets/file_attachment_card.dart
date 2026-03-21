import 'package:flutter/material.dart';

import '../../design/app_theme_colors.dart';
import '../../design/colors.dart';
import '../../design/typography.dart';
import '../file_models.dart';
import 'asset_status_icon.dart';

class FileAttachmentCard extends StatelessWidget {
  const FileAttachmentCard({
    super.key,
    required this.entry,
    this.onTap,
    this.showSize = true,
  });

  final FileAttachmentEntry entry;
  final VoidCallback? onTap;
  final bool showSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.info.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.attach_file_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: AppTypography.titleSmall.copyWith(color: c.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (showSize && entry.size.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.size,
                        style: AppTypography.bodySmall.copyWith(
                          color: c.subtitle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (entry.cacheKey != null)
                AssetStatusIcon(
                  assetKey: entry.cacheKey!,
                  idleColor: c.subtitle,
                )
              else
                Icon(Icons.download_rounded, size: 20, color: c.subtitle),
            ],
          ),
        ),
      ),
    );
  }
}
