import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'app_light_scene.dart';
import 'scene_ink_appearance.dart';
import 'material_contrast.dart';
import 'wallpaper.dart';

Future<ui.FragmentProgram?>? _readingProgram;
ui.FragmentProgram? _resolvedReadingProgram;
Future<ui.FragmentProgram?> _loadReadingProgram() =>
    _readingProgram ??= (() async {
      try {
        final program = await ui.FragmentProgram.fromAsset(
          'shaders/reading_blur.frag',
        );
        _resolvedReadingProgram = program;
        return program;
      } catch (error) {
        debugPrint('[LearnY] Reading blur unavailable: $error');
        return null;
      }
    })();

/// Ink over the shared wallpaper. Blur is painted by the background owner,
/// below every card; this widget never inserts an opaque or tinted surface.
class StudyReadingInk extends StatefulWidget {
  const StudyReadingInk({
    super.key,
    required this.colors,
    required this.builder,
  });
  final List<Color> colors;
  final Widget Function(BuildContext context, List<Color> inks) builder;
  @override
  State<StudyReadingInk> createState() => _StudyReadingInkState();
}

class _StudyReadingInkState extends State<StudyReadingInk> {
  ui.FragmentProgram? _program;
  @override
  void initState() {
    super.initState();
    _program = _resolvedReadingProgram;
    if (_program != null) {
      return;
    }
    _loadReadingProgram().then((program) {
      if (mounted) setState(() => _program = program);
    });
  }

  @override
  Widget build(BuildContext context) => _ReadingInkLayer(
    program: _program,
    colors: widget.colors,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
    child: Material(
      type: MaterialType.transparency,
      child: widget.builder(context, widget.colors),
    ),
  );
}

class _ReadingInkLayer extends SingleChildRenderObjectWidget {
  const _ReadingInkLayer({
    required this.program,
    required this.colors,
    required this.reduceMotion,
    required super.child,
  });
  final ui.FragmentProgram? program;
  final List<Color> colors;
  final bool reduceMotion;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ReadingInkBox(program, colors, reduceMotion);
  @override
  void updateRenderObject(BuildContext context, _ReadingInkBox render) =>
      render.update(program, colors, reduceMotion);
}

class _ReadingInkBox extends RenderProxyBox {
  _ReadingInkBox(this._program, this._colors, this._reduceMotion);
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;
  ui.Image? _image;
  StudyLightScene? _scene;
  List<Color> _colors;
  VoidCallback? _unregister;
  ({Color darkest, Color brightest})? _lastRange;
  SceneInkAppearance? _appearance;
  Offset _lastOrigin = Offset.zero;
  final _blurPaint = Paint();
  bool _reduceMotion;
  Duration? _transitionStart;
  double _fromScale = 1, _fromBias = 0, _targetScale = 1, _targetBias = 0;
  ({double scale, double bias})? _lastTone;
  ColorFilter? _toneFilter;

  void update(
    ui.FragmentProgram? program,
    List<Color> colors,
    bool reduceMotion,
  ) {
    _reduceMotion = reduceMotion;
    if (reduceMotion) _transitionStart = null;
    if (!identical(program, _program)) {
      _blurPaint.shader = null;
      _shader?.dispose();
      _shader = null;
      _program = program;
      _image = null;
    }
    if (!listEquals(colors, _colors)) {
      _colors = colors;
      _lastRange = null;
    }
    if (_scene case final scene?) _sceneChanged(scene);
    markNeedsPaint();
    StudyLightBackdrop.invalidateReadingFields(this);
  }

  void _sceneChanged(StudyLightScene scene) {
    if (!identical(scene, _scene)) _lastRange = null;
    _scene = scene;
    if (scene.image == null) {
      _blurPaint.shader = null;
      _shader?.dispose();
      _shader = null;
      _image = null;
    } else if (_program != null &&
        (!identical(_image, scene.image) || _shader == null)) {
      _shader ??= _program!.fragmentShader();
      _shader!.setImageSampler(0, scene.image!);
      _image = scene.image;
    }
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _unregister = StudyLightBackdrop.registerReadingField(
      this,
      _paintBackground,
      _sceneChanged,
    );
  }

  @override
  void detach() {
    _unregister?.call();
    _unregister = null;
    super.detach();
  }

  @override
  void dispose() {
    _blurPaint.shader = null;
    _shader?.dispose();
    _shader = null;
    _image = null;
    super.dispose();
  }

  void _paintBackground(
    Canvas canvas,
    StudyLightScene scene,
    Size viewport,
    Rect bounds,
  ) {
    final shader = _shader;
    final image = _image;
    if (shader == null ||
        image == null ||
        scene.strength == 0 ||
        bounds.isEmpty) {
      return;
    }
    final texture = scene.texturePlacement(viewport);
    final base = scene.dark ? const Color(0xFF1B1D20) : const Color(0xFFF7F8FB);
    final customDark = scene.dark && scene.wallpaper == StudyWallpaper.custom;
    shader
      ..setFloat(0, bounds.left)
      ..setFloat(1, bounds.top)
      ..setFloat(2, bounds.width)
      ..setFloat(3, bounds.height)
      ..setFloat(4, image.width.toDouble())
      ..setFloat(5, image.height.toDouble())
      ..setFloat(6, texture.origin.dx)
      ..setFloat(7, texture.origin.dy)
      ..setFloat(8, texture.scale)
      ..setFloat(9, wallpaperTransmission(scene.strength))
      ..setFloat(10, base.r)
      ..setFloat(11, base.g)
      ..setFloat(12, base.b)
      ..setFloat(13, customDark ? .46 : 1)
      ..setFloat(14, customDark ? .49 : 1)
      ..setFloat(15, customDark ? .54 : 1);
    _blurPaint.shader = shader;
    canvas.save();
    canvas.translate(bounds.left - 32, bounds.top - 32);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, bounds.width + 64, bounds.height + 64),
      _blurPaint,
    );
    canvas.restore();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;
  ({double scale, double bias}) _toneAt(Duration now) {
    final start = _transitionStart;
    if (start == null) return (scale: _targetScale, bias: _targetBias);
    final t = ((now - start).inMicroseconds / 140000).clamp(0.0, 1.0);
    final eased = t * t * (3 - 2 * t);
    if (t == 1) _transitionStart = null;
    return (
      scale: _fromScale + (_targetScale - _fromScale) * eased,
      bias: _fromBias + (_targetBias - _fromBias) * eased,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_scene == null) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    final backdrop = StudyLightBackdrop.locate(
      this,
      dark: _scene?.dark ?? false,
      fallbackOrigin: _lastOrigin,
    );
    _lastOrigin = backdrop.origin;
    final range = backdrop.scene.readingRange(
      (backdrop.origin & size).inflate(6),
      backdrop.size,
    );
    final now = SchedulerBinding.instance.currentFrameTimeStamp;
    if (range != _lastRange) {
      _lastRange = range;
      final next = resolveSceneInk(
        _colors,
        range,
        preferLight: _appearance?.light ?? backdrop.scene.dark,
      );
      final scale = 1 - next.amount;
      final bias = next.light ? 255 * next.amount : 0.0;
      if (scale != _targetScale || bias != _targetBias) {
        final displayed = _toneAt(now);
        _fromScale = displayed.scale;
        _fromBias = displayed.bias;
        _targetScale = scale;
        _targetBias = bias;
        _transitionStart = !_reduceMotion && _appearance != null ? now : null;
        if (_transitionStart != null) {
          StudyLightBackdrop.animateReadingInk(this);
        }
      }
      _appearance = next;
    }
    final tone = _toneAt(now);
    if (tone.scale == 1 && tone.bias == 0) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    if (tone != _lastTone) {
      _lastTone = tone;
      _toneFilter = inkToneFilter(tone.scale, tone.bias);
    }
    layer = context.pushColorFilter(
      offset,
      _toneFilter!,
      super.paint,
      oldLayer: layer as ColorFilterLayer?,
    );
  }
}
