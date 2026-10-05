import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

const readingBlurSigma = 3.0;

/// One shared, bounded Gaussian texture. Work is merged while a new wallpaper
/// or viewport arrives; scroll and strength changes never generate a texture.
class WallpaperBlur extends ChangeNotifier {
  ui.Image? _image;
  ui.Image? _source;
  final _retired = <ui.Image>{};
  double? _sigma;
  ({ui.Image source, double sigma, int revision})? _pending;
  int _revision = 0;
  bool _busy = false;
  bool _disposed = false;
  Timer? _resizeDebounce;

  ui.Image? get image => _image;

  void request(ui.Image source, double sigma) {
    final quantized = math.max(.05, (sigma.clamp(.05, 256) * 8).round() / 8);
    if (_disposed || identical(source, _source) && _sigma == quantized) return;
    final resizing = identical(source, _source) && _image != null;
    _resizeDebounce?.cancel();
    _resizeDebounce = null;
    _source = source;
    _sigma = quantized;
    _pending?.source.dispose();
    _pending = (
      source: source.clone(),
      sigma: quantized,
      revision: ++_revision,
    );
    if (resizing) {
      _resizeDebounce = Timer(const Duration(milliseconds: 120), () {
        _resizeDebounce = null;
        if (!_busy) unawaited(_drain());
      });
    } else if (!_busy) {
      unawaited(_drain());
    }
  }

  Future<void> _drain() async {
    _busy = true;
    try {
      while (!_disposed && _pending != null && _resizeDebounce == null) {
        final request = _pending!;
        _pending = null;
        ui.Image? next;
        try {
          next = await gaussianWallpaper(request.source, request.sigma);
        } catch (error) {
          debugPrint('[LearnY] Wallpaper blur unavailable: $error');
        } finally {
          request.source.dispose();
        }
        if (_disposed || request.revision != _revision) {
          next?.dispose();
          continue;
        }
        if (next == null) continue;
        final previous = _image;
        _image = next;
        notifyListeners();
        if (previous != null) {
          _retired.add(previous);
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (_retired.remove(previous)) previous.dispose();
          });
          SchedulerBinding.instance.scheduleFrame();
        }
      }
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _resizeDebounce?.cancel();
    _resizeDebounce = null;
    ++_revision;
    _pending?.source.dispose();
    _pending = null;
    _image?.dispose();
    _image = null;
    for (final image in _retired) {
      image.dispose();
    }
    _retired.clear();
    _source = null;
    super.dispose();
  }
}

/// Native Gaussian convolution, not sparse offsets or a CPU pixel readback.
/// At most 1024 × 1024 RGBA pixels (4 MiB); every reading field shares it.
Future<ui.Image> gaussianWallpaper(ui.Image source, double sourceSigma) async {
  final scale = math.min(1.0, 1024 / math.max(source.width, source.height));
  final width = math.max(1, (source.width * scale).round());
  final height = math.max(1, (source.height * scale).round());
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    source,
    ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()
      ..filterQuality = ui.FilterQuality.high
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: sourceSigma * scale,
        sigmaY: sourceSigma * scale,
        tileMode: ui.TileMode.clamp,
      ),
  );
  final picture = recorder.endRecording();
  try {
    return await picture.toImage(width, height);
  } finally {
    picture.dispose();
  }
}
