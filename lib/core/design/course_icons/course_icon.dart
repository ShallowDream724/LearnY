import 'package:flutter/material.dart';

import 'course_icon_canvas.dart';
import 'course_icon_definition.dart';

/// Artwork is decorative beside the course name. Interactive parents (such as
/// the picker) own labels and selected/button semantics, avoiding double reads.
class CourseIcon extends StatelessWidget {
  const CourseIcon({
    super.key,
    required this.option,
    required this.color,
    this.size = 40,
  });
  final CourseIconOption option;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _CourseIconPainter(option, color)),
      ),
    ),
  );
}

class _CourseIconPainter extends CustomPainter {
  const _CourseIconPainter(this.option, this.color);
  final CourseIconOption option;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    option.draw(CourseIconCanvas(canvas, color));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CourseIconPainter old) =>
      option != old.option || color != old.color;
}
