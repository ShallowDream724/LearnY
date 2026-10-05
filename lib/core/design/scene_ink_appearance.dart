import 'dart:math' as math;
import 'dart:ui';

/// Hue-preserving RGB lightness adjustment for one foreground group. Empty
/// background pixels retain alpha zero; this cannot create a surface fill.
class SceneInkAppearance {
  SceneInkAppearance(this.amount, this.light, this.contrast);
  final double amount;
  final bool light;
  final double contrast;
  late final ColorFilter filter = inkToneFilter(
    1 - amount,
    light ? 255 * amount : 0,
  );
  Color apply(Color color) => Color.lerp(
    color,
    light ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
    amount,
  )!;
}

ColorFilter inkToneFilter(double scale, double bias) => ColorFilter.matrix([
  scale,
  0,
  0,
  0,
  bias,
  0,
  scale,
  0,
  0,
  bias,
  0,
  0,
  scale,
  0,
  bias,
  0,
  0,
  0,
  1,
  0,
]);

SceneInkAppearance resolveSceneInk(
  List<Color> colors,
  ({Color darkest, Color brightest}) range, {
  required bool preferLight,
}) {
  final low = range.darkest.computeLuminance();
  final high = range.brightest.computeLuminance();
  double quality(double amount, bool light) {
    var result = double.infinity;
    for (final color in colors) {
      final luminance = Color.lerp(
        color,
        light ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
        amount,
      )!.computeLuminance();
      // An interval including the ink's luminance cannot prove contrast.
      final ratio = luminance >= low && luminance <= high
          ? 1.0
          : luminance < low
          ? (low + .05) / (luminance + .05)
          : (luminance + .05) / (high + .05);
      result = math.min(result, ratio);
    }
    return result;
  }

  final original = quality(0, preferLight);
  if (original >= 4.5) return SceneInkAppearance(0, preferLight, original);
  SceneInkAppearance candidate(bool light) {
    // Retain visible chroma. Texture smoothing must do its share; semantic
    // accents must not be driven to pure black/white by conservative bounds.
    final limit = light ? .6 : .45;
    final maximum = quality(limit, light);
    if (maximum < 4.5) return SceneInkAppearance(limit, light, maximum);
    var lowAmount = 0.0;
    var highAmount = limit;
    for (var step = 0; step < 9; step++) {
      final middle = (lowAmount + highAmount) / 2;
      if (quality(middle, light) >= 4.5) {
        highAmount = middle;
      } else {
        lowAmount = middle;
      }
    }
    return SceneInkAppearance(highAmount, light, quality(highAmount, light));
  }

  final lighter = candidate(true);
  final darker = candidate(false);
  final lightWorks = lighter.contrast >= 4.5;
  final darkWorks = darker.contrast >= 4.5;
  if (lightWorks && darkWorks) {
    return lighter.amount < darker.amount ? lighter : darker;
  }
  if (lightWorks) return lighter;
  if (darkWorks) return darker;
  // Mixed textures may admit neither direction. Keep color, improve only when
  // there is evidence, and do not claim a guaranteed ratio or add an opaque fill.
  final best = lighter.contrast > darker.contrast + .25
      ? lighter
      : darker.contrast > lighter.contrast + .25
      ? darker
      : preferLight
      ? lighter
      : darker;
  if (best.contrast <= original + .25) {
    return SceneInkAppearance(0, preferLight, original);
  }
  final amount = best.amount;
  final improved = quality(amount, best.light);
  return improved > original
      ? SceneInkAppearance(amount, best.light, improved)
      : SceneInkAppearance(0, preferLight, original);
}
