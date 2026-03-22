import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/utils/homework_grade_display.dart';

void main() {
  group('resolveHomeworkGradeDisplay', () {
    test('prefers symbolic label for sentinel negative grades', () {
      final display = resolveHomeworkGradeDisplay(
        grade: -100,
        gradeLevel: null,
      );

      expect(display.numericGrade, isNull);
      expect(display.gradeLevelKey, 'checked');
      expect(display.gradeLevelLabel, '已阅');
      expect(display.primaryLabel, '已阅');
      expect(display.compactBadgeLabel, '已阅');
    });

    test('keeps numeric grades for normal scored homework', () {
      final display = resolveHomeworkGradeDisplay(
        grade: 95,
        gradeLevel: null,
      );

      expect(display.numericGrade, 95);
      expect(display.gradeLevelLabel, isNull);
      expect(display.primaryLabel, '95');
    });

    test('compresses long symbolic labels for badge display', () {
      final display = resolveHomeworkGradeDisplay(
        grade: null,
        gradeLevel: 'exempted course',
      );

      expect(display.gradeLevelLabel, '免课');
      expect(display.compactBadgeLabel, '免课');
    });
  });
}
