import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme_colors.dart';

/// Course identity is independent of urgency and of a course's list position.
enum StudyTone { ink, jade, ochre, rose, slate, plum }

class StudyColors {
  const StudyColors(this.accent, this.fill, this.edge);
  final Color accent;
  final Color fill;
  final Color edge;
}

abstract final class StudyPalette {
  static StudyTone course(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x1fffffff;
    }
    return StudyTone.values[hash % StudyTone.values.length];
  }

  static StudyColors of(BuildContext context, StudyTone tone) {
    final dark = context.isDark;
    final accent = (dark
        ? const [
            0xFF9BBDD7,
            0xFF8EC2AD,
            0xFFDDC194,
            0xFFD9A8AC,
            0xFFACBACA,
            0xFFC0B0D5,
          ]
        : const [
            0xFF5966A9,
            0xFF4C847F,
            0xFFA5804C,
            0xFFAD7488,
            0xFF6C7E99,
            0xFF8772AD,
          ])[tone.index];
    final color = Color(accent);
    return StudyColors(
      color,
      Color.alphaBlend(color.withAlpha(dark ? 24 : 18), context.colors.surface),
      Color.alphaBlend(color.withAlpha(dark ? 46 : 30), context.colors.border),
    );
  }
}

/// A bounded, opaque material. Light is painted once; no backdrop blur or
/// offscreen layers are needed for repeated scrolling content.
class StudySurface extends StatelessWidget {
  const StudySurface({
    super.key,
    required this.child,
    this.tone = StudyTone.slate,
    this.padding = EdgeInsets.zero,
    this.radius = 18,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTapDown,
    this.mouseCursor,
  });

  final Widget child;
  final StudyTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final GestureTapDownCallback? onSecondaryTapDown;
  final MouseCursor? mouseCursor;

  @override
  Widget build(BuildContext context) {
    final colors = StudyPalette.of(context, tone);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(
        color: colors.edge.withAlpha(context.isDark ? 120 : 110),
        width: .7,
      ),
    );
    final content = Padding(padding: padding, child: child);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: (context.isDark ? Colors.black : const Color(0xFF434C78))
                .withAlpha(context.isDark ? 24 : 9),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: (context.isDark ? Colors.black : const Color(0xFF434C78))
                .withAlpha(5),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: colors.fill,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                  Colors.white.withAlpha(context.isDark ? 3 : 50),
                  colors.fill,
                ),
                colors.fill,
              ],
            ),
          ),
          child:
              onTap == null && onLongPress == null && onSecondaryTapDown == null
              ? content
              : InkWell(
                  customBorder: shape,
                  mouseCursor: mouseCursor,
                  onTap: onTap,
                  onLongPress: onLongPress,
                  onSecondaryTapDown: onSecondaryTapDown,
                  child: content,
                ),
        ),
      ),
    );
  }
}

/// A small course signature, never used in place of its readable name.
class CourseSeal extends StatelessWidget {
  const CourseSeal({
    super.key,
    required this.courseId,
    this.size = 32,
    this.icon,
  });
  final String courseId;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = StudyPalette.course(courseId);
    final color = StudyPalette.of(context, tone).accent;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: icon != null
            ? Icon(icon, size: size * .7, color: color)
            : CustomPaint(painter: _SealPainter(color, tone.index)),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  const _SealPainter(this.color, this.variant);
  final Color color;
  final int variant;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    canvas.translate(16, 16);
    canvas.rotate(variant * math.pi / 6);
    final stroke = Paint()
      ..color = color.withAlpha(170)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;
    final fill = Paint()..color = color.withAlpha(20);
    final a = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-10, -10, 15, 20),
      const Radius.circular(7),
    );
    final b = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-5, -10, 15, 20),
      const Radius.circular(7),
    );
    canvas.drawRRect(a, fill);
    canvas.drawRRect(b, fill);
    canvas.drawRRect(a, stroke);
    canvas.drawRRect(b, stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) =>
      color != oldDelegate.color || variant != oldDelegate.variant;
}

class StudyMark extends StatelessWidget {
  const StudyMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .24),
        child: Image.asset(
          'assets/brand/app_icon.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}
