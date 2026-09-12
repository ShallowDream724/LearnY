import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_theme_colors.dart';
import 'app_light_scene.dart';

/// A single bounded backdrop filter for floating navigation, independent of
/// course-card optics and of navigation state or gestures.
class FrostedNavigationSurface extends StatelessWidget {
  const FrostedNavigationSurface({super.key, required this.child});

  final Widget child;
  static final _blur = ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12);

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
                        Color(0x8AFFF7EE),
                        Color(0x73FFF8F2),
                        Color(0x80FFFFFF),
                      ],
                stops: const [0, .55, 1],
              ),
            ),
            child: highContrast
                ? child
                : _NavigationRefraction(
                    scene: StudyLightBackdrop.sceneOf(context),
                    dark: dark,
                    child: child,
                  ),
          ),
        ),
      ),
    );
  }
}

class _NavigationRefraction extends SingleChildRenderObjectWidget {
  const _NavigationRefraction({
    required this.scene,
    required this.dark,
    required super.child,
  });
  final StudyLightScene? scene;
  final bool dark;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _NavigationLens(scene, dark);

  @override
  void updateRenderObject(BuildContext context, _NavigationLens renderObject) =>
      renderObject.update(scene, dark);
}

class _NavigationLens extends RenderProxyBox {
  _NavigationLens(this.scene, this.dark);
  StudyLightScene? scene;
  bool dark;
  ui.Vertices? _mesh;
  Size? _meshSize;
  Offset _meshOrigin = Offset.zero;

  void update(StudyLightScene? nextScene, bool nextDark) {
    if (identical(scene, nextScene) && dark == nextDark) return;
    scene = nextScene;
    dark = nextDark;
    markNeedsPaint();
  }

  ui.Vertices _meshFor(Size size, Offset origin) {
    if (_mesh != null && _meshSize == size && _meshOrigin == origin) {
      return _mesh!;
    }
    final columns = math.max(2, (size.width / 8).ceil());
    const rows = 16;
    final vertices = Float32List((columns + 1) * (rows + 1) * 2);
    final samples = Float32List(vertices.length);
    final indices = Uint16List(columns * rows * 6);
    final radius = size.height / 2;
    final spine = math.max(0.0, size.width / 2 - radius);
    var vertex = 0;
    for (var y = 0; y <= rows; y++) {
      for (var x = 0; x <= columns; x++) {
        final point = Offset(size.width * x / columns, size.height * y / rows);
        final centered = point - size.center(Offset.zero);
        final normal = Offset(
          centered.dx - centered.dx.clamp(-spine, spine),
          centered.dy,
        );
        final distance = normal.distance;
        final slope = (distance / radius).clamp(0.0, 1.0);
        // A convex cap pulls texture samples toward its optical center. The
        // displacement grows smoothly at the curved wall, bending real lines.
        final displacement = distance == 0
            ? Offset.zero
            : normal / distance * (radius * .43 * math.pow(slope, 3));
        final sample = origin + point - displacement;
        vertices[vertex] = point.dx;
        vertices[vertex + 1] = point.dy;
        samples[vertex] = sample.dx;
        samples[vertex + 1] = sample.dy;
        vertex += 2;
      }
    }
    var index = 0;
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < columns; x++) {
        final top = y * (columns + 1) + x;
        final bottom = top + columns + 1;
        for (final point in [
          top,
          bottom,
          top + 1,
          top + 1,
          bottom,
          bottom + 1,
        ]) {
          indices[index++] = point;
        }
      }
    }
    _mesh?.dispose();
    _meshSize = size;
    _meshOrigin = origin;
    return _mesh = ui.Vertices.raw(
      ui.VertexMode.triangles,
      vertices,
      textureCoordinates: samples,
      indices: indices,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final backdrop = StudyLightBackdrop.locate(
      this,
      dark: dark,
      fallbackOrigin: _meshOrigin,
    );
    final bounds = Offset.zero & size;
    final shape = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(size.height / 2),
    );
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.clipRRect(shape);
    canvas.saveLayer(bounds, Paint());
    backdrop.scene.paintMesh(
      canvas,
      backdrop.size,
      _meshFor(size, backdrop.origin),
    );
    canvas.drawRRect(
      shape,
      Paint()..color = dark ? const Color(0x39202429) : const Color(0x36FFF8ED),
    );
    // Fade the curved wall into the transmitted center. A hard inner cut would
    // turn this optical edge into a visible frame.
    canvas.drawRRect(
      shape.deflate(3.5),
      Paint()
        ..color = Colors.black
        ..blendMode = BlendMode.dstOut
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.restore();
    // Light belongs to the material; icons and the moving lens remain above it.
    canvas.drawRRect(
      shape.deflate(.6),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0x22FFFFFF),
                  Color(0x08FFFFFF),
                  Color(0x0A000000),
                  Color(0x06FFFFFF),
                ]
              : const [
                  Color(0x58FFFFFF),
                  Color(0x0FFFFFFF),
                  Color(0x002D241E),
                  Color(0x092D241E),
                ],
          stops: const [0, .30, .72, 1],
        ).createShader(bounds),
    );
    canvas.restore();
    super.paint(context, offset);
  }

  @override
  void dispose() {
    _mesh?.dispose();
    super.dispose();
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
        shape.shift(const Offset(0, 6)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? .38 : .20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
      canvas.drawRRect(
        shape.shift(const Offset(0, 1.5)),
        Paint()
          ..color = Colors.black.withValues(alpha: dark ? .30 : .17)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
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
      shape.deflate(.25),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .5
        ..color = dark ? const Color(0x40000000) : const Color(0x383B342D),
    );
  }

  @override
  bool shouldRepaint(_NavigationGlassEdge oldDelegate) =>
      dark != oldDelegate.dark ||
      highContrast != oldDelegate.highContrast ||
      foreground != oldDelegate.foreground;
}
