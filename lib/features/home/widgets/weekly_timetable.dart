import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/design/app_materials.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/schedule/schedule_models.dart';

/// A shared time axis preserves duration and overlaps, compressing long gaps.
class WeeklyTimetable extends StatefulWidget {
  const WeeklyTimetable({
    super.key,
    required this.snapshot,
    required this.onOpenItem,
    this.showEmptyWeekends = false,
  });
  final HomeScheduleSnapshot snapshot;
  final ValueChanged<TodayScheduleItem> onOpenItem;
  final bool showEmptyWeekends;
  @override
  State<WeeklyTimetable> createState() => _WeeklyTimetableState();
}

class _WeeklyTimetableState extends State<WeeklyTimetable> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final days = widget.snapshot.days
        .where(
          (day) =>
              day.date.weekday <= 5 ||
              widget.showEmptyWeekends ||
              widget.snapshot.itemsFor(day).isNotEmpty,
        )
        .toList();
    final entries = [
      for (final day in days)
        for (final item in widget.snapshot.itemsFor(day))
          _TimedEntry(day.dateKey, item),
    ];
    final bands = _timeBands(entries);
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(12) / 12,
    );
    final timeWidth = 40.0 * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final pixelsPerMinute = (compact ? .94 : .86) * scale;
        return Column(
          children: [
            SizedBox(
              height: 52 * scale,
              child: Row(
                children: [
                  SizedBox(width: timeWidth),
                  for (final day in days)
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            compact
                                ? day.weekdayLabel.substring(1)
                                : day.weekdayLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: day.isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : c.text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            compact ? '${day.date.day}' : day.shortDateLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: day.isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : c.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text('本周没有课', style: TextStyle(color: c.tertiary)),
                    )
                  : Scrollbar(
                      controller: _scroll,
                      child: SingleChildScrollView(
                        controller: _scroll,
                        child: Column(
                          children: [
                            for (final band in bands) ...[
                              SizedBox(
                                height:
                                    (band.end - band.start) * pixelsPerMinute +
                                    8,
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: timeWidth,
                                      child: Stack(
                                        children: [
                                          for (final start
                                              in band.entries
                                                  .map((entry) => entry.start)
                                                  .toSet())
                                            Positioned(
                                              top:
                                                  (start - band.start) *
                                                      pixelsPerMinute +
                                                  5,
                                              left: 0,
                                              right: 0,
                                              child: Text(
                                                _clock(start),
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: c.tertiary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    for (final day in days)
                                      Expanded(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: c.border.withAlpha(100),
                                                width: .5,
                                              ),
                                            ),
                                          ),
                                          child: LayoutBuilder(
                                            builder: (context, cell) {
                                              final dayEntries = band.entries
                                                  .where(
                                                    (entry) =>
                                                        entry.day ==
                                                        day.dateKey,
                                                  )
                                                  .toList();
                                              final lanes =
                                                  <List<_TimedEntry>>[];
                                              for (final entry in dayEntries) {
                                                final lane = lanes.indexWhere(
                                                  (lane) =>
                                                      lane.last.end <=
                                                      entry.start,
                                                );
                                                if (lane < 0) {
                                                  lanes.add([entry]);
                                                } else {
                                                  lanes[lane].add(entry);
                                                }
                                              }
                                              final width =
                                                  cell.maxWidth /
                                                  math.max(1, lanes.length);
                                              return Stack(
                                                children: [
                                                  for (
                                                    var lane = 0;
                                                    lane < lanes.length;
                                                    lane++
                                                  )
                                                    for (final entry
                                                        in lanes[lane])
                                                      Positioned(
                                                        top:
                                                            (entry.start -
                                                                    band.start) *
                                                                pixelsPerMinute +
                                                            4,
                                                        left: lane * width + 2,
                                                        width: math.max(
                                                          0,
                                                          width - 4,
                                                        ),
                                                        height: math.max(
                                                          16,
                                                          (entry.end -
                                                                      entry
                                                                          .start) *
                                                                  pixelsPerMinute -
                                                              2,
                                                        ),
                                                        child: _TimetableEvent(
                                                          item: entry.item,
                                                          compact: compact,
                                                          onTap: () =>
                                                              widget.onOpenItem(
                                                                entry.item,
                                                              ),
                                                        ),
                                                      ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Divider(height: 16, thickness: .5),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

int? _minutes(String value) {
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

String _clock(int minutes) => minutes >= 24 * 60
    ? '待定'
    : '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class _TimedEntry {
  _TimedEntry(this.day, this.item);
  final String day;
  final TodayScheduleItem item;
  int get start => _minutes(item.startTime) ?? 24 * 60;
  int get end {
    final known = _minutes(item.endTime);
    return known != null && known > start ? known : start + 95;
  }
}

class _TimeBand {
  _TimeBand(this.start, this.end, this.entries);
  final int start;
  int end;
  final List<_TimedEntry> entries;
}

List<_TimeBand> _timeBands(List<_TimedEntry> entries) {
  final sorted = [...entries]..sort((a, b) => a.start.compareTo(b.start));
  final bands = <_TimeBand>[];
  for (final entry in sorted) {
    if (bands.isEmpty || entry.start > bands.last.end + 20) {
      bands.add(_TimeBand(entry.start, entry.end, [entry]));
    } else {
      bands.last.entries.add(entry);
      bands.last.end = math.max(bands.last.end, entry.end);
    }
  }
  return bands;
}

class _TimetableEvent extends StatelessWidget {
  const _TimetableEvent({
    required this.item,
    required this.compact,
    required this.onTap,
  });
  final TodayScheduleItem item;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final colors = StudyPalette.of(
      context,
      StudyPalette.course(context, item.courseId ?? item.courseName),
    );
    final color = colors.accent;
    final foreground = colors.accent;
    final label = '${item.courseName}\n${item.timeLabel}\n${item.location}';
    return Semantics(
      label: label,
      button: true,
      child: Tooltip(
        message: label,
        child: ClipPath(
          clipper: item.endTimeInferred ? const _UncertainEndClipper() : null,
          child: Material(
            color: Color.alphaBlend(
              color.withAlpha(dark ? 54 : 25),
              context.colors.surface,
            ),
            borderRadius: BorderRadius.circular(6),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: LayoutBuilder(
                builder: (context, size) {
                  final short =
                      size.maxHeight <
                      70 * MediaQuery.textScalerOf(context).scale(1);
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 4 : 10,
                      6,
                      compact ? 4 : 10,
                      item.endTimeInferred ? 10 : 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              item.courseName,
                              maxLines: short
                                  ? 2
                                  : compact
                                  ? 3
                                  : 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 11 : 13,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                                color: foreground,
                              ),
                            ),
                          ),
                        ),
                        if (!short) ...[
                          if (!compact)
                            Text(
                              item.timeLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                height: 1.3,
                                color: foreground,
                              ),
                            ),
                          Text(
                            item.location.isEmpty ? '地点待定' : item.location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              height: 1.3,
                              color: foreground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UncertainEndClipper extends CustomClipper<Path> {
  const _UncertainEndClipper();
  @override
  Path getClip(Size size) {
    final teeth = math.max(2, (size.width / 9).round());
    final step = size.width / teeth;
    final path = Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 4);
    for (var i = teeth; i > 0; i--) {
      path
        ..lineTo((i - .5) * step, size.height)
        ..lineTo((i - 1) * step, size.height - 4);
    }
    return path..close();
  }

  @override
  bool shouldReclip(_UncertainEndClipper oldClipper) => false;
}
