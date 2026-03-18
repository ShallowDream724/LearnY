/// LearnY Design System — Typography
///
/// Uses Google Fonts (Inter) with a strict type scale.
/// No emoji — all visual elements use Material Symbols or custom SVGs.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  static const EdgeInsets cardPadding =
      EdgeInsets.symmetric(horizontal: base, vertical: md);

  /// Standard page padding.
  static const EdgeInsets pagePadding =
      EdgeInsets.symmetric(horizontal: base, vertical: sm);

  /// Standard section spacing.
  static const double sectionGap = xl;

  /// Standard card border radius.
  static const double cardRadius = 16;

  /// Small chip / badge radius.
  static const double chipRadius = 8;

  /// Bottom nav bar height.
  static const double bottomNavHeight = 64;
}

/// Type scale — Inter font family with carefully chosen sizes and weights.
abstract final class AppTypography {
  static String get _fontFamily => GoogleFonts.inter().fontFamily!;

  // ─────────── Headlines ───────────

  /// Page title — large and bold.
  static TextStyle get headlineLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.5,
      );

  /// Section title.
  static TextStyle get headlineMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.3,
      );

  /// Subsection title.
  static TextStyle get headlineSmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.2,
      );

  // ─────────── Titles ───────────

  /// Card title / list tile title.
  static TextStyle get titleLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  /// Smaller title — tabs, chips.
  static TextStyle get titleMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle get titleSmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  // ─────────── Body ───────────

  /// Primary body text.
  static TextStyle get bodyLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  /// Secondary body text.
  static TextStyle get bodyMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  /// Caption / timestamp.
  static TextStyle get bodySmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  // ─────────── Labels ───────────

  /// Button labels.
  static TextStyle get labelLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.3,
      );

  /// Badge / chip labels.
  static TextStyle get labelSmall => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: 0.5,
      );

  // ─────────── Stat numbers ───────────

  /// Large statistic number (dashboard cards).
  static TextStyle get statLarge => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        height: 1.1,
        letterSpacing: -1.0,
      );

  /// Medium stat number.
  static TextStyle get statMedium => TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      );
}
