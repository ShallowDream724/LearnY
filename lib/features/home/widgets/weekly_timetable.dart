import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/design/app_materials.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/timetable_layout.dart';

/// Phone and desktop share the same minute axis, lunch fold and overlap lanes.
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
    final layout = TimetableLayout.fromSnapshot(widget.snapshot);
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(12) / 12,
    );
    final timeWidth = 40.0 * scale;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final pixelsPerMinute = (compact ? .94 : .86) * scale;
        final axis = TimetableAxis(
          layout,
          pixelsPerMinute: pixelsPerMinute,
          breakExtent: 28 * scale,
        );
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
              child: Scrollbar(
                controller: _scroll,
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      SizedBox(
                        height: axis.height + 24,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: timeWidth,
                                  child: Stack(
                                    children: [
                                      for (final start in layout.ticks)
                                        Positioned(
                                          top: axis.offset(start) + 4,
                                          left: 0,
                                          right: 0,
                                          child: Text(
                                            TimetableLayout.clock(start),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: c.tertiary,
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        top: axis.height + 5,
                                        left: 0,
                                        right: 0,
                                        child: Text(
                                          TimetableLayout.clock(layout.end),
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
                                          final dayEntries = layout.entries
                                              .where(
                                                (entry) =>
                                                    entry.day == day.dateKey,
                                              )
                                              .toList();
                                          return Stack(
                                            children: [
                                              for (final tick in [
                                                ...layout.ticks,
                                                layout.end,
                                              ])
                                                Positioned(
                                                  top: axis.offset(tick) + 4,
                                                  left: 0,
                                                  right: 0,
                                                  child: Divider(
                                                    height: 1,
                                                    thickness: .5,
                                                    color: c.border.withAlpha(
                                                      90,
                                                    ),
                                                  ),
                                                ),
                                              for (final entry in dayEntries)
                                                Positioned(
                                                  top:
                                                      axis.offset(entry.start) +
                                                      4,
                                                  left:
                                                      entry.lane *
                                                          cell.maxWidth /
                                                          entry.laneCount +
                                                      2,
                                                  width: math.max(
                                                    0,
                                                    cell.maxWidth /
                                                            entry.laneCount -
                                                        4,
                                                  ),
                                                  height: math.max(
                                                    1,
                                                    axis.extent(
                                                          entry.start,
                                                          entry.end,
                                                        ) -
                                                        2,
                                                  ),
                                                  child: _TimetableEvent(
                                                    item: entry.item,
                                                    compact: compact,
                                                    onTap: () => widget
                                                        .onOpenItem(entry.item),
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
                            if (layout.lunchBreak case final rest?)
                              Positioned(
                                top: axis.offset(rest.start) + 4,
                                left: 0,
                                right: 0,
                                height: axis.breakExtent,
                                child: _LunchBreakBand(
                                  rest: rest,
                                  timeWidth: timeWidth,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (layout.entries.isEmpty && layout.untimed.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '本周没有课',
                            style: TextStyle(color: c.tertiary),
                          ),
                        ),
                      for (final entry in layout.untimed)
                        ListTile(
                          title: Text(entry.item.courseName),
                          subtitle: Text('${entry.day} · 时间待定'),
                          onTap: () => widget.onOpenItem(entry.item),
                        ),
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

class _LunchBreakBand extends StatelessWidget {
  const _LunchBreakBand({required this.rest, required this.timeWidth});
  final TimetableBreak rest;
  final double timeWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label:
          '午休，${TimetableLayout.clock(rest.start)} 至 ${TimetableLayout.clock(rest.end)}',
      child: ExcludeSemantics(
        child: ColoredBox(
          color: c.surface,
          child: Row(
            children: [
              SizedBox(
                width: timeWidth,
                child: Text(
                  TimetableLayout.clock(rest.start),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: c.tertiary),
                ),
              ),
              Expanded(
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        c.tertiary.withAlpha(3),
                        c.tertiary.withAlpha(14),
                        c.tertiary.withAlpha(3),
                      ],
                    ),
                  ),
                  child: Text(
                    '午休',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 3,
                      color: c.subtitle,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
                        if (!short)
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
