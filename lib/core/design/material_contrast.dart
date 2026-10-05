import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Perceptual wallpaper strength preserves color at ordinary slider values.
double wallpaperTransmission(double strength) =>
    math.sqrt(strength.clamp(0, 1));

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
