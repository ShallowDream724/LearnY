import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/file_type_utils.dart';
import '../../../core/design/typography.dart';
import '../../../core/files/file_asset_runtime.dart';
import '../../../core/files/file_models.dart';
import '../../../core/services/file_download_service.dart';
import '../providers/file_bookmark_providers.dart';
import 'file_action_menu.dart';
import 'file_type_mark.dart';

class FileCard extends ConsumerWidget {
  const FileCard({
    super.key,
    required this.item,
    this.hideCourseName = false,
    this.isFavorite = false,
    this.forceDownloaded = false,
    this.onTap,
    this.trailing,
  });

  final FileDetailItem item;
  final bool hideCourseName;
  final bool isFavorite;
  final bool forceDownloaded;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final ext = FileTypeUtils.extractExt(item.title, item.fileType);
    final course = StudyPalette.of(
      context,
      StudyPalette.course(context, item.courseId),
    );
    final jade = StudyPalette.of(context, StudyTone.jade);
    final ochre = StudyPalette.of(context, StudyTone.ochre);
    final downloadStates = ref.watch(fileDownloadProvider);
    final runtime = ref
        .read(fileAssetRuntimeResolverProvider)
        .resolveDetailItem(item, downloadStates);
    final resolvedFavorite =
        ref.watch(fileBookmarkStateProvider(item.cacheKey)).valueOrNull ??
        isFavorite;
    final isDownloaded = forceDownloaded || runtime.isDownloaded;
    final time = _formatTimeAgo(item.uploadTime);

    Future<void> openMenu(Offset anchor) => showFileActionMenu(
      context,
      item: item,
      isFavorite: resolvedFavorite,
      isDownloading: runtime.isDownloading,
      anchor: anchor,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPressStart: (details) => openMenu(details.globalPosition),
      onSecondaryTapDown: (details) => openMenu(details.globalPosition),
      child: Material(
        color: c.surface.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                FileTypeMark(extension: ext),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hideCourseName && item.courseName.isNotEmpty) ...[
                        Text(
                          item.courseName,
                          style: AppTypography.bodySmall.copyWith(
                            color: course.accent,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: AppTypography.titleMedium.copyWith(
                                color: c.text,
                                fontSize: 14,
                                height: 1.45,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (item.markedImportant)
                            Padding(
                              padding: const EdgeInsets.only(left: 6, top: 2),
                              child: Tooltip(
                                message: '教师标记为重要',
                                child: Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: ochre.accent,
                                ),
                              ),
                            ),
                          if (resolvedFavorite)
                            Padding(
                              padding: const EdgeInsets.only(left: 6, top: 2),
                              child: Tooltip(
                                message: '已收藏',
                                child: Icon(
                                  Icons.bookmark_rounded,
                                  size: 16,
                                  color: ochre.accent,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (item.isNew)
                            Text(
                              '未读',
                              style: AppTypography.labelSmall.copyWith(
                                color: c.infoAccent,
                              ),
                            ),
                          Text(
                            item.size.isNotEmpty
                                ? item.size
                                : '${item.rawSize} B',
                            style: AppTypography.bodySmall.copyWith(
                              color: c.subtitle,
                            ),
                          ),
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: AppTypography.bodySmall.copyWith(
                                color: c.tertiary,
                              ),
                            ),
                          if (isDownloaded)
                            Text(
                              '已下载',
                              style: AppTypography.labelSmall.copyWith(
                                color: jade.accent,
                              ),
                            ),
                          if (runtime.isDownloading)
                            Text(
                              '下载中 ${(runtime.progress * 100).toInt()}%',
                              style: AppTypography.labelSmall.copyWith(
                                color: c.infoAccent,
                              ),
                            ),
                        ],
                      ),
                      if (runtime.isDownloading) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: runtime.progress > 0
                                ? runtime.progress
                                : null,
                            minHeight: 3,
                            backgroundColor: c.surfaceHigh,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
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
