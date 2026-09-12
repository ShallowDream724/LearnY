import 'package:flutter/material.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';
import '../providers/search_models.dart';

class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader({
    super.key,
    required this.section,
    required this.count,
    required this.collapsed,
    required this.onTap,
  });

  final SearchSectionMeta section;
  final int count;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  section.title,
                  style: AppTypography.titleSmall.copyWith(color: c.text),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$count',
                style: AppTypography.labelMedium.copyWith(color: c.subtitle),
              ),
              const SizedBox(width: 16),
              Expanded(child: Divider(color: c.border)),
              const SizedBox(width: 8),
              Icon(
                collapsed
                    ? Icons.expand_more_rounded
                    : Icons.expand_less_rounded,
                size: 18,
                color: c.subtitle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SearchResultTile extends StatelessWidget {
  const SearchResultTile({
    super.key,
    required this.result,
    required this.onTap,
  });
  final SearchResult result;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final course = StudyPalette.of(
      context,
      StudyPalette.course(context, result.courseId),
    );
    final isCourse = result.kind == SearchResultKind.course;
    return Material(
      color: c.surface.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              if (isCourse) ...[
                CourseSeal(courseId: result.courseId, size: 36),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: AppTypography.titleMedium.copyWith(
                        color: c.text,
                        fontSize: 15,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      result.subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: isCourse ? c.subtitle : course.accent,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.isFavorite || result.isDownloaded) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (result.isFavorite)
                            Text(
                              '已收藏',
                              style: AppTypography.labelSmall.copyWith(
                                color: StudyPalette.of(
                                  context,
                                  StudyTone.ochre,
                                ).accent,
                              ),
                            ),
                          if (result.isDownloaded)
                            Text(
                              '已下载',
                              style: AppTypography.labelSmall.copyWith(
                                color: StudyPalette.of(
                                  context,
                                  StudyTone.jade,
                                ).accent,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
