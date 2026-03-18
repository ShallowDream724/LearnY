/// LearnY Design System — Color Scheme
///
/// A curated, harmonious color palette for a premium academic app.
/// Dark mode first, with light mode variants.
library;

import 'package:flutter/material.dart';

/// Core brand colors — deep scholarly tones.
abstract final class AppColors {
  // ─────────────────────────────────────────────
  //  Brand
  // ─────────────────────────────────────────────

  /// Primary — a refined indigo-violet, conveys intellect and trust.
  static const Color primary = Color(0xFF6366F1);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF4F46E5);
  static const Color primaryContainer = Color(0xFF312E81);

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

  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkSurfaceHigh = Color(0xFF334155);
  static const Color darkBorder = Color(0xFF475569);

  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // ─────────────────────────────────────────────
  //  Light theme surfaces
  // ─────────────────────────────────────────────

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceHigh = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);

  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightTextTertiary = Color(0xFF94A3B8);

  // ─────────────────────────────────────────────
  //  Unread / notification badge
  // ─────────────────────────────────────────────

  static const Color unreadBadge = Color(0xFFEF4444);
  static const Color newBadge = Color(0xFF6366F1);
}
