import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../wallpaper/wallpaper_crop.dart';
import '../wallpaper/wallpaper_image_service.dart';
import 'app_light_scene.dart';
import 'app_theme_colors.dart';
import 'typography.dart';

typedef ApplyWallpaper =
    Future<void> Function(Uint8List bytes, Rect crop, int intensity);

Future<bool?> showWallpaperCropEditor(
  BuildContext context, {
  required String sourcePath,
  required ApplyWallpaper onApply,
  Rect? initialCrop,
  int initialIntensity = 30,
}) {
  final screen = MediaQuery.sizeOf(context);
  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: false,
    builder: (_) {
      final editor = WallpaperCropEditor(
        sourcePath: sourcePath,
        screenAspectRatio: screen.aspectRatio,
        initialCrop: initialCrop,
        initialIntensity: initialIntensity,
        onApply: onApply,
      );
      return screen.width < 700
          ? Dialog.fullscreen(child: editor)
          : Dialog(
              clipBehavior: Clip.antiAlias,
              insetPadding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 1040,
                height: math.min(820, screen.height - 48),
                child: editor,
              ),
            );
    },
  );
}

/// One draft owns framing; only Apply exports pixels and changes preferences.
class WallpaperCropEditor extends StatefulWidget {
  const WallpaperCropEditor({
    super.key,
    required this.sourcePath,
    required this.screenAspectRatio,
    required this.onApply,
    this.initialCrop,
    this.initialIntensity = 30,
  });
  final String sourcePath;
  final double screenAspectRatio;
  final ApplyWallpaper onApply;
  final Rect? initialCrop;
  final int initialIntensity;
  @override
  State<WallpaperCropEditor> createState() => _WallpaperCropEditorState();
}

class _WallpaperCropEditorState extends State<WallpaperCropEditor> {
  final _images = WallpaperImageService();
  ui.Image? _image;
  Rect _crop = Rect.zero;
  Rect _gestureCrop = Rect.zero;
  Offset _gestureFocal = Offset.zero;
  Offset _resizeAnchor = Offset.zero;
  late double _ratio = widget.screenAspectRatio;
  late int _intensity = widget.initialIntensity;
  String _preset = '屏幕';
  bool _preview = false;
  bool _saving = false;
  String? _error;

  Size get _imageSize =>
      Size(_image!.width.toDouble(), _image!.height.toDouble());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final image = await _images.decode(widget.sourcePath);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _image = image;
        _crop = widget.initialCrop == null
            ? WallpaperCrop.centered(_imageSize, _ratio)
            : WallpaperCrop.restore(widget.initialCrop!, _imageSize);
        _ratio = _crop.width / _crop.height;
        if (widget.initialCrop != null) _preset = '已保存';
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is FormatException
              ? error.message
              : '无法打开这张图片，请尝试 JPG、PNG 或 WebP',
        );
      }
    }
  }

  @override
  void dispose() {
    final image = _image;
    if (image != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => image.dispose());
    }
    super.dispose();
  }

  void _setCrop(Rect crop) =>
      setState(() => _crop = WallpaperCrop.constrain(crop, _imageSize, _ratio));

  void _zoom(double zoom) {
    final width = WallpaperCrop.centered(_imageSize, _ratio).width / zoom;
    _setCrop(
      Rect.fromCenter(
        center: _crop.center,
        width: width,
        height: width / _ratio,
      ),
    );
  }

  Future<void> _apply() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final bytes = await _images.crop(_image!, _crop);
      if (!mounted) return;
      await widget.onApply(
        bytes,
        WallpaperCrop.normalize(_crop, _imageSize),
        _intensity,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '背景未能保存，请重试';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        backgroundColor: colors.surface,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: '取消裁剪',
            onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
          ),
          title: const Text('裁剪背景'),
          actions: [
            TextButton(
              onPressed: _image == null || _saving
                  ? null
                  : () => setState(
                      () => _crop = WallpaperCrop.centered(_imageSize, _ratio),
                    ),
              child: const Text('重置'),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _image == null
              ? Center(
                  child: _error == null
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!),
                        ),
                )
              : LayoutBuilder(
                  builder: (context, bounds) {
                    final stage = _stage();
                    final controls = _controls();
                    return bounds.maxWidth >= 700
                        ? Row(
                            children: [
                              Expanded(child: stage),
                              SizedBox(width: 300, child: controls),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(child: stage),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: bounds.maxHeight * .49,
                                ),
                                child: controls,
                              ),
                            ],
                          );
                  },
                ),
        ),
      ),
    );
  }

  Widget _controls() {
    final maxRect = WallpaperCrop.centered(_imageSize, _ratio);
    final maxZoom = math.min(8.0, maxRect.width / math.min(48, maxRect.width));
    final zoom = (maxRect.width / _crop.width).clamp(1.0, maxZoom);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final preset in {
                '屏幕': widget.screenAspectRatio,
                '原图': _imageSize.aspectRatio,
                '竖图': 9 / 16,
                '横图': 16 / 9,
                '方形': 1.0,
              }.entries)
                ChoiceChip(
                  showCheckmark: false,
                  label: Text(preset.key),
                  selected: _preset == preset.key,
                  onSelected: _saving
                      ? null
                      : (_) => setState(() {
                          _preset = preset.key;
                          _ratio = preset.value;
                          _crop = WallpaperCrop.constrain(
                            _crop,
                            _imageSize,
                            _ratio,
                          );
                        }),
                ),
            ],
          ),
          Row(
            children: [
              const Text('取景缩放'),
              Expanded(
                child: Slider(
                  value: zoom,
                  min: 1,
                  max: maxZoom,
                  semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)} 倍',
                  onChanged: _saving || maxZoom == 1 ? null : _zoom,
                ),
              ),
              Text('${zoom.toStringAsFixed(1)}×'),
            ],
          ),
          Row(
            children: [
              const Text('背景强度'),
              Expanded(
                child: Slider(
                  value: _intensity.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  semanticFormatterCallback: (v) => '${v.round()}%',
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _intensity = v.round()),
                ),
              ),
              Text('$_intensity%'),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  _preview ? '阅读效果' : '拖动选框，双指或滚轮缩放',
                  style: AppTypography.bodySmall.copyWith(
                    color: context.colors.subtitle,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(() => _preview = !_preview),
                icon: Icon(
                  _preview ? Icons.crop : Icons.visibility_outlined,
                  size: 18,
                ),
                label: Text(_preview ? '调整裁剪' : '预览效果'),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton.icon(
            onPressed: _saving ? null : _apply,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(_saving ? '正在应用…' : '应用背景'),
          ),
        ],
      ),
    );
  }

  Widget _stage() => LayoutBuilder(
    builder: (context, bounds) {
      final stageSize = Size(bounds.maxWidth, bounds.maxHeight);
      final available = Size(
        math.max(1, stageSize.width - 48),
        math.max(1, stageSize.height - 40),
      );
      final fitted = applyBoxFit(
        BoxFit.contain,
        _imageSize,
        available,
      ).destination;
      final imageRect = Alignment.center.inscribe(
        fitted,
        Offset.zero & stageSize,
      );
      final scale = fitted.width / _imageSize.width;
      final selection = Rect.fromLTWH(
        imageRect.left + _crop.left * scale,
        imageRect.top + _crop.top * scale,
        _crop.width * scale,
        _crop.height * scale,
      );
      final painter = _CropPainter(
        image: _image!,
        imageRect: imageRect,
        crop: _crop,
        selection: selection,
        preview: _preview,
        dark: context.isDark,
        intensity: _intensity / 100,
      );
      return Semantics(
        label: '裁剪区域',
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, event) {
            if (_saving ||
                _preview ||
                (event is! KeyDownEvent && event is! KeyRepeatEvent)) {
              return KeyEventResult.ignored;
            }
            final delta = switch (event.logicalKey) {
              LogicalKeyboardKey.arrowLeft => const Offset(-1, 0),
              LogicalKeyboardKey.arrowRight => const Offset(1, 0),
              LogicalKeyboardKey.arrowUp => const Offset(0, -1),
              LogicalKeyboardKey.arrowDown => const Offset(0, 1),
              _ => Offset.zero,
            };
            if (delta == Offset.zero) return KeyEventResult.ignored;
            _setCrop(
              _crop.shift(delta * math.max(1, _imageSize.shortestSide / 100)),
            );
            return KeyEventResult.handled;
          },
          child: Listener(
            onPointerSignal: (event) {
              if (!_saving && !_preview && event is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(event, (
                  _,
                ) {
                  final zoom =
                      WallpaperCrop.centered(_imageSize, _ratio).width /
                      _crop.width;
                  _zoom(zoom * math.exp(event.scrollDelta.dy * .002));
                });
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _saving || _preview
                  ? null
                  : (details) {
                      _gestureCrop = _crop;
                      _gestureFocal = details.localFocalPoint;
                    },
              onScaleUpdate: _saving || _preview
                  ? null
                  : (details) {
                      final width = _gestureCrop.width / details.scale;
                      _setCrop(
                        Rect.fromCenter(
                          center:
                              _gestureCrop.center +
                              (details.localFocalPoint - _gestureFocal) / scale,
                          width: width,
                          height: width / _ratio,
                        ),
                      );
                    },
              child: Stack(
                children: [
                  Positioned.fill(child: CustomPaint(painter: painter)),
                  if (!_preview)
                    for (var corner = 0; corner < 4; corner++)
                      _handle(corner, selection, imageRect, scale),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _handle(int corner, Rect selection, Rect imageRect, double scale) {
    final right = corner == 1 || corner == 2;
    final bottom = corner >= 2;
    final position = Offset(
      right ? selection.right : selection.left,
      bottom ? selection.bottom : selection.top,
    );
    return Positioned(
      left: position.dx - 24,
      top: position.dy - 24,
      child: Semantics(
        label: '调整裁剪${bottom ? '下' : '上'}${right ? '右' : '左'}角',
        child: MouseRegion(
          cursor: right == bottom
              ? SystemMouseCursors.resizeUpLeftDownRight
              : SystemMouseCursors.resizeUpRightDownLeft,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _saving
                ? null
                : (_) {
                    _gestureCrop = _crop;
                    _resizeAnchor = Offset(
                      right ? _crop.left : _crop.right,
                      bottom ? _crop.top : _crop.bottom,
                    );
                    _gestureFocal = Offset(
                      right ? _crop.right : _crop.left,
                      bottom ? _crop.bottom : _crop.top,
                    );
                  },
            onPanUpdate: _saving
                ? null
                : (details) {
                    _gestureFocal += details.delta / scale;
                    final sx = right ? 1.0 : -1.0;
                    final sy = bottom ? 1.0 : -1.0;
                    final delta = _gestureFocal - _resizeAnchor;
                    final maxWidth = math.min(
                      right
                          ? _imageSize.width - _resizeAnchor.dx
                          : _resizeAnchor.dx,
                      (bottom
                              ? _imageSize.height - _resizeAnchor.dy
                              : _resizeAnchor.dy) *
                          _ratio,
                    );
                    final width = ((delta.dx * sx + delta.dy * sy * _ratio) / 2)
                        .clamp(math.min(48.0, maxWidth), maxWidth)
                        .toDouble();
                    _setCrop(
                      Rect.fromCenter(
                        center:
                            _resizeAnchor +
                            Offset(sx * width / 2, sy * width / _ratio / 2),
                        width: width,
                        height: width / _ratio,
                      ),
                    );
                  },
            child: const SizedBox.square(dimension: 48),
          ),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter({
    required this.image,
    required this.imageRect,
    required this.crop,
    required this.selection,
    required this.preview,
    required this.dark,
    required this.intensity,
  });
  final ui.Image image;
  final Rect imageRect;
  final Rect crop;
  final Rect selection;
  final bool preview;
  final bool dark;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final base = dark ? const Color(0xFF1B1D20) : const Color(0xFFF7F8FB);
    if (preview) {
      final frame = Alignment.center.inscribe(
        applyBoxFit(
          BoxFit.contain,
          crop.size,
          Size(math.max(1, size.width - 40), math.max(1, size.height - 32)),
        ).destination,
        Offset.zero & size,
      );
      canvas.drawRect(frame, Paint()..color = base);
      final paint = Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Colors.white.withValues(alpha: intensity);
      if (dark) paint.colorFilter = customWallpaperDarkFilter;
      canvas.drawImageRect(image, crop, frame, paint);
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      imageRect,
      Paint()..filterQuality = FilterQuality.medium,
    );
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(imageRect)
        ..addRect(selection),
      Paint()..color = Colors.black.withValues(alpha: .55),
    );
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: .4)
      ..strokeWidth = .7;
    for (var i = 1; i <= 2; i++) {
      final x = selection.left + selection.width * i / 3;
      final y = selection.top + selection.height * i / 3;
      canvas.drawLine(
        Offset(x, selection.top),
        Offset(x, selection.bottom),
        grid,
      );
      canvas.drawLine(
        Offset(selection.left, y),
        Offset(selection.right, y),
        grid,
      );
    }
    canvas.drawRect(
      selection,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final handle = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (final point in [
      selection.topLeft,
      selection.topRight,
      selection.bottomLeft,
      selection.bottomRight,
    ]) {
      final dx = point.dx == selection.left ? 1.0 : -1.0;
      final dy = point.dy == selection.top ? 1.0 : -1.0;
      final length = math.min(
        18.0,
        math.min(selection.width, selection.height) / 3,
      );
      canvas.drawLine(point, point + Offset(dx * length, 0), handle);
      canvas.drawLine(point, point + Offset(0, dy * length), handle);
    }
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      image != old.image ||
      imageRect != old.imageRect ||
      crop != old.crop ||
      selection != old.selection ||
      preview != old.preview ||
      dark != old.dark ||
      intensity != old.intensity;
}
