import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Perceptual wallpaper strength preserves color at ordinary slider values.
double wallpaperTransmission(double strength) =>
    math.sqrt(strength.clamp(0, 1));

/// Preserve hue/saturation while finding the closest readable lightness on the
/// reading material. Some ochre/plum accents cannot reach text contrast even
/// on opaque white; tinting the background alone cannot repair those colors.
Color readingForeground(Color color, {required bool dark}) {
  final material = dark ? const Color(0xFF20242D) : Colors.white;
  final surface = material.computeLuminance();
  double ratio(Color ink) {
    final value = ink.computeLuminance();
    return (math.max(value, surface) + .05) / (math.min(value, surface) + .05);
  }

  const target = 6.0; // headroom for bounded translucent control material
  if (ratio(color) >= target) return color;
  final hsl = HSLColor.fromColor(color);
  var low = dark ? hsl.lightness : 0.0;
  var high = dark ? 1.0 : hsl.lightness;
  for (var i = 0; i < 12; i++) {
    final mid = (low + high) / 2;
    final readable = ratio(hsl.withLightness(mid).toColor()) >= target;
    if (readable == dark) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return hsl.withLightness(dark ? high : low).toColor();
}

/// Finds the light/dark surface opacity needed by a semantic foreground.
/// Called for a small cached wallpaper sample, never for screen pixels per frame.
double contrastOpacity(
  Color background,
  Color foreground, {
  required bool dark,
  double minimum = 0,
}) {
  final tint = dark ? const Color(0xFF20242D) : Colors.white;
  final ink = foreground.computeLuminance();
  bool legible(double alpha) {
    final surface = Color.alphaBlend(
      tint.withValues(alpha: alpha),
      background,
    ).computeLuminance();
    return (math.max(surface, ink) + .05) / (math.min(surface, ink) + .05) >=
        4.5;
  }

  if (legible(minimum)) return minimum;
  var low = minimum;
  var high = 1.0;
  for (var i = 0; i < 9; i++) {
    final mid = (low + high) / 2;
    if (legible(mid)) {
      high = mid;
    } else {
      low = mid;
    }
  }
  return high;
}
