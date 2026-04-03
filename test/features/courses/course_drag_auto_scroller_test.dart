import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/features/courses/widgets/course_drag_auto_scroller.dart';

void main() {
  group('expandCourseDragRectForViewportObstruction', () {
    test('keeps the drag rect unchanged when there is no obstruction', () {
      const dragRect = Rect.fromLTWH(20, 40, 120, 80);

      final adjusted = expandCourseDragRectForViewportObstruction(dragRect);

      expect(adjusted, dragRect);
    });

    test('expands the bottom edge into the covered bottom area', () {
      const dragRect = Rect.fromLTWH(20, 40, 120, 80);

      final adjusted = expandCourseDragRectForViewportObstruction(
        dragRect,
        viewportObstruction: const EdgeInsets.only(bottom: 84),
      );

      expect(adjusted.bottom, dragRect.bottom + 84);
      expect(adjusted.top, dragRect.top);
    });

    test('expands all covered sides symmetrically', () {
      const dragRect = Rect.fromLTWH(50, 60, 100, 70);

      final adjusted = expandCourseDragRectForViewportObstruction(
        dragRect,
        viewportObstruction: const EdgeInsets.fromLTRB(8, 12, 16, 20),
      );

      expect(adjusted, const Rect.fromLTRB(42, 48, 166, 150));
    });
  });
}
