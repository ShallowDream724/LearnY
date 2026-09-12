import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Decode once at bounded resolution; keep native image buffers out of prefs.
class WallpaperImageService {
  static const maxInputBytes = 64 * 1024 * 1024;
  static const maxDecodeSide = 3072;
  static const maxOutputSide = 2560;

  Future<ui.Image> decode(String path) async {
    final length = await File(path).length();
    if (length <= 0 || length > maxInputBytes) {
      throw const FormatException('请选择小于 64 MB 的图片');
    }
    final buffer = await ui.ImmutableBuffer.fromFilePath(path);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final scale = math.min(
        1.0,
        maxDecodeSide / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).round()),
        targetHeight: math.max(1, (descriptor.height * scale).round()),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }

  Future<Uint8List> crop(ui.Image image, ui.Rect rect) async {
    final scale = math.min(
      1.0,
      maxOutputSide / math.max(rect.width, rect.height),
    );
    final width = math.max(1, (rect.width * scale).round());
    final height = math.max(1, (rect.height * scale).round());
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      image,
      rect,
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    final picture = recorder.endRecording();
    ui.Image? output;
    try {
      output = await picture.toImage(width, height);
      final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw const FormatException('图片处理失败');
      return bytes.buffer.asUint8List();
    } finally {
      output?.dispose();
      picture.dispose();
    }
  }
}
