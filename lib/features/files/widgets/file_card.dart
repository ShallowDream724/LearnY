/// Reusable file card widget — used in global files list and course detail.
///
/// Shows: file type icon, course name, title, size/time, download state,
/// importance badge, new badge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/services/file_download_service.dart';
import '../file_detail_screen.dart' show fileIcon, fileColor;

class FileCard extends ConsumerWidget {
  final db.CourseFile file;
  final String courseName;
  final bool hideCourseName;
  final VoidCallback? onTap;

  const FileCard({
    super.key,
    required this.file,
    required this.courseName,
    this.hideCourseName = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final sub =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiary =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final ext = _extractExt(file.title, file.fileType);
    final color = fileColor(ext);

    // Download state
    final downloadStates = ref.watch(fileDownloadProvider);
    final downloadState = downloadStates[file.id];
    final isDownloaded =
        downloadState?.status == DownloadStatus.downloaded ||
            file.localDownloadState == 'downloaded';
    final isDownloading =
        downloadState?.status == DownloadStatus.downloading;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 0.5),
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
                    child: Icon(fileIcon(ext), color: color, size: 21),
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
                          border: Border.all(color: surface, width: 1.5),
                        ),
                        child: const Icon(Icons.check,
                            size: 7, color: Colors.white),
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
                          value: downloadState?.progress,
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
                        courseName,
                        style: TextStyle(
                          fontSize: 11,
                          color: tertiary,
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
                          file.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (file.isNew)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.info.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'NEW',
                            style: TextStyle(
                              color: AppColors.info,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      if (file.markedImportant)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.star_rounded,
                              size: 14, color: AppColors.warning),
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
                        file.size.isNotEmpty
                            ? file.size
                            : '${file.rawSize} B',
                        style: TextStyle(fontSize: 11, color: tertiary),
                      ),
                      const Spacer(),
                      Text(
                        _formatTimeAgo(file.uploadTime),
                        style: TextStyle(fontSize: 11, color: tertiary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Chevron
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: tertiary),
            ),
          ],
        ),
      ),
    );
  }

  static String _extractExt(String title, String fileType) {
    if (fileType.isNotEmpty) return fileType.toLowerCase();
    final dot = title.lastIndexOf('.');
    if (dot != -1 && dot < title.length - 1) {
      return title.substring(dot + 1).toLowerCase();
    }
    return '';
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
