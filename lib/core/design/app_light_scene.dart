import 'dart:async';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'app_theme_colors.dart';
import 'wallpaper.dart';
import 'material_contrast.dart';
import 'colors.dart';
import 'wallpaper_contrast_grid.dart';
import 'wallpaper_blur.dart';

typedef SceneReadingPainter =
    void Function(
      Canvas canvas,
      StudyLightScene scene,
      Size viewport,
      Rect bounds,
      double visibility,
    );

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

  /// Reading fields belong below page content, never in an overlapping title
  /// layer. Registration follows RenderObject attachment, with no post-layout
  /// measurements or widget rebuilds while scrolling.
  static VoidCallback registerReadingField(
    RenderBox field,
    SceneReadingPainter painter,
    void Function(StudyLightScene) onSceneChanged, {
    required Rect Function(RenderObject backdrop) bounds,
  }) {
    RenderObject? ancestor = field.parent;
    while (ancestor != null && ancestor is! _LightBackdrop) {
      ancestor = ancestor.parent;
    }
    final backdrop = ancestor as _LightBackdrop?;
    if (backdrop == null) return () {};
    backdrop.fields[field] = (
      paint: painter,
      sceneChanged: onSceneChanged,
      bounds: bounds,
    );
    backdrop._motion.addListener(field.markNeedsPaint);
    onSceneChanged(backdrop.scene);
    backdrop.markNeedsPaint();
    return () {
      backdrop.fields.remove(field);
      backdrop._motion.removeListener(field.markNeedsPaint);
      backdrop.markNeedsPaint();
    };
  }

  static void invalidateReadingFields(RenderBox field) {
    RenderObject? ancestor = field.parent;
    while (ancestor != null && ancestor is! _LightBackdrop) {
      ancestor = ancestor.parent;
    }
    (ancestor as _LightBackdrop?)?.markNeedsPaint();
  }

  static void animateReadingInk(RenderBox field) {
    RenderObject? ancestor = field.parent;
    while (ancestor != null && ancestor is! _LightBackdrop) {
      ancestor = ancestor.parent;
    }
    final motion = (ancestor as _LightBackdrop?)?._motion;
    if (motion is _SceneMotion) motion.animateInk();
  }

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

class _StudyLightBackdropState extends State<StudyLightBackdrop>
    with SingleTickerProviderStateMixin {
  ImageStream? _stream;
  ImageInfo? _image;
  ImageProvider? _provider;
  late final _SceneMotion _motion;
  final _blur = WallpaperBlur();
  ImageStreamListener? _listener;
  late StudyLightScene _scene;
  Color? _statusSample;
  Color? _navigationSample;
  Size? _sampleSize;
  int _sampleRevision = 0;
  int _contrastRevision = 0;
  bool _contrastQueued = false;
  bool _contrastBusy = false;

  @override
  void initState() {
    super.initState();
    _motion = _SceneMotion(this);
    _blur.addListener(_onBlurReady);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _motion.stopInk();
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
      _requestBlur(size);
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
    _requestBlur(MediaQuery.sizeOf(context));
    _queueContrastAnalysis();
  }

  void _requestBlur(Size viewport) {
    final image = _scene.image;
    if (image == null || viewport.isEmpty) return;
    _blur.request(
      image,
      readingBlurSigma / _scene.texturePlacement(viewport).scale,
    );
  }

  void _onBlurReady() {
    if (mounted) setState(() => _scene = _scene.withReadingBlur(_blur.image));
  }

  void _queueContrastAnalysis() {
    ++_contrastRevision;
    _contrastQueued = true;
    if (!_contrastBusy) unawaited(_analyseContrast());
  }

  Future<void> _analyseContrast() async {
    _contrastBusy = true;
    try {
      while (mounted && _contrastQueued) {
        _contrastQueued = false;
        final revision = _contrastRevision;
        final scene = _scene;
        final image = scene.image;
        if (image == null) continue;
        final texture = image.clone();
        TransferableTypedData? pixels;
        try {
          pixels = await _transferWallpaperPixels(texture);
        } finally {
          texture.dispose();
        }
        if (!mounted || revision != _contrastRevision || pixels == null) {
          continue;
        }
        final grid = await compute(
          analyseWallpaperContrast,
          WallpaperContrastRequest(
            width: image.width,
            height: image.height,
            pixels: pixels,
            dark: scene.dark,
            customDark: scene.dark && scene.wallpaper == StudyWallpaper.custom,
          ),
        );
        if (!mounted || revision != _contrastRevision) continue;
        setState(() => _scene = _scene.withContrastGrid(grid));
      }
    } catch (_) {
      // Unavailable analysis uses conservative contrast, never an average guess.
    } finally {
      _contrastBusy = false;
      if (mounted && _contrastQueued) unawaited(_analyseContrast());
    }
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
    _blur.removeListener(_onBlurReady);
    _blur.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SceneScope(
    scene: _scene,
    motion: _motion,
    child: NotificationListener<ScrollNotification>(
      onNotification: (_) {
        // Moving a cached PageView layer changes its sampling coordinates but
        // does not otherwise repaint its glass display lists.
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
          child: _SceneLayer(
            scene: _scene,
            motion: _motion,
            child: widget.child,
          ),
        ),
      ),
    ),
  );
}

Future<TransferableTypedData?> _transferWallpaperPixels(ui.Image image) async {
  final bytes = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  return bytes == null
      ? null
      : TransferableTypedData.fromList([bytes.buffer.asUint8List()]);
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
  _SceneMotion(TickerProvider provider) {
    _ticker = provider.createTicker((_) {
      notifyListeners();
      if (SchedulerBinding.instance.currentFrameTimeStamp >= _inkDeadline) {
        _ticker.stop();
      }
    });
  }
  late final Ticker _ticker;
  Duration _inkDeadline = Duration.zero;
  void animateInk() {
    _inkDeadline =
        SchedulerBinding.instance.currentFrameTimeStamp +
        const Duration(milliseconds: 140);
    if (!_ticker.isActive) _ticker.start();
  }

  void moved() => notifyListeners();
  void stopInk() => _ticker.stop();
  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class _SceneLayer extends SingleChildRenderObjectWidget {
  const _SceneLayer({
    required this.scene,
    required this.motion,
    required super.child,
  });
  final StudyLightScene scene;
  final Listenable motion;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _LightBackdrop(scene, motion);

  @override
  void updateRenderObject(BuildContext context, _LightBackdrop renderObject) {
    renderObject.scene = scene;
    renderObject.motion = motion;
  }
}

class _LightBackdrop extends RenderProxyBox {
  _LightBackdrop(this._scene, this._motion);
  StudyLightScene _scene;
  Listenable _motion;
  final fields =
      <
        RenderBox,
        ({
          SceneReadingPainter paint,
          void Function(StudyLightScene) sceneChanged,
          Rect Function(RenderObject backdrop) bounds,
        })
      >{};
  set motion(Listenable value) {
    if (identical(value, _motion)) return;
    if (attached) _motion.removeListener(markNeedsPaint);
    for (final field in fields.keys) {
      _motion.removeListener(field.markNeedsPaint);
    }
    _motion = value;
    for (final field in fields.keys) {
      _motion.addListener(field.markNeedsPaint);
    }
    if (attached) _motion.addListener(markNeedsPaint);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _motion.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _motion.removeListener(markNeedsPaint);
    super.detach();
  }

  StudyLightScene get scene => _scene;
  set scene(StudyLightScene value) {
    if (identical(_scene, value)) return;
    _scene = value;
    for (final field in fields.values) {
      field.sceneChanged(value);
    }
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    scene.paint(context.canvas, size);
    final viewport = Offset.zero & size;
    for (final entry in fields.entries) {
      final field = entry.key;
      if (!field.attached || !field.hasSize) continue;
      // Navigator keeps covered routes attached. Their fields must retain the
      // latest sampler, but must not leave blur behind the visible route.
      var visible = true;
      var clip = viewport;
      RenderObject descendant = field;
      for (
        RenderObject? ancestor = field.parent;
        ancestor != null && ancestor != this;
        ancestor = ancestor.parent
      ) {
        if (ancestor is RenderOffstage && ancestor.offstage ||
            ancestor is RenderSliver && ancestor.geometry?.visible == false) {
          visible = false;
          break;
        }
        final localClip = ancestor.describeApproximatePaintClip(descendant);
        if (localClip != null) {
          final projected = MatrixUtils.transformRect(
            ancestor.getTransformTo(this),
            localClip,
          );
          if (!projected.isFinite) {
            visible = false;
            break;
          }
          clip = clip.intersect(projected);
        }
        descendant = ancestor;
      }
      if (!visible) continue;
      final bounds = entry.value.bounds(this);
      if (!bounds.isFinite || bounds.isEmpty || !bounds.overlaps(clip)) {
        continue;
      }
      final visibleInk = bounds.intersect(clip);
      final visibility =
          (visibleInk.width *
                  visibleInk.height /
                  (bounds.width * bounds.height))
              .clamp(0.0, 1.0);
      entry.value.paint(context.canvas, scene, size, bounds, visibility);
    }
    context.canvas.restore();
    super.paint(context, offset);
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
    this.contrastGrid,
    this.readingBlur,
  });
  final bool dark;
  final ui.Image? image;
  final StudyWallpaper wallpaper;
  final bool mobileArtwork;
  final double strength;
  final List<Color> samples;
  final WallpaperContrastGrid? contrastGrid;
  final ui.Image? readingBlur;
  final _opacityCache = <(Color, Color, double), double>{};
  final _rangeCache =
      <(int, int, int, int), ({Color darkest, Color brightest})>{};
  ui.Shader? _shader;
  Size? _shaderSize;
  Size? _placementSize;
  ({double scale, Offset origin})? _placement;

  StudyLightScene withStrength(double strength) =>
      StudyLightScene(
          dark: dark,
          image: image,
          wallpaper: wallpaper,
          mobileArtwork: mobileArtwork,
          strength: strength,
          samples: samples,
          contrastGrid: contrastGrid,
          readingBlur: readingBlur,
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
          contrastGrid: contrastGrid,
          readingBlur: readingBlur,
        )
        .._shader = _shader
        .._shaderSize = _shaderSize;

  StudyLightScene withContrastGrid(WallpaperContrastGrid grid) =>
      StudyLightScene(
          dark: dark,
          image: image,
          wallpaper: wallpaper,
          mobileArtwork: mobileArtwork,
          strength: strength,
          samples: samples,
          contrastGrid: grid,
          readingBlur: readingBlur,
        )
        .._shader = _shader
        .._shaderSize = _shaderSize;

  StudyLightScene withReadingBlur(ui.Image? image) =>
      StudyLightScene(
          dark: dark,
          image: this.image,
          wallpaper: wallpaper,
          mobileArtwork: mobileArtwork,
          strength: strength,
          samples: samples,
          contrastGrid: contrastGrid,
          readingBlur: image,
        )
        .._shader = _shader
        .._shaderSize = _shaderSize;

  double readingOpacity(
    Rect area,
    Size viewport, {
    double minimum = .25,
    Color? foreground,
  }) {
    final textColor =
        foreground ??
        (dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary);
    final range = readingRange(area, viewport);
    final color = dark ? range.brightest : range.darkest;
    final key = (color, textColor, minimum);
    if (_opacityCache[key] case final cached?) return cached;
    final alpha = contrastOpacity(
      color,
      textColor,
      dark: dark,
      minimum: minimum,
    );
    if (_opacityCache.length >= 128) _opacityCache.clear();
    _opacityCache[key] = alpha;
    return alpha;
  }

  /// Conservative source bounds for ink decisions. This is not an average
  /// brightness guess and does not claim a single ink can cover every texture.
  ({Color darkest, Color brightest}) readingRange(Rect area, Size viewport) {
    final base = dark ? const Color(0xFF1B1D20) : const Color(0xFFF7F8FB);
    if (image == null || strength <= 0) return (darkest: base, brightest: base);
    final grid = contrastGrid;
    if (grid == null || viewport.isEmpty) {
      return (darkest: Colors.black, brightest: Colors.white);
    }
    final placement = texturePlacement(viewport);
    final gutter = 1 + 2 / placement.scale;
    final source = Rect.fromLTRB(
      (area.left - placement.origin.dx) / placement.scale - gutter,
      (area.top - placement.origin.dy) / placement.scale - gutter,
      (area.right - placement.origin.dx) / placement.scale + gutter,
      (area.bottom - placement.origin.dy) / placement.scale + gutter,
    );
    final left = (source.left / grid.width * grid.columns).floor().clamp(
      0,
      grid.columns - 1,
    );
    final right = (source.right / grid.width * grid.columns).ceil().clamp(
      left + 1,
      grid.columns,
    );
    final top = (source.top / grid.height * grid.rows).floor().clamp(
      0,
      grid.rows - 1,
    );
    final bottom = (source.bottom / grid.height * grid.rows).ceil().clamp(
      top + 1,
      grid.rows,
    );
    final key = (left, right, top, bottom);
    if (_rangeCache[key] case final cached?) return cached;
    Color mixed(bool brightest) => Color.alphaBlend(
      grid
          .extremeRegion(left, top, right, bottom, brightest: brightest)
          .withValues(alpha: wallpaperTransmission(strength)),
      base,
    );
    final result = (darkest: mixed(false), brightest: mixed(true));
    if (_rangeCache.length >= 128) _rangeCache.clear();
    _rangeCache[key] = result;
    return result;
  }

  static Offset source(Size size) =>
      Offset(-size.width * .12, -size.height * .3);

  ({double scale, Offset origin}) texturePlacement(Size size) {
    if (_placementSize == size && _placement != null) return _placement!;
    final texture = image!;
    final textureSize = Size(
      texture.width.toDouble(),
      texture.height.toDouble(),
    );
    final fitted = applyBoxFit(BoxFit.cover, textureSize, size);
    final artwork = wallpaper.artwork(forMobile: mobileArtwork);
    final scale = fitted.destination.width / fitted.source.width * artwork.zoom;
    final framing = ((1 - size.aspectRatio) / .45).clamp(0.0, 1.0);
    final alignment = Alignment.lerp(
      artwork.wideAlignment,
      artwork.tallAlignment,
      framing,
    )!;
    final result = (
      scale: scale,
      origin: Offset(
        (size.width - texture.width * scale) * (1 + alignment.x) / 2,
        (size.height - texture.height * scale) * (1 + alignment.y) / 2,
      ),
    );
    _placementSize = size;
    return _placement = result;
  }

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
      final placement = texturePlacement(size);
      final matrix = Matrix4.identity()
        ..translateByDouble(placement.origin.dx, placement.origin.dy, 0, 1)
        ..scaleByDouble(placement.scale, placement.scale, 1, 1);
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
