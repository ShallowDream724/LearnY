import 'package:flutter/material.dart';

/// Navigation's semantic tones, separate from refraction and gesture physics.
/// The filters operate on actual scrolled content. Positive channel slopes keep
/// color changes continuous; selection stays darker in light mode and lighter
/// in dark mode, without sampling the page on the CPU or flipping icon colors.
class NavigationGlassAppearance {
  const NavigationGlassAppearance._({
    required this.foreground,
    required this.selectedForeground,
    required this.tint,
    required this.pressedTint,
    required this.backdropTone,
    required this.selectionTone,
  });

  final Color foreground;
  final Color selectedForeground;
  final Color tint;
  final Color pressedTint;
  final ColorFilter backdropTone;
  final ColorFilter selectionTone;

  static final light = NavigationGlassAppearance._(
    foreground: const Color(0xFF252D40),
    selectedForeground: const Color(0xFF26345C),
    tint: const Color(0x10FFF8F0),
    pressedTint: const Color(0x086070AC),
    backdropTone: _toneRange(.55, 1, saturation: .82),
    selectionTone: const ColorFilter.matrix([
      .84,
      0,
      0,
      0,
      0,
      0,
      .84,
      0,
      0,
      5,
      0,
      0,
      .84,
      0,
      19,
      0,
      0,
      0,
      1,
      0,
    ]),
  );

  static final dark = NavigationGlassAppearance._(
    foreground: const Color(0xFFF4F5F9),
    selectedForeground: const Color(0xFFF0F3FF),
    tint: const Color(0x1820232A),
    pressedTint: const Color(0x08DDE5FF),
    backdropTone: _toneRange(.045, .33, saturation: .82),
    selectionTone: const ColorFilter.matrix([
      .85,
      0,
      0,
      0,
      26,
      0,
      .85,
      0,
      0,
      31,
      0,
      0,
      .85,
      0,
      43,
      0,
      0,
      0,
      1,
      0,
    ]),
  );

  static ColorFilter _toneRange(
    double low,
    double high, {
    required double saturation,
  }) {
    final gain = high - low;
    final red = (1 - saturation) * .2126 * gain;
    final green = (1 - saturation) * .7152 * gain;
    final blue = (1 - saturation) * .0722 * gain;
    final diagonal = saturation * gain;
    return ColorFilter.matrix([
      red + diagonal,
      green,
      blue,
      0,
      low * 255,
      red,
      green + diagonal,
      blue,
      0,
      low * 255,
      red,
      green,
      blue + diagonal,
      0,
      low * 255,
      0,
      0,
      0,
      1,
      0,
    ]);
  }
}
