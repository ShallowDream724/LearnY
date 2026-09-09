import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'app_theme_colors.dart';

/// One authored landscape spans the shell. Glass samples this same scene at
/// paint time, so scrolling does not need measurements or per-card image loads.
class StudyLightBackdrop extends StatefulWidget {
  const StudyLightBackdrop({super.key, required this.child});

  final Widget child;

  static String assetFor(Brightness brightness) =>
      'assets/artwork/landscape_${brightness == Brightness.dark ? 'dark' : 'light'}.webp';

  static StudyLightScene? sceneOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SceneScope>()?.scene;

  static ({StudyLightScene scene, Size size, Offset origin}) locate(
    RenderBox surface, {
    required bool dark,
  }) {
    RenderObject? ancestor = surface.parent;
    while (ancestor != null && ancestor is! _LightBackdrop) {
      ancestor = ancestor.parent;
    }
    final backdrop = ancestor as _LightBackdrop?;
    return (
      scene: backdrop?.scene ?? StudyLightScene(dark: dark),
      size: backdrop?.size ?? surface.size,
      origin: backdrop == null
          ? Offset.zero
          : MatrixUtils.transformPoint(
              surface.getTransformTo(backdrop),
              Offset.zero,
            ),
    );
  }

  @override
  State<StudyLightBackdrop> createState() => _StudyLightBackdropState();
}

class _StudyLightBackdropState extends State<StudyLightBackdrop> {
  ImageStream? _stream;
  ImageInfo? _image;
  String? _asset;
  late final _listener = ImageStreamListener(_onImage);
  late StudyLightScene _scene;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = context.isDark;
    final asset = StudyLightBackdrop.assetFor(Theme.of(context).brightness);
    if (_asset == asset) return;
    _asset = asset;
    _stream?.removeListener(_listener);
    _replaceImage(null);
    _scene = StudyLightScene(dark: dark);
    _stream = AssetImage(asset).resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener);
  }

  void _onImage(ImageInfo image, bool synchronousCall) {
    void update() {
      _replaceImage(image);
      _scene = StudyLightScene(dark: context.isDark, image: image.image);
    }

    if (synchronousCall) {
      update();
    } else {
      setState(update);
    }
  }

  void _replaceImage(ImageInfo? next) {
    final previous = _image;
    _image = next;
    if (previous != null) {
      // Match Flutter Image: the old render tree may still use this frame until
      // the pending rebuild replaces it, including retained painting layers.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _replaceImage(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SceneScope(
    scene: _scene,
    child: _SceneLayer(scene: _scene, child: widget.child),
  );
}

class _SceneScope extends InheritedWidget {
  const _SceneScope({required this.scene, required super.child});
  final StudyLightScene scene;

  @override
  bool updateShouldNotify(_SceneScope oldWidget) =>
      !identical(scene, oldWidget.scene);
}

class _SceneLayer extends SingleChildRenderObjectWidget {
  const _SceneLayer({required this.scene, required super.child});
  final StudyLightScene scene;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LightBackdrop(scene);

  @override
  void updateRenderObject(BuildContext context, _LightBackdrop renderObject) {
    renderObject.scene = scene;
  }
}

class _LightBackdrop extends RenderProxyBox {
  _LightBackdrop(this._scene);
  StudyLightScene _scene;
  StudyLightScene get scene => _scene;
  set scene(StudyLightScene value) {
    if (identical(_scene, value)) return;
    _scene = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    scene.paint(context.canvas, size);
    context.canvas.restore();
    super.paint(context, offset);
  }
}

/// Texture and cover transform are shared by the background and every pane.
/// Clamp sampling also covers offscreen scroll-cache and refracted edge pixels.
class StudyLightScene {
  StudyLightScene({required this.dark, this.image});
  final bool dark;
  final ui.Image? image;
  ui.Shader? _shader;
  Size? _shaderSize;

  static Offset source(Size size) =>
      Offset(-size.width * .12, -size.height * .3);

  void paint(Canvas canvas, Size size, {Rect? coverage}) {
    final bounds = Offset.zero & size;
    final texture = image;
    final paint = Paint()
      ..color = dark ? const Color(0xFF1B1D20) : const Color(0xFFF3F2EC);
    if (texture != null) {
      if (_shader == null || _shaderSize != size) {
        final textureSize = Size(
          texture.width.toDouble(),
          texture.height.toDouble(),
        );
        final fitted = applyBoxFit(BoxFit.cover, textureSize, size);
        final scale = fitted.destination.width / fitted.source.width;
        // A narrow viewport frames the rising side of the same curve. Never
        // stretch a landscape image or invent a second light source for mobile.
        final framing = ((1 - size.aspectRatio) / .45).clamp(0.0, 1.0);
        final matrix = Matrix4.identity()
          ..translateByDouble(
            (size.width - texture.width * scale) * (.5 + .275 * framing),
            (size.height - texture.height * scale) / 2,
            0,
            1,
          )
          ..scaleByDouble(scale, scale, 1, 1);
        _shader = ui.ImageShader(
          texture,
          TileMode.clamp,
          TileMode.clamp,
          matrix.storage,
          filterQuality: FilterQuality.medium,
        );
        _shaderSize = size;
      }
      paint.shader = _shader;
    }
    canvas.drawRect(coverage ?? bounds, paint);
  }
}
