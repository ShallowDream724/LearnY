import '../../../core/design/course_glass.dart';
import '../../../core/design/course_icons/course_icon.dart';
import '../../../core/design/course_icons/course_icon_catalog.dart';
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
    this.onChooseIcon,
    this.onLongPress,
    this.onMenu,
  });

  final ResolvedCourseCardModel card;
  final VoidCallback? onChooseIcon;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<Rect>? onMenu;

  static const _controlExtent = 48.0;
  static const _glyphExtent = 40.0;
  static const _menuGap = 4.0;

  static TextStyle get _titleStyle => AppTypography.titleLarge.copyWith(
    inherit: false,
    fontSize: 16,
    height: 1.4,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
  );

  static TextStyle get _statStyle => AppTypography.bodySmall.copyWith(
    inherit: false,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
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

    final title = measure(card.displayTitle, _titleStyle, contentWidth, 2);
    final identityRow = math.max(
      isEditing ? _controlExtent : _glyphExtent,
      measure(
        card.secondaryLabel,
        AppTypography.bodySmall,
        contentWidth - 52,
        1,
      ).height,
    );
    final statWidth = math.max(
      1.0,
      contentWidth - (isEditing ? _controlExtent + _menuGap : 0),
    );
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
      isEditing ? _controlExtent : 0.0,
      lines * lineHeight + (lines - 1) * 4,
    );
    return (32 + title.height + 4 + identityRow + 6 + 1 + 8 + footerHeight + 2)
        .ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = StudyPalette.course(
      context,
      card.course.id,
      accentKey: card.accentKey,
    );
    final palette = StudyPalette.of(context, tone);
    final teacher = card.secondaryLabel;
    final labels = _statLabels(card);

    return CourseGlassSurface(
      tone: tone,
      radius: 18,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      onLongPress: onLongPress,
      mouseCursor: isEditing
          ? SystemMouseCursors.grab
          : SystemMouseCursors.click,
      onSecondaryTapDown: onMenu != null
          ? (details) => onMenu!(details.globalPosition & Size.zero)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
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
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Tooltip(
                  triggerMode: TooltipTriggerMode.manual,
                  message: teacher,
                  child: Text(
                    teacher,
                    style: AppTypography.bodySmall.copyWith(color: c.subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isEditing)
                IconButton(
                  tooltip: '更换图标',
                  onPressed: onChooseIcon,
                  constraints: const BoxConstraints.tightFor(
                    width: _controlExtent,
                    height: _controlExtent,
                  ),
                  padding: const EdgeInsets.all(4),
                  icon: CourseIcon(
                    option: courseIconFor(
                      key: card.iconKey,
                      courseName: card.course.name,
                    ),
                    color: Color.lerp(palette.accent, c.text, .12)!,
                  ),
                )
              else
                CourseIcon(
                  option: courseIconFor(
                    key: card.iconKey,
                    courseName: card.course.name,
                  ),
                  color: Color.lerp(palette.accent, c.text, .12)!,
                ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 6),
          Divider(height: 1, thickness: 1, color: palette.edge.withAlpha(110)),
          const SizedBox(height: 8),
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
                const SizedBox(width: _menuGap),
                Builder(
                  builder: (context) => IconButton(
                    tooltip: '编辑课程',
                    constraints: const BoxConstraints.tightFor(
                      width: _controlExtent,
                      height: _controlExtent,
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
