import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_materials.dart';
import 'app_light_scene.dart';
import 'app_theme_colors.dart';

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
      scene: StudyLightBackdrop.sceneOf(context),
      tint: Color(tone.glass),
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
    required this.scene,
    required super.child,
  });
  final double radius;
  final bool dark;
  final Color tint;
  final StudyLightScene? scene;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _GlassSurface(radius, dark, tint, scene);
  @override
  void updateRenderObject(
    BuildContext context,
    covariant _GlassSurface renderObject,
  ) => renderObject.update(radius, dark, tint, scene);
}

class _GlassSurface extends RenderProxyBox {
  _GlassSurface(this.radius, this.dark, this.tint, this.scene);
  double radius;
  bool dark;
  Color tint;
  // The inherited image revision invalidates surfaces in retained page layers.
  // Position still resolves at paint time, independently of widget rebuilds.
  StudyLightScene? scene;
  Offset _lastSceneOrigin = Offset.zero;
  void update(
    double nextRadius,
    bool nextDark,
    Color nextTint,
    StudyLightScene? nextScene,
  ) {
    if (radius == nextRadius &&
        dark == nextDark &&
        tint == nextTint &&
        identical(scene, nextScene)) {
      return;
    }
    radius = nextRadius;
    dark = nextDark;
    tint = nextTint;
    scene = nextScene;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final backdrop = StudyLightBackdrop.locate(
      this,
      dark: dark,
      fallbackOrigin: _lastSceneOrigin,
    );
    _lastSceneOrigin = backdrop.origin;
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    _GlassOptics(
      radius,
      tint,
      backdrop.size,
      backdrop.origin,
      dark,
      backdrop.scene,
    ).paint(context.canvas, size);
    context.canvas.restore();
    super.paint(context, offset);
  }
}

class _GlassOptics {
  const _GlassOptics(
    this.radius,
    this.tint,
    this.sceneSize,
    this.origin,
    this.dark,
    this.scene,
  );
  final double radius;
  final Color tint;
  final Size sceneSize;
  final Offset origin;
  final bool dark;
  final StudyLightScene scene;

  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    final center = bounds.center;
    final towardLight = StudyLightScene.source(sceneSize) - (origin + center);
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
    scene.paint(
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
    scene.paint(canvas, sceneSize, coverage: origin & size);
    canvas.translate(origin.dx, origin.dy);
    canvas.drawRect(
      bounds,
      Paint()
        ..color = dark
            ? const Color(0x44202429)
            : Colors.white.withValues(alpha: scene.wallpaper.paneOpacity),
    );
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
