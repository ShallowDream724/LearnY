import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'app_materials.dart';
import 'study_reading_ink.dart';

/// Headings are part of the scrolling content. Only glyphs receive a small
/// optical shadow. Soft wallpaper blur belongs to the background plane,
/// underneath all content; buttons have no opaque resting fill.
class StudyHeaderContent extends StatelessWidget {
  const StudyHeaderContent({
    super.key,
    required this.child,
    this.onWallpaper = true,
  }) : _actions = false;
  const StudyHeaderContent.actions({
    super.key,
    required this.child,
    this.onWallpaper = true,
  }) : _actions = true;
  final Widget child;
  final bool _actions;
  final bool onWallpaper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = context.isDark;
    Widget reading(List<Color> colors, Widget child) => onWallpaper
        ? StudyReadingInk(colors: colors, builder: (_, _) => child)
        : child;
    if (!_actions) {
      final shadows = [
        Shadow(
          color: (dark ? Colors.black : Colors.white).withAlpha(210),
          blurRadius: 2,
        ),
      ];
      return reading(
        [theme.colorScheme.onSurface],
        DefaultTextStyle.merge(
          style: TextStyle(shadows: shadows),
          child: IconTheme.merge(
            data: IconThemeData(shadows: shadows),
            child: child,
          ),
        ),
      );
    }
    final primary = theme.colorScheme.primary;
    final secondary = theme.colorScheme.onSurfaceVariant;
    const fill = WidgetStatePropertyAll(Colors.transparent);
    final shape = WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
    final scopedTheme = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: primary,
        onSurfaceVariant: secondary,
      ),
      textButtonTheme: TextButtonThemeData(
        style: (theme.textButtonTheme.style ?? const ButtonStyle()).copyWith(
          backgroundColor: fill,
          shape: shape,
          foregroundColor: WidgetStateProperty.resolveWith<Color>(
            (states) =>
                states.contains(WidgetState.disabled) ? secondary : primary,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: (theme.iconButtonTheme.style ?? const ButtonStyle()).copyWith(
          backgroundColor: fill,
          shape: shape,
          foregroundColor: WidgetStatePropertyAll(secondary),
        ),
      ),
    );
    // AppBar inserts its own inherited IconButtonTheme. Clear its resting fill
    // explicitly; press, hover and focus retain their existing state layers.
    return reading(
      [
        secondary,
        primary,
        theme.colorScheme.error,
        StudyPalette.of(context, StudyTone.ochre).accent,
      ],
      Theme(
        data: scopedTheme,
        child: IconButtonTheme(
          data: scopedTheme.iconButtonTheme,
          child: TextButtonTheme(
            data: scopedTheme.textButtonTheme,
            child: IconTheme.merge(
              data: IconThemeData(color: secondary),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
