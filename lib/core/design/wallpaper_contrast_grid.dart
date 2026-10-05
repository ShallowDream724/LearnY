import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Small conservative color bounds of the decoded wallpaper, not averages.
/// Bilinear interpolation stays inside the per-channel bounds of its source
/// pixels. The painter includes a source-pixel gutter when querying the grid.
class WallpaperContrastGrid {
  WallpaperContrastGrid._(
    this.width,
    this.height,
    this.columns,
    this.rows,
    this._channels,
  );
  final int width;
  final int height;
  final int columns;
  final int rows;
  final Uint8List _channels;

  Color extreme(int column, int row, {required bool brightest}) {
    final start = (row * columns + column) * 6 + (brightest ? 3 : 0);
    return Color.fromARGB(
      255,
      _channels[start],
      _channels[start + 1],
      _channels[start + 2],
    );
  }

  /// Aggregate byte bounds before the contrast calculation. A regional query
  /// does no per-cell gamma conversion, image scan or temporary color list.
  Color extremeRegion(
    int left,
    int top,
    int right,
    int bottom, {
    required bool brightest,
  }) {
    var red = brightest ? 0 : 255;
    var green = red;
    var blue = red;
    final componentOffset = brightest ? 3 : 0;
    for (var y = top; y < bottom; y++) {
      for (var x = left; x < right; x++) {
        final i = (y * columns + x) * 6 + componentOffset;
        final r = _channels[i];
        final g = _channels[i + 1];
        final b = _channels[i + 2];
        if (brightest ? r > red : r < red) red = r;
        if (brightest ? g > green : g < green) green = g;
        if (brightest ? b > blue : b < blue) blue = b;
      }
    }
    return Color.fromARGB(255, red, green, blue);
  }
}

class WallpaperContrastRequest {
  const WallpaperContrastRequest({
    required this.width,
    required this.height,
    required this.pixels,
    required this.dark,
    required this.customDark,
  });
  final int width;
  final int height;
  final TransferableTypedData pixels;
  final bool dark;
  final bool customDark;
}

/// Runs once per decoded image on a worker isolate. Only the 12 KiB grid comes
/// back; the transferred image bytes are released with the worker's lifetime.
WallpaperContrastGrid analyseWallpaperContrast(
  WallpaperContrastRequest request,
) {
  final bytes = request.pixels.materialize().asUint8List();
  final width = request.width;
  final height = request.height;
  final columns = width.clamp(1, 32);
  final rows = height.clamp(1, 64);
  final channels = Uint8List(columns * rows * 6);
  for (var i = 0; i < channels.length; i += 6) {
    channels[i] = channels[i + 1] = channels[i + 2] = 255;
  }
  final base = request.dark ? const [27, 29, 32] : const [247, 248, 251];
  final gains = request.customDark
      ? const [.46, .49, .54]
      : const [1.0, 1.0, 1.0];
  for (var y = 0; y < height; y++) {
    final row = y * rows ~/ height;
    for (var x = 0; x < width; x++) {
      final pixel = (y * width + x) * 4;
      final alpha = bytes[pixel + 3] / 255;
      final cell = (row * columns + x * columns ~/ width) * 6;
      for (var component = 0; component < 3; component++) {
        final value =
            bytes[pixel + component] * gains[component] * alpha +
            base[component] * (1 - alpha);
        // Include quantization error as well as real variation in the tile.
        final low = (value.floor() - 1).clamp(0, 255);
        final high = (value.ceil() + 1).clamp(0, 255);
        if (low < channels[cell + component]) channels[cell + component] = low;
        if (high > channels[cell + 3 + component]) {
          channels[cell + 3 + component] = high;
        }
      }
    }
  }
  return WallpaperContrastGrid._(width, height, columns, rows, channels);
}
