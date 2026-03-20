/// Semantic theme colors — convenience extension on [BuildContext].
///
/// Usage:
///   final c = context.colors;
///   Container(color: c.surface, child: Text('Hello', style: TextStyle(color: c.text)));
///
/// This eliminates the repeated pattern:
///   isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary
///
/// across every widget's build() method.
library;

import 'package:flutter/material.dart';

import 'colors.dart';

/// Resolved semantic colors for the current brightness.
class AppThemeColors {
  final bool isDark;

  AppThemeColors._(this.isDark);

  // Backgrounds
  Color get bg => isDark ? AppColors.darkBackground : AppColors.lightBackground;
  Color get surface => isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get surfaceHigh =>
      isDark ? AppColors.darkSurfaceHigh : AppColors.lightSurfaceHigh;
  Color get border => isDark ? AppColors.darkBorder : AppColors.lightBorder;

  // Text
  Color get text => isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get subtitle =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get tertiary =>
      isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
}

/// Convenience extension for quick access to semantic colors.
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  AppThemeColors get colors => AppThemeColors._(isDark);
}
