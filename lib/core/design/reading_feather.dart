import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// The content rectangle has constant protection. Only its exterior fades.
/// Nine disjoint patches avoid blurred masks, readbacks and offscreen layers.
class ReadingFeather {
  ReadingFeather(this.color);
  final Color color;
  static const extent = 36.0;
  static const _stops = [0.0, .125, .25, .375, .5, .625, .75, .875, 1.0];
  late final _colors = [
    for (final t in _stops)
      color.withValues(alpha: color.a * (1 - t * t * (3 - 2 * t))),
  ];
  final _fill = Paint();
  Size? _size;
  double? _topExtent;
  List<(Rect, Paint)> _patches = const [];

  void paint(Canvas canvas, Rect core, {double topExtent = extent}) {
    if (core.isEmpty || color.a == 0) return;
    topExtent = topExtent.clamp(0.0, extent);
    if (_size != core.size || _topExtent != topExtent) {
      _prepare(core.size, topExtent);
    }
    canvas.save();
    canvas.translate(core.left, core.top);
    canvas.drawRect(Offset.zero & core.size, _fill..color = color);
    for (final (bounds, paint) in _patches) {
      canvas.drawRect(bounds, paint);
    }
    canvas.restore();
  }

  void _prepare(Size size, double topExtent) {
    _size = size;
    _topExtent = topExtent;
    final core = Offset.zero & size;
    final patches = <(Rect, Paint)>[];
    void side(Rect bounds, Offset start, Offset end) {
      if (bounds.isEmpty) return;
      patches.add((
        bounds,
        Paint()..shader = ui.Gradient.linear(start, end, _colors, _stops),
      ));
    }

    side(
      Rect.fromLTRB(core.left, core.top - topExtent, core.right, core.top),
      core.topLeft,
      core.topLeft.translate(0, -topExtent),
    );
    side(
      Rect.fromLTRB(core.left, core.bottom, core.right, core.bottom + extent),
      core.bottomLeft,
      core.bottomLeft.translate(0, extent),
    );
    side(
      Rect.fromLTRB(core.left - extent, core.top, core.left, core.bottom),
      core.topLeft,
      core.topLeft.translate(-extent, 0),
    );
    side(
      Rect.fromLTRB(core.right, core.top, core.right + extent, core.bottom),
      core.topRight,
      core.topRight.translate(extent, 0),
    );
    for (final (corner, dx, dy) in [
      (core.topLeft, -1, -1),
      (core.topRight, 1, -1),
      (core.bottomLeft, -1, 1),
      (core.bottomRight, 1, 1),
    ]) {
      final height = dy < 0 ? topExtent : extent;
      if (height == 0) continue;
      final transform = Matrix4.identity()
        ..translateByDouble(corner.dx, corner.dy, 0, 1)
        ..scaleByDouble(1, height / extent, 1, 1)
        ..translateByDouble(-corner.dx, -corner.dy, 0, 1);
      patches.add((
        Rect.fromPoints(corner, corner.translate(dx * extent, dy * height)),
        Paint()
          ..shader = ui.Gradient.radial(
            corner,
            extent,
            _colors,
            _stops,
            TileMode.clamp,
            transform.storage,
          ),
      ));
    }
    _patches = patches;
  }
}
