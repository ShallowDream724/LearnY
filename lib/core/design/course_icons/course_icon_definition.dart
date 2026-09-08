import 'package:flutter/foundation.dart';

import 'course_icon_canvas.dart';

typedef CourseIconDrawing = void Function(CourseIconCanvas canvas);

@immutable
class CourseIconOption {
  const CourseIconOption({
    required this.key,
    required this.label,
    required this.group,
    required this.draw,
    this.keywords = const [],
  });

  final String key;
  final String label;
  final String group;
  final List<String> keywords;
  final CourseIconDrawing draw;

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    return needle.isEmpty ||
        [
          key,
          label,
          group,
          ...keywords,
        ].any((value) => value.toLowerCase().contains(needle));
  }
}
