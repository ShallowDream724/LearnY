import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/timetable_layout.dart';
import '../../support/schedule_fixture.dart';

void main() {
  test(
    'retains 08:00 and internal gaps with exact unusual start and end times',
    () {
      final layout = TimetableLayout.fromSnapshot(
        extremeScheduleSnapshot(scheduleToday),
      );
      expect(layout.start, 480);
      expect(layout.end, 1305); // 21:45, no hours added after the last class.
      expect(layout.ticks, [480, 590, 810, 920, 1030, 1160]);
      final lab = layout.entries.firstWhere((e) => e.item.courseName == '综合实验');
      final practice = layout.entries.firstWhere(
        (e) => e.item.courseName == '设计实践',
      );
      expect(lab.duration, 205); // 13:30–16:55
      expect(practice.duration, 150); // 16:10–18:40
      for (final zoom in [.86, .94, 1.88]) {
        expect(layout.offset(practice.start, zoom), closeTo(490 * zoom, .001));
        expect(
          layout.offset(practice.start, zoom) - layout.offset(lab.start, zoom),
          closeTo(160 * zoom, .001),
        );
      }
    },
  );

  test('a sparse afternoon week retains morning and trims only its tail', () {
    final layout = TimetableLayout.fromSnapshot(
      _snapshot([_item('afternoon', '13:30', '16:55')]),
    );
    expect(layout.start, 480);
    expect(layout.end, 1015);
    expect(layout.ticks, [480, 590, 810, 920]);
    expect(layout.offset(layout.entries.single.start, 1), 330);
  });

  test('overlap groups share lanes without narrowing unrelated classes', () {
    final layout = TimetableLayout.fromSnapshot(
      _snapshot([
        _item('long', '13:30', '16:55'),
        _item('middle', '14:20', '15:05'),
        _item('late', '16:10', '18:40'),
        _item('evening', '19:20', '21:45'),
      ]),
    );
    expect(layout.entries.map((e) => e.laneCount), [2, 2, 2, 1]);
    expect(layout.entries.map((e) => e.lane), [0, 1, 1, 0]);
    expect(layout.entries[2].start, 970);
  });

  test(
    'early and unknown times are retained without fabricated clock labels',
    () {
      final layout = TimetableLayout.fromSnapshot(
        _snapshot([_item('early', '07:30', '08:00'), _item('unknown', '', '')]),
      );
      expect(layout.start, 450);
      expect(layout.end, 480);
      expect(layout.untimed.single.item.courseName, 'unknown');
    },
  );
}

TodayScheduleItem _item(String name, String start, String end) =>
    TodayScheduleItem(
      courseName: name,
      startTime: start,
      endTime: end,
      location: '',
    );
HomeScheduleSnapshot _snapshot(List<TodayScheduleItem> items) {
  final days = scheduleFixtureSnapshot(scheduleToday, [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ]).days;
  return HomeScheduleSnapshot(
    days: days,
    itemsByDateKey: {days.first.dateKey: items},
  );
}
