import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';
import '../providers/course_workbench_models.dart';

class CourseCardTile extends StatelessWidget {
  const CourseCardTile({
    super.key,
    required this.card,
    required this.isEditing,
    required this.onTap,
    this.onLongPress,
    this.onMenu,
  });

  final ResolvedCourseCardModel card;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Rect>? onMenu;

  static TextStyle get _titleStyle => AppTypography.titleLarge.copyWith(
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get _statStyle => AppTypography.bodySmall.copyWith(
    fontWeight: FontWeight.w500,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  static List<String> _statLabels(ResolvedCourseCardModel card) => [
    if (card.pendingHomeworks > 0) '${card.pendingHomeworks} 待交',
    if (card.unreadNotifications > 0) '${card.unreadNotifications} 未读',
    '${card.totalFiles} 文件',
  ];

  /// Measures the same text and wrapping used by the tile. The grid takes the
  /// tallest card in each row, so sparse rows do not inherit empty title tracks.
  static double gridExtent(
    BuildContext context, {
    required ResolvedCourseCardModel card,
    required double width,
    required bool isEditing,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);
    final contentWidth = math.max(1.0, width - 32);
    Size measure(String text, TextStyle style, double maxWidth, int maxLines) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: textScaler,
        textDirection: textDirection,
        maxLines: maxLines,
        ellipsis: '…',
      )..layout(maxWidth: math.max(1, maxWidth));
      final size = painter.size;
      painter.dispose();
      return size;
    }

    final title = measure(
      card.displayTitle,
      _titleStyle,
      contentWidth - (resolveCourseIconOption(card.iconKey) == null ? 0 : 44),
      2,
    );
    final teacher = card.secondaryLabel.isEmpty
        ? 0.0
        : 6 +
              measure(
                card.secondaryLabel,
                AppTypography.bodySmall,
                contentWidth,
                1,
              ).height;
    final statWidth = math.max(1.0, contentWidth - (isEditing ? 48 : 0));
    var lineWidth = 0.0;
    var lines = 1;
    var lineHeight = 0.0;
    final labels = _statLabels(card);
    for (var index = 0; index < labels.length; index++) {
      final size = measure(
        labels[index],
        _statStyle.copyWith(
          fontWeight: index == labels.length - 1
              ? FontWeight.w400
              : FontWeight.w500,
        ),
        statWidth,
        1,
      );
      lineHeight = math.max(lineHeight, size.height);
      if (lineWidth > 0 && lineWidth + 10 + size.width > statWidth) {
        lines++;
        lineWidth = size.width;
      } else {
        lineWidth += (lineWidth == 0 ? 0 : 10) + size.width;
      }
    }
    final footerHeight = math.max(
      isEditing ? 44.0 : 0.0,
      lines * lineHeight + (lines - 1) * 4,
    );
    return (32 +
            math.max(32, title.height) +
            teacher +
            14 +
            1 +
            10 +
            footerHeight +
            2)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = StudyPalette.course(card.course.id);
    final palette = StudyPalette.of(context, tone);
    final teacher = card.secondaryLabel;
    final labels = _statLabels(card);

    return StudySurface(
      tone: tone,
      radius: 18,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      onLongPress: onLongPress,
      mouseCursor: isEditing
          ? SystemMouseCursors.grab
          : SystemMouseCursors.click,
      onSecondaryTapDown: isEditing && onMenu != null
          ? (details) => onMenu!(details.globalPosition & Size.zero)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tooltip(
                  triggerMode: TooltipTriggerMode.manual,
                  message: card.hasCustomAlias
                      ? '${card.displayTitle}\n${card.course.name}'
                      : card.course.name,
                  child: Text(
                    card.displayTitle,
                    style: _titleStyle.copyWith(color: c.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (resolveCourseIconOption(card.iconKey) != null) ...[
                const SizedBox(width: 12),
                CourseSeal(
                  courseId: card.course.id,
                  size: 32,
                  icon: resolveCourseIconOption(card.iconKey)?.icon,
                ),
              ],
            ],
          ),
          if (teacher.isNotEmpty) ...[
            const SizedBox(height: 6),
            Tooltip(
              triggerMode: TooltipTriggerMode.manual,
              message: teacher,
              child: Text(
                teacher,
                style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const Spacer(),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: palette.edge.withAlpha(110)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    for (var index = 0; index < labels.length; index++)
                      Text(
                        labels[index],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _statStyle.copyWith(
                          color: index == labels.length - 1
                              ? c.subtitle
                              : palette.accent,
                          fontWeight: index == labels.length - 1
                              ? FontWeight.w400
                              : FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (isEditing) ...[
                const SizedBox(width: 4),
                Builder(
                  builder: (context) => IconButton(
                    tooltip: '编辑课程',
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    onPressed: () {
                      final box = context.findRenderObject()! as RenderBox;
                      if (onMenu != null) {
                        onMenu!(box.localToGlobal(Offset.zero) & box.size);
                      } else {
                        onTap();
                      }
                    },
                    icon: Icon(Icons.more_horiz_rounded, color: palette.accent),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
