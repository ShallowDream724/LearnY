import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../providers/course_workbench_models.dart';

const _cardColors = [
  AppColors.primary,
  Color(0xFF06B6D4),
  Color(0xFF8B5CF6),
  Color(0xFFEC4899),
  Color(0xFFF97316),
  Color(0xFF14B8A6),
  Color(0xFF6366F1),
  Color(0xFFEAB308),
];

class CourseCardTile extends StatelessWidget {
  const CourseCardTile({
    super.key,
    required this.card,
    required this.colorIndex,
    required this.isEditing,
    required this.onTap,
    this.onLongPress,
  });

  final ResolvedCourseCardModel card;
  final int colorIndex;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = _cardColors[colorIndex % _cardColors.length];
    final iconOption = resolveCourseIconOption(card.iconKey);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isEditing
                  ? accent.withAlpha(context.isDark ? 78 : 96)
                  : c.border,
              width: isEditing ? 0.9 : 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accent.withAlpha(context.isDark ? 40 : 20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: iconOption != null
                          ? Icon(iconOption.icon, color: accent, size: 18)
                          : Text(
                              _initials(card.course.name),
                              style: AppTypography.labelSmall.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  const Spacer(),
                  if (isEditing)
                    IconButton(
                      tooltip: '编辑课程',
                      onPressed: onTap,
                      icon: Icon(Icons.more_horiz_rounded, color: c.subtitle),
                    )
                  else if (card.aggregateBadgeCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.unreadBadge,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${card.aggregateBadgeCount}',
                        style: AppTypography.labelSmall.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                card.displayTitle,
                style: AppTypography.titleMedium.copyWith(color: c.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                card.secondaryLabel,
                style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _MicroStat(
                    icon: Icons.notifications_none_rounded,
                    count: card.unreadNotifications,
                    color: card.unreadNotifications > 0
                        ? AppColors.info
                        : c.tertiary,
                  ),
                  _MicroStat(
                    icon: Icons.assignment_outlined,
                    count: card.pendingHomeworks,
                    color: card.pendingHomeworks > 0
                        ? AppColors.warning
                        : c.tertiary,
                  ),
                  _MicroStat(
                    icon: Icons.folder_outlined,
                    count: card.totalFiles,
                    color: c.tertiary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '';
    final chars = name.runes.toList();
    if (chars.isNotEmpty && chars[0] > 127) {
      return String.fromCharCode(chars[0]);
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }
}

class _MicroStat extends StatelessWidget {
  const _MicroStat({
    required this.icon,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          count.toString(),
          style: AppTypography.bodySmall.copyWith(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
