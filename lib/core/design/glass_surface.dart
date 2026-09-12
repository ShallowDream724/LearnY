import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Optical properties, independent of shape, theme, and the controls in a pane.
@immutable
class GlassOptics {
  const GlassOptics({
    this.blurSigma = 5,
    this.refraction = 12,
    this.light = 1,
    this.shadow = 1,
  }) : assert(blurSigma >= 0),
       assert(refraction >= 0),
       assert(light >= 0),
       assert(shadow >= 0);

  final double blurSigma;
  final double refraction;
  final double light;
  final double shadow;
}

/// A reusable rounded glass pane. Its backdrop, lighting, and shadow are also
/// available separately for controls that need only part of the material.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 24,
    this.tint,
    this.optics = const GlassOptics(),
  }) : assert(radius >= 0);

  final Widget child;
  final double radius;
  final Color? tint;
  final GlassOptics optics;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final fill = highContrast
        ? Theme.of(context).colorScheme.surface
        : tint ?? (dark ? const Color(0xAD20232A) : const Color(0x58FFF8F0));
    return CustomPaint(
      painter: GlassShadow(radius: radius, dark: dark, strength: optics.shadow),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: GlassBackdrop(
          radius: radius,
          optics: optics,
          enabled: !highContrast,
          child: ColoredBox(
            color: fill,
            child: GlassLighting(
              radius: radius,
              strength: optics.light,
              enabled: !highContrast,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

final _glassPrograms = <String, Future<ui.FragmentProgram?>>{};

Future<ui.FragmentProgram?> _glassProgram(String asset) =>
    _glassPrograms.putIfAbsent(asset, () async {
      try {
        return await ui.FragmentProgram.fromAsset(asset);
      } catch (error) {
        debugPrint('[LearnY] Glass effect unavailable ($asset): $error');
        return null;
      }
    });

/// Filters actual page content. Impeller supplies its live texture to the
/// refraction shader; other renderers retain the same backdrop with plain blur.
/// The caller owns clipping, allowing this to compose with other surface styles.
class GlassBackdrop extends StatefulWidget {
  const GlassBackdrop({
    super.key,
    required this.child,
    required this.radius,
    this.optics = const GlassOptics(),
    this.enabled = true,
  });
  final Widget child;
  final double radius;
  final GlassOptics optics;
  final bool enabled;

  @override
  State<GlassBackdrop> createState() => _GlassBackdropState();
}

class _GlassBackdropState extends State<GlassBackdrop> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    if (ui.ImageFilter.isShaderFilterSupported) _load();
  }

  Future<void> _load() async {
    final program = await _glassProgram('shaders/glass_refraction.frag');
    if (!mounted || program == null) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _GlassBackdropLayer(
      shader: _shader,
      radius: widget.radius,
      optics: widget.optics,
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
      enabled: widget.enabled,
      child: widget.child,
    );
  }
}

class _GlassBackdropLayer extends SingleChildRenderObjectWidget {
  const _GlassBackdropLayer({
    required this.shader,
    required this.radius,
    required this.optics,
    required this.pixelRatio,
    required this.enabled,
    required super.child,
  });
  final ui.FragmentShader? shader;
  final double radius;
  final GlassOptics optics;
  final double pixelRatio;
  final bool enabled;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGlassBackdrop(this);

  @override
  void updateRenderObject(BuildContext context, _RenderGlassBackdrop render) {
    render.configuration = this;
    render.markNeedsPaint();
  }
}

class _RenderGlassBackdrop extends RenderProxyBox {
  _RenderGlassBackdrop(this.configuration);
  _GlassBackdropLayer configuration;

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final config = configuration;
    if (!config.enabled || child == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final shader = config.shader;
    final scale = config.pixelRatio;
    final origin = localToGlobal(Offset.zero);
    // The filter input can include more than the clipped pane. Keep the lens
    // geometry independent of that texture's dimensions and screen position.
    shader
      ?..setFloat(2, origin.dx * scale)
      ..setFloat(3, origin.dy * scale)
      ..setFloat(4, size.width * scale)
      ..setFloat(5, size.height * scale)
      ..setFloat(6, config.radius * scale)
      ..setFloat(7, config.optics.refraction * scale);
    final blur = ui.ImageFilter.blur(
      sigmaX: config.optics.blurSigma,
      sigmaY: config.optics.blurSigma,
    );
    final backdrop = (layer ??= BackdropFilterLayer()) as BackdropFilterLayer;
    backdrop.filter = shader == null || config.optics.refraction == 0
        ? blur
        : ui.ImageFilter.compose(
            outer: ui.ImageFilter.shader(shader),
            inner: blur,
          );
    context.pushLayer(backdrop, super.paint, offset);
  }
}

/// Inner highlights and grazing shade only; no tint, backdrop, input, or shadow.
/// Light is painted below [child], so it cannot wash out icons and text.
class GlassLighting extends StatefulWidget {
  const GlassLighting({
    super.key,
    required this.child,
    required this.radius,
    this.strength = 1,
    this.enabled = true,
  });
  final Widget child;
  final double radius;
  final double strength;
  final bool enabled;

  @override
  State<GlassLighting> createState() => _GlassLightingState();
}

class _GlassLightingState extends State<GlassLighting> {
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final program = await _glassProgram('shaders/glass_light.frag');
    if (!mounted || program == null) return;
    setState(() => _shader = program.fragmentShader());
  }

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: widget.enabled
        ? _GlassLightPainter(
            shader: _shader,
            radius: widget.radius,
            strength: widget.strength,
            dark: Theme.of(context).brightness == Brightness.dark,
          )
        : null,
    child: widget.child,
  );
}

class _GlassLightPainter extends CustomPainter {
  const _GlassLightPainter({
    required this.shader,
    required this.radius,
    required this.strength,
    required this.dark,
  });
  final ui.FragmentShader? shader;
  final double radius;
  final double strength;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final light = shader;
    if (light == null) return;
    light
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, radius)
      ..setFloat(3, dark ? 1 : 0)
      ..setFloat(4, strength);
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        Radius.circular(math.min(radius, size.shortestSide / 2)),
      ),
    );
    canvas.drawRect(Offset.zero & size, Paint()..shader = light);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassLightPainter oldDelegate) =>
      shader != oldDelegate.shader ||
      radius != oldDelegate.radius ||
      strength != oldDelegate.strength ||
      dark != oldDelegate.dark;
}

/// Exterior depth without filling the pane; usable as any CustomPaint painter.
class GlassShadow extends CustomPainter {
  const GlassShadow({
    required this.radius,
    required this.dark,
    this.strength = 1,
  });
  final double radius;
  final bool dark;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final corner = math.min(radius, size.shortestSide / 2);
    final shape = RRect.fromRectAndRadius(bounds, Radius.circular(corner));
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
        ..color = Colors.black.withValues(
          alpha: ((dark ? .34 : .16) * strength).clamp(0, 1),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    // Gaussian, slightly wider at the curved sides; no constant-width outline.
    final contact = RRect.fromRectAndRadius(
      Rect.fromLTRB(-1.05, -.2, size.width + 1.05, size.height + .3),
      Radius.elliptical(corner + 1.05, corner + .25),
    );
    canvas.drawRRect(
      contact,
      Paint()
        ..color = Colors.black.withValues(
          alpha: ((dark ? .66 : .48) * strength).clamp(0, 1),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .75),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(GlassShadow oldDelegate) =>
      radius != oldDelegate.radius ||
      dark != oldDelegate.dark ||
      strength != oldDelegate.strength;
}
