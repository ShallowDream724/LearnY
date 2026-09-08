/// LearnY Design System — Typography
///
/// Bundled screen-reading type; no runtime network dependency.
/// No emoji — all visual elements use Material Symbols or custom SVGs.
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'app_font.dart';

/// 4dp base spacing unit.
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Standard card padding.
  static const EdgeInsets cardPadding = EdgeInsets.symmetric(
    horizontal: base,
    vertical: md,
  );

  /// Standard page padding.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(
    horizontal: base,
    vertical: sm,
  );

  /// Standard section spacing.
  static const double sectionGap = xl;

  /// Standard card border radius.
  static const double cardRadius = 18;

  /// Small chip / badge radius.
  static const double chipRadius = 10;

  /// Bottom nav bar height.
  static const double bottomNavHeight = 64;
}

/// Shared type scale using the host platform's installed font.
abstract final class AppTypography {
  static String get fontFamily => AppFont.family;

  static List<String>? get fontFamilyFallback =>
      switch (defaultTargetPlatform) {
        TargetPlatform.windows => const ['Microsoft YaHei', 'Segoe UI'],
        _ => null,
      };

  // ─────────── Headlines ───────────

  /// Page title — large and bold.
  static TextStyle get headlineLarge => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 28,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0,
  );

  /// Section title.
  static TextStyle get headlineMedium => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0,
  );

  /// Subsection title.
  static TextStyle get headlineSmall => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
  );

  // ─────────── Titles ───────────

  /// Card title / list tile title.
  static TextStyle get titleLarge => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Smaller title — tabs, chips.
  static TextStyle get titleMedium => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  static TextStyle get titleSmall => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ─────────── Body ───────────

  /// Primary body text.
  static TextStyle get bodyLarge => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Secondary body text.
  static TextStyle get bodyMedium => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Caption / timestamp.
  static TextStyle get bodySmall => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  // ─────────── Labels ───────────

  /// Button labels.
  static TextStyle get labelLarge => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0,
  );

  /// Tab labels / category headers.
  static TextStyle get labelMedium => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0,
  );

  /// Badge / chip labels.
  static TextStyle get labelSmall => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0,
  );

  // ─────────── Stat numbers ───────────

  /// Large statistic number (dashboard cards).
  static TextStyle get statLarge => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 36,
    fontWeight: FontWeight.w400,
    height: 1.1,
    letterSpacing: 0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Medium stat number.
  static TextStyle get statMedium => TextStyle(
    fontFamily: fontFamily,
    fontFamilyFallback: fontFamilyFallback,
    fontSize: 24,
    fontWeight: FontWeight.w400,
    height: 1.2,
    letterSpacing: 0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
