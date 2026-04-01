import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/utils/china_time.dart';
import 'package:learn_y/core/utils/deadline_time.dart';

void main() {
  group('formatMonthDayHourMinuteInChina', () {
    test('renders Beijing time from a UTC instant', () {
      final utcInstant = DateTime.utc(2026, 4, 1, 2, 19);

      expect(formatMonthDayHourMinuteInChina(utcInstant), '04-01 10:19');
    });
  });

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
