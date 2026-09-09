import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_materials.dart';
import 'app_theme_colors.dart';

/// The viewport owns the shared light. Surfaces resolve their location while
/// painting, so scrolling/resizing never needs post-frame measurement or state.
class CourseGlassBackdrop extends SingleChildRenderObjectWidget {
  const CourseGlassBackdrop({super.key, required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GlassBackdrop(context.isDark);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderObject renderObject,
  ) {
    (renderObject as _GlassBackdrop).dark = context.isDark;
  }
}

class _GlassBackdrop extends RenderProxyBox {
  _GlassBackdrop(this._dark);
  bool _dark;
  set dark(bool value) {
    if (_dark != value) {
      _dark = value;
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    _SceneLight(dark: _dark).paint(context.canvas, size);
    context.canvas.restore();
    super.paint(context, offset);
  }
}

class CourseGlassSurface extends StatelessWidget {
  const CourseGlassSurface({
    super.key,
    required this.child,
    required this.tone,
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
    final border = BorderRadius.circular(radius);
    return _GlassLayer(
      radius: radius,
      dark: context.isDark,
      tint: Color(
        const [
          0xFF708DE0,
          0xFF5CAF9E,
          0xFFCEA868,
          0xFFCB8AA5,
          0xFF7AA4C4,
          0xFFA08ACD,
        ][tone.index],
      ),
      child: ClipRRect(
        borderRadius: border,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: RoundedRectangleBorder(borderRadius: border),
            onTap: onTap,
            onLongPress: onLongPress,
            onSecondaryTapDown: onSecondaryTapDown,
            mouseCursor: mouseCursor,
            hoverColor: Colors.white.withAlpha(context.isDark ? 6 : 10),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _GlassLayer extends SingleChildRenderObjectWidget {
  const _GlassLayer({
    required this.radius,
    required this.dark,
    required this.tint,
    required super.child,
  });
  final double radius;
  final bool dark;
  final Color tint;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GlassSurface(radius, dark, tint);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _GlassSurface renderObject,
  ) => renderObject.update(radius, dark, tint);
}

class _GlassSurface extends RenderProxyBox {
  _GlassSurface(this.radius, this.dark, this.tint);
  double radius;
  bool dark;
  Color tint;
  void update(double nextRadius, bool nextDark, Color nextTint) {
    if (radius == nextRadius && dark == nextDark && tint == nextTint) return;
    radius = nextRadius;
    dark = nextDark;
    tint = nextTint;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    RenderObject? ancestor = parent;
    while (ancestor != null && ancestor is! _GlassBackdrop) {
      ancestor = ancestor.parent;
    }
    final backdrop = ancestor as _GlassBackdrop?;
    final origin = backdrop == null
        ? Offset.zero
        : MatrixUtils.transformPoint(getTransformTo(backdrop), Offset.zero);
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    _GlassOptics(
      radius,
      tint,
      backdrop?.size ?? size,
      origin,
      dark,
    ).paint(context.canvas, size);
    context.canvas.restore();
    super.paint(context, offset);
  }
}

class _SceneLight {
  const _SceneLight({required this.dark});
  final bool dark;
  static Offset source(Size size) =>
      Offset(size.width * .02, -size.height * .3);
  void paint(Canvas canvas, Size size, {Rect? coverage}) {
    final bounds = Offset.zero & size;
    // Cards can be painted outside the viewport (scroll cache / refraction).
    // Extend the same light field there instead of cutting it at the viewport.
    final paintBounds = coverage ?? bounds;
    canvas.drawRect(
      paintBounds,
      Paint()..color = dark ? const Color(0xFF171C27) : const Color(0xFFEFF3F8),
    );
    canvas.drawRect(
      paintBounds,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.96, -1.6),
          radius: 1.75,
          colors: dark
              ? const [Color(0x0EFFFFFF), Color(0x07FFFFFF), Color(0x00FFFFFF)]
              : const [Color(0xFFFFFFFF), Color(0xE8FFFFFF), Color(0x00FFFFFF)],
          stops: const [0, .36, 1],
        ).createShader(bounds),
    );
  }
}

class _GlassOptics {
  const _GlassOptics(
    this.radius,
    this.tint,
    this.sceneSize,
    this.origin,
    this.dark,
  );
  final double radius;
  final Color tint;
  final Size sceneSize;
  final Offset origin;
  final bool dark;

  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    final center = bounds.center;
    final towardLight = _SceneLight.source(sceneSize) - (origin + center);
    final direction = towardLight / math.max(1, towardLight.distance);
    // Shadow is clipped outside: it must never show through the clear center.
    canvas.save();
    canvas.clipPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(bounds.inflate(16))
        ..addRRect(outer),
    );
    canvas.drawRRect(
      outer.shift(-direction * 2),
      Paint()
        ..color = dark ? const Color(0x30000000) : const Color(0x12324762)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.restore();
    final inner = RRect.fromRectAndRadius(
      bounds.deflate(3),
      Radius.circular(radius - 3),
    );
    final rim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(outer)
      ..addRRect(inner);
    canvas.save();
    canvas.clipPath(rim);
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.04);
    canvas.translate(-center.dx - origin.dx, -center.dy - origin.dy);
    _SceneLight(dark: dark).paint(
      canvas,
      sceneSize,
      coverage: Rect.fromCenter(
        center: origin + center,
        width: size.width / 1.04,
        height: size.height / 1.04,
      ),
    );
    canvas.restore();
    canvas.drawRRect(outer, Paint()..color = tint.withAlpha(dark ? 24 : 17));
    canvas.save();
    canvas.clipPath(rim);
    canvas.drawRRect(outer, Paint()..color = tint.withAlpha(9));
    canvas.restore();
    final transmission = HSVColor.fromColor(
      tint,
    ).withSaturation(.58).withValue(1).toColor();
    canvas.save();
    canvas.clipRRect(inner);
    canvas.translate(-origin.dx, -origin.dy);
    _SceneLight(dark: dark).paint(canvas, sceneSize, coverage: origin & size);
    canvas.translate(origin.dx, origin.dy);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            transmission.withAlpha(dark ? 12 : 8),
            transmission.withAlpha(dark ? 8 : 3),
            transmission.withAlpha(dark ? 16 : 9),
            transmission.withAlpha(dark ? 24 : 17),
          ],
          stops: const [0, .32, .65, 1],
        ).createShader(bounds),
    );
    canvas.restore();
    final edge = RRect.fromRectAndRadius(
      bounds.deflate(.35),
      Radius.circular(radius - .35),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65
        ..color = tint.withAlpha(dark ? 58 : 38),
    );
    canvas.drawRRect(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .7
        ..shader = LinearGradient(
          begin: Alignment(direction.dx, direction.dy),
          end: Alignment(-direction.dx, -direction.dy),
          colors: dark
              ? const [
                  Color(0x50FFFFFF),
                  Color(0x18FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0x06FFFFFF),
                  Color(0x30FFFFFF),
                ]
              : const [
                  Color(0xFFFFFFFF),
                  Color(0x55FFFFFF),
                  Color(0x00FFFFFF),
                  Color(0x12FFFFFF),
                  Color(0xB8FFFFFF),
                ],
          stops: const [0, .24, .46, .86, 1],
        ).createShader(bounds),
    );
  }
}
