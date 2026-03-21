import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/utils/deadline_time.dart';

void main() {
  group('formatRelativeDeadlineLabel', () {
    test('uses calendar-day difference instead of Duration.inDays floor', () {
      final now = DateTime(2026, 3, 21, 10, 20);
      final deadline = DateTime(2026, 3, 23, 10, 0);

      expect(formatRelativeDeadlineLabel(deadline, now: now), '后天 10:00');
    });
  });

  group('formatRelativeDayCountLabel', () {
    test('treats a two-calendar-day deadline as 后天', () {
      final now = DateTime(2026, 3, 21, 10, 20);
      final deadline = DateTime(2026, 3, 23, 10, 0);

      expect(formatRelativeDayCountLabel(deadline, now: now), '后天');
    });
  });
}
