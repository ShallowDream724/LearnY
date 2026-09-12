import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'app_theme_colors.dart';
import 'wallpaper.dart';

/// One authored landscape spans the shell. Glass samples this same scene at
/// paint time, so scrolling does not need measurements or per-card image loads.
class StudyLightBackdrop extends StatefulWidget {
  const StudyLightBackdrop({
    super.key,
    required this.child,
    this.wallpaper = StudyWallpaper.dunes,
    this.mobileArtwork = false,
    this.strength = .3,
    this.imageProvider,
  });

  final Widget child;
  final StudyWallpaper wallpaper;
  final bool mobileArtwork;
  final double strength;
  final ImageProvider? imageProvider;

  static String assetFor(
    Brightness brightness, {
    StudyWallpaper wallpaper = StudyWallpaper.dunes,
    bool forMobile = false,
  }) => wallpaper.assetFor(brightness, forMobile: forMobile);

  static StudyLightScene? sceneOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SceneScope>()?.scene;

  static Listenable? motionOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SceneScope>()?.motion;

  static ({StudyLightScene scene, Size size, Offset origin}) locate(
    RenderBox surface, {
    required bool dark,
    Offset fallbackOrigin = Offset.zero,
  }) {
    RenderObject? ancestor = surface.parent;
    while (ancestor != null && ancestor is! _LightBackdrop) {
      ancestor = ancestor.parent;
    }
    final backdrop = ancestor as _LightBackdrop?;
    final origin = backdrop == null
        ? Offset.zero
        : MatrixUtils.transformPoint(
            surface.getTransformTo(backdrop),
            Offset.zero,
          );
    return (
      scene: backdrop?.scene ?? StudyLightScene(dark: dark),
      size: backdrop?.size ?? surface.size,
      // Retained sliver children have a zero paint transform while offscreen.
      // Their layers can still repaint, so never send that projection's NaN
      // coordinates into native drawing. Reuse the last visible mapping.
      origin: origin.isFinite ? origin : fallbackOrigin,
    );
  }

  @override
  State<StudyLightBackdrop> createState() => _StudyLightBackdropState();
}

class _StudyLightBackdropState extends State<StudyLightBackdrop> {
  ImageStream? _stream;
  ImageInfo? _image;
  ImageProvider? _provider;
  final _motion = _SceneMotion();
  ImageStreamListener? _listener;
  late StudyLightScene _scene;
  Color? _statusSample;
  Size? _sampleSize;
  int _sampleRevision = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImage();
  }

  @override
  void didUpdateWidget(StudyLightBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wallpaper != widget.wallpaper ||
        oldWidget.mobileArtwork != widget.mobileArtwork ||
        oldWidget.imageProvider != widget.imageProvider) {
      _resolveImage();
    }
    if (oldWidget.strength != widget.strength) {
      _scene = _scene.withStrength(widget.strength);
    }
  }

  void _resolveImage() {
    final dark = context.isDark;
    final wallpaper = widget.wallpaper;
    final mobile = widget.mobileArtwork;
    final provider =
        widget.imageProvider ??
        AssetImage(
          wallpaper.assetFor(Theme.of(context).brightness, forMobile: mobile),
        );
    if (_provider == provider && _scene.dark == dark) {
      if (_sampleSize != MediaQuery.sizeOf(context)) _sampleStatusBar();
      return;
    }
    _provider = provider;
    if (_listener != null) _stream?.removeListener(_listener!);
    // Keep the current landscape visible while a new selection decodes.
    if (_image == null || _scene.dark != dark) {
      _replaceImage(null);
      _scene = StudyLightScene(
        dark: dark,
        wallpaper: wallpaper,
        mobileArtwork: mobile,
        strength: widget.strength,
      );
    }
    _listener = ImageStreamListener(
      (image, synchronousCall) {
        if (!mounted || _provider != provider) {
          image.dispose();
          return;
        }
        _onImage(image, synchronousCall, wallpaper, dark, mobile);
      },
      onError: (Object error, StackTrace? stack) {
        // Import validates custom files; external deletion/corruption can still
        // happen later. Preserve the previous scene without a framework crash.
        debugPrint('[LearnY] Background image could not be loaded');
      },
    );
    _stream = provider.resolve(createLocalImageConfiguration(context));
    _stream!.addListener(_listener!);
  }

  void _onImage(
    ImageInfo image,
    bool synchronousCall,
    StudyWallpaper wallpaper,
    bool dark,
    bool mobile,
  ) {
    void update() {
      _replaceImage(image);
      _scene = StudyLightScene(
        dark: dark,
        image: image.image,
        wallpaper: wallpaper,
        mobileArtwork: mobile,
        strength: widget.strength,
      );
    }

    if (synchronousCall) {
      update();
    } else {
      setState(update);
    }
    _sampleStatusBar();
  }

  Future<void> _sampleStatusBar() async {
    final image = _scene.image;
    if (image == null) return;
    final size = MediaQuery.sizeOf(context);
    _sampleSize = size;
    final height = MediaQuery.viewPaddingOf(context).top.clamp(1.0, 80.0);
    final revision = ++_sampleRevision;
    final texture = image.clone();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(16 / size.width, 4 / height);
    StudyLightScene(
      dark: _scene.dark,
      image: texture,
      wallpaper: _scene.wallpaper,
      mobileArtwork: _scene.mobileArtwork,
      strength: 1,
    ).paint(canvas, size);
    final picture = recorder.endRecording();
    ui.Image? sample;
    try {
      sample = await picture.toImage(16, 4);
      final bytes = await sample.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted || revision != _sampleRevision || bytes == null) return;
      var r = 0;
      var g = 0;
      var b = 0;
      for (var i = 0; i < bytes.lengthInBytes; i += 4) {
        r += bytes.getUint8(i);
        g += bytes.getUint8(i + 1);
        b += bytes.getUint8(i + 2);
      }
      setState(
        () => _statusSample = Color.fromARGB(255, r ~/ 64, g ~/ 64, b ~/ 64),
      );
    } catch (_) {
      // Theme contrast remains the fallback if pixel sampling is unavailable.
    } finally {
      sample?.dispose();
      picture.dispose();
      texture.dispose();
    }
  }

  SystemUiOverlayStyle _systemBars() {
    final base = _scene.dark
        ? const Color(0xFF1B1D20)
        : const Color(0xFFF7F8FB);
    final color = _statusSample == null
        ? base
        : Color.alphaBlend(
            _statusSample!.withValues(alpha: widget.strength.clamp(0, 1)),
            base,
          );
    return (color.computeLuminance() > .179
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
        );
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
    if (_listener != null) _stream?.removeListener(_listener!);
    _replaceImage(null);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SceneScope(
    scene: _scene,
    motion: _motion,
    child: NotificationListener<ScrollNotification>(
      onNotification: (_) {
        // Moving a cached PageView layer changes its sampling coordinates but
        // does not otherwise repaint its header/glass display lists.
        _motion.moved();
        return false;
      },
      child: Theme(
        data: Theme.of(context).copyWith(
          appBarTheme: Theme.of(
            context,
          ).appBarTheme.copyWith(systemOverlayStyle: _systemBars()),
        ),
        child: _SceneLayer(scene: _scene, child: widget.child),
      ),
    ),
  );
}

class _SceneScope extends InheritedWidget {
  const _SceneScope({
    required this.scene,
    required this.motion,
    required super.child,
  });
  final StudyLightScene scene;
  final Listenable motion;

  @override
  bool updateShouldNotify(_SceneScope oldWidget) =>
      !identical(scene, oldWidget.scene);
}

class _SceneMotion extends ChangeNotifier {
  void moved() => notifyListeners();
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

/// An opaque slice of the same scene for scrolling page headers: the wallpaper
/// remains continuous while scrolled text cannot show through the toolbar.
class StudyLightSurface extends LeafRenderObjectWidget {
  const StudyLightSurface({super.key});

  @override
  RenderObject createRenderObject(BuildContext context) => _SceneSurfaceBox(
    StudyLightBackdrop.sceneOf(context),
    context.isDark,
    StudyLightBackdrop.motionOf(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _SceneSurfaceBox).update(
      StudyLightBackdrop.sceneOf(context),
      context.isDark,
      StudyLightBackdrop.motionOf(context),
    );
  }
}

class _SceneSurfaceBox extends RenderBox {
  _SceneSurfaceBox(this.scene, this.dark, this.motion);
  StudyLightScene? scene;
  bool dark;
  Listenable? motion;
  Offset _lastSceneOrigin = Offset.zero;

  void update(StudyLightScene? next, bool nextDark, Listenable? nextMotion) {
    if (motion != nextMotion) {
      if (attached) motion?.removeListener(markNeedsPaint);
      motion = nextMotion;
      if (attached) motion?.addListener(markNeedsPaint);
    }
    if (identical(scene, next) && dark == nextDark) return;
    scene = next;
    dark = nextDark;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    motion?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    motion?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get sizedByParent => true;
  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    final backdrop = StudyLightBackdrop.locate(
      this,
      dark: dark,
      fallbackOrigin: _lastSceneOrigin,
    );
    _lastSceneOrigin = backdrop.origin;
    context.canvas.save();
    context.canvas.translate(
      offset.dx - backdrop.origin.dx,
      offset.dy - backdrop.origin.dy,
    );
    backdrop.scene.paint(
      context.canvas,
      backdrop.size,
      coverage: backdrop.origin & size,
    );
    context.canvas.restore();
  }
}

/// Texture and cover transform are shared by the background and every pane.
/// Clamp sampling also covers offscreen scroll-cache and refracted edge pixels.
class StudyLightScene {
  StudyLightScene({
    required this.dark,
    this.image,
    this.wallpaper = StudyWallpaper.dunes,
    this.mobileArtwork = false,
    this.strength = .3,
  });
  final bool dark;
  final ui.Image? image;
  final StudyWallpaper wallpaper;
  final bool mobileArtwork;
  final double strength;
  ui.Shader? _shader;
  Size? _shaderSize;

  StudyLightScene withStrength(double strength) =>
      StudyLightScene(
          dark: dark,
          image: image,
          wallpaper: wallpaper,
          mobileArtwork: mobileArtwork,
          strength: strength,
        )
        .._shader = _shader
        .._shaderSize = _shaderSize;

  static Offset source(Size size) =>
      Offset(-size.width * .12, -size.height * .3);

  void paint(Canvas canvas, Size size, {Rect? coverage}) {
    final bounds = Offset.zero & size;
    final texture = image;
    final paintBounds = coverage ?? bounds;
    canvas.drawRect(
      paintBounds,
      Paint()..color = dark ? const Color(0xFF1B1D20) : const Color(0xFFF7F8FB),
    );
    if (texture == null || strength <= 0) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: strength.clamp(0, 1));
    if (dark && wallpaper == StudyWallpaper.custom) {
      paint.colorFilter = customWallpaperDarkFilter;
    }
    if (_shader == null || _shaderSize != size) {
      final textureSize = Size(
        texture.width.toDouble(),
        texture.height.toDouble(),
      );
      final fitted = applyBoxFit(BoxFit.cover, textureSize, size);
      final artwork = wallpaper.artwork(forMobile: mobileArtwork);
      final scale =
          fitted.destination.width / fitted.source.width * artwork.zoom;
      final framing = ((1 - size.aspectRatio) / .45).clamp(0.0, 1.0);
      final alignment = Alignment.lerp(
        artwork.wideAlignment,
        artwork.tallAlignment,
        framing,
      )!;
      final matrix = Matrix4.identity()
        ..translateByDouble(
          (size.width - texture.width * scale) * (1 + alignment.x) / 2,
          (size.height - texture.height * scale) * (1 + alignment.y) / 2,
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
    canvas.drawRect(paintBounds, paint);
  }
}

const customWallpaperDarkFilter = ui.ColorFilter.matrix([
  .46,
  0,
  0,
  0,
  0,
  0,
  .49,
  0,
  0,
  0,
  0,
  0,
  .54,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
]);
