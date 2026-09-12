import 'dart:math' as math;

import 'schedule_models.dart';

/// Platform-independent projection. One minute has the same height everywhere;
/// a gap in the school calendar is a gap in the timetable.
class TimetableLayout {
  TimetableLayout._(this.start, this.end, this.entries, this.untimed);

  factory TimetableLayout.fromSnapshot(HomeScheduleSnapshot snapshot) {
    final entries = <TimetablePlacement>[];
    final untimed = <({String day, TodayScheduleItem item})>[];
    for (final day in snapshot.days) {
      final timed = <TimetablePlacement>[];
      for (final item in snapshot.itemsFor(day)) {
        final start = parseMinutes(item.startTime);
        if (start == null) {
          untimed.add((day: day.dateKey, item: item));
          continue;
        }
        final end = parseMinutes(item.endTime);
        timed.add(
          TimetablePlacement(
            day: day.dateKey,
            item: item,
            start: start,
            end: end != null && end > start ? end : start + 95,
          ),
        );
      }
      timed.sort((a, b) {
        final order = a.start.compareTo(b.start);
        return order == 0 ? b.end.compareTo(a.end) : order;
      });
      // Assign lanes per connected overlap group. An unrelated class later in
      // the day must not inherit a narrow lane from an earlier collision.
      final group = <TimetablePlacement>[];
      final laneEnds = <int>[];
      var groupEnd = 0;
      void flush() {
        for (final entry in group) {
          entries.add(entry.withLanes(entry.lane, laneEnds.length));
        }
        group.clear();
        laneEnds.clear();
      }

      for (final entry in timed) {
        if (group.isNotEmpty && entry.start >= groupEnd) flush();
        var lane = laneEnds.indexWhere((end) => end <= entry.start);
        if (lane == -1) {
          lane = laneEnds.length;
          laneEnds.add(entry.end);
        } else {
          laneEnds[lane] = entry.end;
        }
        group.add(entry.withLanes(lane, 1));
        groupEnd = group.length == 1
            ? entry.end
            : math.max(groupEnd, entry.end);
      }
      flush();
    }
    final start = entries.fold(8 * 60, (value, e) => math.min(value, e.start));
    final end = entries.isEmpty
        ? 9 * 60 + 35
        : entries.map((entry) => entry.end).reduce(math.max);
    return TimetableLayout._(
      start,
      end,
      List.unmodifiable(entries),
      List.unmodifiable(untimed),
    );
  }

  /// Visual reference anchors only; upstream times are never snapped to these.
  static const periodStarts = [480, 590, 810, 920, 1030, 1160];
  final int start;
  final int end;
  final List<TimetablePlacement> entries;
  final List<({String day, TodayScheduleItem item})> untimed;
  int get duration => end - start;
  double offset(int minute, double pixelsPerMinute) =>
      (minute - start) * pixelsPerMinute;
  List<int> get ticks => {
    start,
    ...periodStarts.where((minute) => minute >= start && minute < end),
  }.toList()..sort();

  static int? parseMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return hour * 60 + minute;
  }

  static String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

class TimetablePlacement {
  const TimetablePlacement({
    required this.day,
    required this.item,
    required this.start,
    required this.end,
    this.lane = 0,
    this.laneCount = 1,
  });
  final String day;
  final TodayScheduleItem item;
  final int start;
  final int end;
  final int lane;
  final int laneCount;
  int get duration => end - start;

  TimetablePlacement withLanes(int lane, int count) => TimetablePlacement(
    day: day,
    item: item,
    start: start,
    end: end,
    lane: lane,
    laneCount: count,
  );
}
