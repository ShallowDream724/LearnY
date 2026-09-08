import 'package:flutter/material.dart';

/// Shared 48-unit geometry, round terminals and two optical line weights.
/// Drawings contain geometry only; the caller owns scale, color and semantics.
class CourseIconCanvas {
  CourseIconCanvas(this.canvas, this.color);

  final Canvas canvas;
  final Color color;

  Paint stroke(bool secondary) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = secondary ? 1.15 : 1.65
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = secondary ? color.withValues(alpha: .58) : color;

  void outline(Path path, {bool secondary = false}) =>
      canvas.drawPath(path, stroke(secondary));

  void area(Path path, double alpha) =>
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));

  void line(
    double x1,
    double y1,
    double x2,
    double y2, {
    bool secondary = false,
  }) => canvas.drawLine(Offset(x1, y1), Offset(x2, y2), stroke(secondary));

  void dot(double x, double y, double radius, {bool secondary = false}) =>
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = color.withValues(alpha: secondary ? .58 : 1),
      );

  void circle(double x, double y, double radius, {bool secondary = false}) =>
      canvas.drawCircle(Offset(x, y), radius, stroke(secondary));
}
