import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'material_contrast.dart';
import 'study_control_surface.dart';

/// Headings are part of the scrolling content. Only glyphs receive a small
/// optical shadow; no rectangular paint extends behind or below the heading.
/// Actions use their own bounded Material buttons and normal state feedback.
class StudyHeaderContent extends StatelessWidget {
  const StudyHeaderContent({super.key, required this.child}) : _actions = false;
  const StudyHeaderContent.actions({super.key, required this.child})
    : _actions = true;
  final Widget child;
  final bool _actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = context.isDark;
    if (!_actions) {
      final shadows = [
        Shadow(
          color: (dark ? Colors.black : Colors.white).withAlpha(210),
          blurRadius: 2,
        ),
      ];
      return DefaultTextStyle.merge(
        style: TextStyle(shadows: shadows),
        child: IconTheme.merge(
          data: IconThemeData(shadows: shadows),
          child: child,
        ),
      );
    }
    final primary = readingForeground(theme.colorScheme.primary, dark: dark);
    final secondary = readingForeground(
      theme.colorScheme.onSurfaceVariant,
      dark: dark,
    );
    final fill = WidgetStatePropertyAll(controlSurfaceColor(dark: dark));
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
    // AppBar inserts its own inherited IconButtonTheme. Override that scope,
    // not only ThemeData, so the actual button material uses this surface.
    return Theme(
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
    );
  }
}
