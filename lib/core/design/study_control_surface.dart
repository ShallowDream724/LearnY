import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'material_contrast.dart';

/// A compact functional control with a stable reading surface inside its
/// rounded bounds. Features own padding, semantics, layout and interaction.
/// No fog, wallpaper mask or gradient is painted outside the control.
class StudyControlSurface extends StatelessWidget {
  const StudyControlSurface({
    super.key,
    required this.colors,
    required this.builder,
    this.radius = 12,
  });
  final List<Color> colors;
  final Widget Function(BuildContext context, List<Color> inks) builder;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final inks = [
      for (final color in colors) readingForeground(color, dark: dark),
    ];
    return Material(
      color: controlSurfaceColor(dark: dark),
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: builder(context, inks),
    );
  }
}

/// A fixed material avoids wallpaper classification, tone changes while
/// scrolling and repeated backdrop filters. Resolved semantic inks maintain
/// contrast even against the worst possible black/white backdrop.
Color controlSurfaceColor({required bool dark}) =>
    (dark ? const Color(0xFF20242D) : Colors.white).withAlpha(240);
