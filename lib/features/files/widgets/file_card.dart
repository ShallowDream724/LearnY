/// Reusable file card widget — used in global files list and course detail.
///
/// Shows: file type icon, course name, title, size/time, download state,
/// importance badge, new badge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/file_type_utils.dart';
import '../../../core/files/file_asset_runtime.dart';
import '../../../core/files/file_models.dart';
import '../../../core/services/file_download_service.dart';

class FileCard extends ConsumerWidget {
  final FileDetailItem item;
  final bool hideCourseName;
  final bool isFavorite;
  final bool forceDownloaded;
  final VoidCallback? onTap;

  const FileCard({
    super.key,
    required this.item,
    this.hideCourseName = false,
    this.isFavorite = false,
    this.forceDownloaded = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    final ext = FileTypeUtils.extractExt(item.title, item.fileType);
    final color = FileTypeUtils.color(ext);

    final downloadStates = ref.watch(fileDownloadProvider);
    final runtime = ref
        .read(fileAssetRuntimeResolverProvider)
        .resolveDetailItem(item, downloadStates);
    final isDownloaded = forceDownloaded || runtime.isDownloaded;
    final isDownloading = runtime.isDownloading;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            // File type icon
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      FileTypeUtils.icon(ext),
                      color: color,
                      size: 21,
                    ),
                  ),
                  // Download status indicator
                  if (isDownloaded)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: c.surface, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 7,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (isDownloading)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          value: runtime.progress,
                          color: color,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // File info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Course name (if shown)
                  if (!hideCourseName)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        item.courseName,
                        style: TextStyle(
                          fontSize: 11,
                          color: c.tertiary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  // Title row + badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isNew)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.info.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (item.markedImportant)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                        ),
                      if (isFavorite)
                        const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.bookmark_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Metadata row
                  Row(
                    children: [
                      Text(
                        ext.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.size.isNotEmpty ? item.size : '${item.rawSize} B',
                        style: TextStyle(fontSize: 11, color: c.tertiary),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(item.uploadTime),
                        style: TextStyle(fontSize: 11, color: c.tertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: c.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimeAgo(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
      if (diff.inHours < 24) return '${diff.inHours}小时前';
      if (diff.inDays < 7) return '${diff.inDays}天前';
      if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}周前';
      return '${dt.month}/${dt.day}';
    } catch (_) {
      return '';
    }
  }
}
