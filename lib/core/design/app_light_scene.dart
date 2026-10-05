import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'app_theme_colors.dart';
import 'wallpaper.dart';
import 'material_contrast.dart';
import 'colors.dart';

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
  Color? _navigationSample;
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
    final sourceProvider =
        widget.imageProvider ??
        AssetImage(
          wallpaper.assetFor(Theme.of(context).brightness, forMobile: mobile),
        );
    final size = MediaQuery.sizeOf(context);
    final ratio = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 2.0);
    // Custom photos may contain tens of megapixels. Decode only the display
    // budget, quantized so window resizing does not fill the image cache.
    final provider = widget.imageProvider == null
        ? sourceProvider
        : ResizeImage(
            sourceProvider,
            width: ((size.width * ratio / 128).ceil() * 128).clamp(128, 2560),
            height: ((size.height * ratio / 128).ceil() * 128).clamp(128, 2560),
            policy: ResizeImagePolicy.fit,
            allowUpscaling: false,
          );
    if (_provider == provider && _scene.dark == dark) {
      if (_sampleSize != MediaQuery.sizeOf(context)) _sampleSystemBars();
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
    _sampleSystemBars();
  }

  Future<void> _sampleSystemBars() async {
    final image = _scene.image;
    if (image == null) return;
    final size = MediaQuery.sizeOf(context);
    _sampleSize = size;
    final revision = ++_sampleRevision;
    final texture = image.clone();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final scene = StudyLightScene(
      dark: _scene.dark,
      image: texture,
      wallpaper: _scene.wallpaper,
      mobileArtwork: _scene.mobileArtwork,
      strength: 1,
    );
    canvas.scale(16 / size.width, 32 / size.height);
    scene.paint(canvas, size);
    final picture = recorder.endRecording();
    ui.Image? sample;
    try {
      sample = await picture.toImage(16, 32);
      final bytes = await sample.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (!mounted || revision != _sampleRevision || bytes == null) return;
      Color average(int start) {
        var r = 0;
        var g = 0;
        var b = 0;
        for (var i = start; i < start + 64 * 4; i += 4) {
          r += bytes.getUint8(i);
          g += bytes.getUint8(i + 1);
          b += bytes.getUint8(i + 2);
        }
        return Color.fromARGB(255, r ~/ 64, g ~/ 64, b ~/ 64);
      }

      setState(() {
        _statusSample = average(0);
        _navigationSample = average((16 * 32 - 64) * 4);
        _scene = _scene.withSamples([
          for (var i = 0; i < 16 * 32 * 4; i += 4)
            Color.fromARGB(
              255,
              bytes.getUint8(i),
              bytes.getUint8(i + 1),
              bytes.getUint8(i + 2),
            ),
        ]);
      });
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
    Brightness iconBrightness(Color? sample) {
      final color = sample == null
          ? base
          : Color.alphaBlend(
              sample.withValues(alpha: wallpaperTransmission(widget.strength)),
              base,
            );
      return color.computeLuminance() > .179
          ? Brightness.dark
          : Brightness.light;
    }

    return (iconBrightness(_statusSample) == Brightness.dark
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemStatusBarContrastEnforced: false,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: iconBrightness(_navigationSample),
          systemNavigationBarContrastEnforced: false,
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
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemBars(),
          child: _SceneLayer(scene: _scene, child: widget.child),
        ),
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
  const StudyLightSurface({super.key}) : _localScrim = false;
  const StudyLightSurface._scrim() : _localScrim = true;
  final bool _localScrim;

  @override
  RenderObject createRenderObject(BuildContext context) => _SceneSurfaceBox(
    StudyLightBackdrop.sceneOf(context),
    context.isDark,
    StudyLightBackdrop.motionOf(context),
    _localScrim,
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

/// Contrast belongs to the foreground group, not a wall-to-wall toolbar slab.
/// The feather stays outside the glyphs; no image readback or backdrop blur.
class StudyHeaderContent extends StatelessWidget {
  const StudyHeaderContent({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      const Positioned.fill(child: StudyLightSurface._scrim()),
      child,
    ],
  );
}

class _SceneSurfaceBox extends RenderBox {
  _SceneSurfaceBox(this.scene, this.dark, this.motion, this.localScrim);
  final bool localScrim;
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
    final coverage = backdrop.origin & size;
    if (!localScrim) {
      backdrop.scene.paint(context.canvas, backdrop.size, coverage: coverage);
    } else {
      final alpha = backdrop.scene.readingOpacity(
        coverage,
        backdrop.size,
        minimum: 0,
        foreground: dark
            ? AppColors.darkTextPrimary
            : AppColors.lightTextPrimary,
      );
      if (alpha > 0) {
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(
            coverage.inflate(18),
            const Radius.circular(22),
          ),
          Paint()
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
            ..color = (dark ? const Color(0xFF20242D) : Colors.white)
                .withValues(alpha: alpha),
        );
      }
    }
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
    this.samples = const [],
  });
  final bool dark;
  final ui.Image? image;
  final StudyWallpaper wallpaper;
  final bool mobileArtwork;
  final double strength;
  final List<Color> samples;
  final _opacityCache = <(int, int, int, int, double, Color), double>{};
  ui.Shader? _shader;
  Size? _shaderSize;

  StudyLightScene withStrength(double strength) =>
      StudyLightScene(
          dark: dark,
          image: image,
          wallpaper: wallpaper,
          mobileArtwork: mobileArtwork,
          strength: strength,
          samples: samples,
        )
        .._shader = _shader
        .._shaderSize = _shaderSize;

  StudyLightScene withSamples(List<Color> next) =>
      StudyLightScene(
          dark: dark,
          image: image,
          wallpaper: wallpaper,
          mobileArtwork: mobileArtwork,
          strength: strength,
          samples: next,
        )
        .._shader = _shader
        .._shaderSize = _shaderSize;

  double readingOpacity(
    Rect area,
    Size viewport, {
    double minimum = .25,
    Color? foreground,
  }) {
    if (samples.isEmpty || viewport.isEmpty) return dark ? .75 : .85;
    final left = (area.left / viewport.width * 16).floor().clamp(0, 15);
    final right = (area.right / viewport.width * 16).ceil().clamp(left + 1, 16);
    final top = (area.top / viewport.height * 32).floor().clamp(0, 31);
    final bottom = (area.bottom / viewport.height * 32).ceil().clamp(
      top + 1,
      32,
    );
    final textColor =
        foreground ??
        (dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final key = (left, right, top, bottom, minimum, textColor);
    if (_opacityCache[key] case final cached?) return cached;
    var alpha = minimum;
    final base = dark ? const Color(0xFF1B1D20) : const Color(0xFFF7F8FB);
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final color = Color.alphaBlend(
          samples[y * 16 + x].withValues(
            alpha: wallpaperTransmission(strength),
          ),
          base,
        );
        final needed = contrastOpacity(
          color,
          textColor,
          dark: dark,
          minimum: minimum,
        );
        if (needed > alpha) alpha = needed;
      }
    }
    if (_opacityCache.length >= 128) _opacityCache.clear();
    _opacityCache[key] = alpha;
    return alpha;
  }

  static Offset source(Size size) =>
      Offset(-size.width * .12, -size.height * .3);

  void paint(Canvas canvas, Size size, {Rect? coverage}) {
    final bounds = Offset.zero & size;
    final paintBounds = coverage ?? bounds;
    canvas.drawRect(
      paintBounds,
      Paint()..color = dark ? const Color(0xFF1B1D20) : const Color(0xFFF7F8FB),
    );
    final paint = _texturePaint(size);
    if (paint != null) canvas.drawRect(paintBounds, paint);
  }

  Paint? _texturePaint(Size size) {
    final texture = image;
    if (texture == null || strength <= 0) return null;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: wallpaperTransmission(strength));
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
    return paint;
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
