/// LearnY Design System — Color Scheme
///
/// A curated, harmonious color palette for a premium academic app.
/// Dark mode first, with light mode variants.
library;

import 'package:flutter/material.dart';

/// Shared palette; resolve foreground roles through the active theme.
abstract final class AppColors {
  // ─────────────────────────────────────────────
  //  Brand
  // ─────────────────────────────────────────────

  /// Primary action colors, with a distinct light foreground for dark surfaces.
  static const Color primary = Color(0xFF006BD6);
  static const Color primaryLight = Color(0xFF70B1FF);
  static const Color primaryDark = Color(0xFF0754A7);
  static const Color primaryContainer = Color(0xFF153B63);

  /// Secondary — a warm amber for accents, badges, and highlights.
  static const Color secondary = Color(0xFFF59E0B);
  static const Color secondaryLight = Color(0xFFFBBF24);
  static const Color secondaryDark = Color(0xFFD97706);

  /// Tertiary — a cool teal for informational UI.
  static const Color tertiary = Color(0xFF14B8A6);
  static const Color tertiaryLight = Color(0xFF2DD4BF);

  // ─────────────────────────────────────────────
  //  Semantic
  // ─────────────────────────────────────────────

  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─────────────────────────────────────────────
  //  Deadline urgency spectrum
  // ─────────────────────────────────────────────

  /// Overdue — red
  static const Color deadlineOverdue = Color(0xFFEF4444);

  /// < 24h — orange
  static const Color deadlineUrgent = Color(0xFFF97316);

  /// 1-3 days — amber
  static const Color deadlineSoon = Color(0xFFFBBF24);

  /// > 3 days — green
  static const Color deadlineComfortable = Color(0xFF22C55E);

  // ─────────────────────────────────────────────
  //  Grade colors
  // ─────────────────────────────────────────────

  static const Color gradeExcellent = Color(0xFF22C55E); // A, 优秀
  static const Color gradeGood = Color(0xFF3B82F6); // B
  static const Color gradeAverage = Color(0xFFFBBF24); // C
  static const Color gradePoor = Color(0xFFF97316); // D
  static const Color gradeFail = Color(0xFFEF4444); // F, 不通过

  // ─────────────────────────────────────────────
  //  Dark theme surfaces
  // ─────────────────────────────────────────────

  static const Color darkBackground = Color(0xFF18191C);
  static const Color darkSurface = Color(0xFF222326);
  static const Color darkSurfaceHigh = Color(0xFF2D2F33);
  static const Color darkBorder = Color(0xFF3B3D42);

  static const Color darkTextPrimary = Color(0xFFF3F4F6);
  static const Color darkTextSecondary = Color(0xFFBABEC6);
  static const Color darkTextTertiary = Color(0xFF979DA7);

  // ─────────────────────────────────────────────
  //  Light theme surfaces
  // ─────────────────────────────────────────────

  static const Color lightBackground = Color(0xFFF7F8FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFF0F2F5);
  static const Color lightBorder = Color(0xFFE0E3E8);

  static const Color lightTextPrimary = Color(0xFF1D2026);
  static const Color lightTextSecondary = Color(0xFF5D636C);
  static const Color lightTextTertiary = Color(0xFF707780);

  // ─────────────────────────────────────────────
  //  Unread / notification badge
  // ─────────────────────────────────────────────

  static const Color unreadBadge = Color(0xFFEF4444);
  static const Color newBadge = primary;
}
