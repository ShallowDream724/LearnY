import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_theme_colors.dart';

/// A single bounded backdrop filter for floating navigation, independent of
/// course-card optics and of navigation state or gestures.
class FrostedNavigationSurface extends StatelessWidget {
  const FrostedNavigationSurface({super.key, required this.child});

  final Widget child;
  static final _blur = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18);

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final highContrast = MediaQuery.highContrastOf(context);
    const radius = BorderRadius.all(Radius.circular(999));
    return CustomPaint(
      painter: _NavigationGlassEdge(dark: dark, highContrast: highContrast),
      foregroundPainter: _NavigationGlassEdge(
        dark: dark,
        highContrast: highContrast,
        foreground: true,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: _blur,
          enabled: !highContrast,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: highContrast
                    ? [
                        context.colors.surface,
                        context.colors.surface,
                        context.colors.surface,
                      ]
                    : dark
                    ? const [
                        Color(0xB820232A),
                        Color(0x9920232A),
                        Color(0xAD20232A),
                      ]
                    : const [
                        Color(0x9EFFFDF9),
                        Color(0x80FFFDF9),
                        Color(0x8FFFFFFF),
                      ],
                stops: const [0, .55, 1],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NavigationGlassEdge extends CustomPainter {
  const _NavigationGlassEdge({
    required this.dark,
    required this.highContrast,
    this.foreground = false,
  });
  final bool dark;
  final bool highContrast;
  final bool foreground;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(size.height / 2),
    );
    if (!foreground) {
      // Keep the shadow outside the glass so it cannot muddy the clear center.
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(bounds.inflate(32))
          ..addRRect(shape),
      );
      canvas.drawRRect(
        shape.shift(const Offset(0, 5)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? .32 : .16)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.restore();
      return;
    }
    final edge = shape.deflate(.6);
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: highContrast
              ? [
                  dark ? Colors.white54 : Colors.black45,
                  dark ? Colors.white54 : Colors.black45,
                ]
              : dark
              ? const [Color(0x70FFFFFF), Color(0x12FFFFFF), Color(0x38FFFFFF)]
              : const [Color(0xF0FFFFFF), Color(0x48FFFFFF), Color(0xBDFFFFFF)],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      shape.deflate(1.8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5
        ..color = dark ? const Color(0x40000000) : const Color(0x153B342D),
    );
  }

  @override
  bool shouldRepaint(_NavigationGlassEdge oldDelegate) =>
      dark != oldDelegate.dark ||
      highContrast != oldDelegate.highContrast ||
      foreground != oldDelegate.foreground;
}
