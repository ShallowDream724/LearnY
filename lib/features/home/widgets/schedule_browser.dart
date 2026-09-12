import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_materials.dart';
import '../../../core/design/responsive.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/app_surfaces.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import 'schedule_status.dart';
import 'schedule_pager.dart';

/// The home keeps a daily pager. Weekly browsing is a separate full-screen task.
class ScheduleBrowser extends StatefulWidget {
  const ScheduleBrowser({
    super.key,
    required this.days,
    required this.today,
    required this.selectedDate,
    required this.onDateSelected,
    required this.snapshot,
    required this.onOpenCourse,
    required this.onOpenWeek,
    this.isLoading = false,
    this.hasCalendarData = true,
    this.failure,
    this.firstDate,
    this.lastDate,
    this.onBoundary,
  });

  final List<HomeScheduleDayOption> days;
  final DateTime today;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final HomeScheduleSnapshot snapshot;
  final ValueChanged<String> onOpenCourse;
  final VoidCallback onOpenWeek;
  final bool isLoading;
  final bool hasCalendarData;
  final ScheduleFailure? failure;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final ValueChanged<int>? onBoundary;

  @override
  State<ScheduleBrowser> createState() => _ScheduleBrowserState();
}

class _ScheduleBrowserState extends State<ScheduleBrowser> {
  static final _firstDay = DateTime(1970, 1, 5);
  static final _lastDay = DateTime(2100, 12, 31);
  final _focus = FocusNode(debugLabel: 'daily-schedule');
  int get _index => widget.days
      .indexWhere((day) => DateUtils.isSameDay(day.date, widget.selectedDate))
      .clamp(0, widget.days.length - 1);

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _move(int delta) {
    _focus.requestFocus();
    final date = widget.selectedDate.add(Duration(days: delta));
    if (date.isBefore(widget.firstDate ?? _firstDay) ||
        date.isAfter(widget.lastDate ?? _lastDay)) {
      widget.onBoundary?.call(delta);
      return;
    }
    if (!date.isBefore(_firstDay) && !date.isAfter(_lastDay)) {
      widget.onDateSelected(date);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      currentDate: widget.today,
      firstDate: widget.firstDate ?? _firstDay,
      lastDate: widget.lastDate ?? _lastDay,
    );
    if (date != null && mounted) widget.onDateSelected(date);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final day = widget.days[_index];
    final items = widget.snapshot.itemsFor(day);
    final scale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(12) / 12,
    );
    final dateLabel = day.date.year == widget.today.year
        ? day.shortDateLabel
        : '${day.date.year}/${day.shortDateLabel}';
    final desktopControls = usesDesktopControls(context);
    return Focus(
      focusNode: _focus,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          _move(-1);
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          _move(1);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: StudySurface(
        tone: StudyTone.ink,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              runSpacing: 2,
              children: [
                Tooltip(
                  message: '选择日期',
                  child: TextButton(
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 4,
                      ),
                    ),
                    onPressed: _pickDate,
                    child: Text(
                      '${day.weekdayLabel} · $dateLabel',
                      style: AppTypography.headlineSmall.copyWith(
                        color: c.text,
                      ),
                    ),
                  ),
                ),
                if (!day.isToday)
                  Tooltip(
                    message: '回到今天',
                    child: TextButton(
                      onPressed: () => widget.onDateSelected(widget.today),
                      child: const Text('回到今天'),
                    ),
                  ),
                Tooltip(
                  message: '查看整周课表',
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: widget.onOpenWeek,
                    child: const Text('周课表'),
                  ),
                ),
                if (desktopControls)
                  IconButton(
                    tooltip: '前一天',
                    onPressed: () => _move(-1),
                    icon: const Icon(Icons.chevron_left, size: 18),
                  ),
                if (desktopControls)
                  IconButton(
                    tooltip: '后一天',
                    onPressed: () => _move(1),
                    icon: const Icon(Icons.chevron_right, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    items.length == 1 ||
                        constraints.maxWidth < 280 ||
                        scale > 1.4
                    ? 1
                    : constraints.maxWidth >= 840 && items.length != 4
                    ? 3
                    : 2;
                final tileHeight = 76.0 * scale;
                final rows = (items.length / columns).ceil();
                final contentHeight = items.isEmpty
                    ? (widget.failure != null ? 58.0 : 38.0) * scale
                    : rows * tileHeight + math.max(0, rows - 1) * 6 + 8;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AnimatedSize(
                      duration: AppMotion.duration(
                        context,
                        const Duration(milliseconds: 180),
                      ),
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: contentHeight,
                        child: SchedulePager(
                          date: widget.selectedDate,
                          firstDate: widget.firstDate ?? _firstDay,
                          lastDate: widget.lastDate ?? _lastDay,
                          stepDays: 1,
                          onDateChanged: widget.onDateSelected,
                          onBoundary: widget.onBoundary,
                          itemBuilder: (context, pageDate) {
                            final date = buildHomeScheduleDays(
                              pageDate,
                              length: 1,
                              today: widget.today,
                            ).single;
                            final entries = widget.snapshot.itemsFor(date);
                            if (entries.isEmpty) {
                              final text =
                                  widget.failure != null &&
                                      !widget.snapshot.hasRoutineData
                                  ? scheduleFailureLabel(widget.failure!)
                                  : widget.isLoading && !widget.hasCalendarData
                                  ? '正在加载课表'
                                  : !widget.hasCalendarData
                                  ? '暂无课表缓存'
                                  : date.isToday
                                  ? '今天没有课'
                                  : '${date.shortDateLabel} 没有课';
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        text,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: c.subtitle,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return GridView.builder(
                              primary: false,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: entries.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: entries.length == 1
                                        ? 1
                                        : columns,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 6,
                                    mainAxisExtent: tileHeight,
                                  ),
                              itemBuilder: (_, i) => _DailyCourseTile(
                                item: entries[i],
                                onOpen: widget.onOpenCourse,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    ScheduleNotes(
                      snapshot: widget.snapshot,
                      onOpenCourse: widget.onOpenCourse,
                    ),
                    if (widget.failure != null &&
                        items.isNotEmpty &&
                        !widget.snapshot.hasRoutineData)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                scheduleFailureLabel(widget.failure!),
                                style: AppTypography.bodySmall.copyWith(
                                  color: c.subtitle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyCourseTile extends StatelessWidget {
  const _DailyCourseTile({required this.item, required this.onOpen});
  final TodayScheduleItem item;
  final ValueChanged<String> onOpen;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canOpen = item.courseId?.isNotEmpty ?? false;
    final time = Text(
      item.startTime.isEmpty ? '待定' : item.startTime,
      style: AppTypography.bodySmall.copyWith(
        fontSize: 12,
        height: 1.2,
        color: StudyPalette.of(
          context,
          StudyPalette.course(context, item.courseId ?? item.courseName),
        ).accent,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final title = Text(
      item.courseName,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.titleMedium.copyWith(
        fontSize: 14,
        height: 1.3,
        color: c.text,
      ),
    );
    final location = Text(
      item.location.isEmpty ? '地点待定' : item.location,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.bodySmall.copyWith(
        fontSize: 12,
        height: 1.2,
        color: c.subtitle,
      ),
    );
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 480) {
            return Row(
              children: [
                SizedBox(width: 84, child: time),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [title, const SizedBox(height: 5), location],
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              time,
              const SizedBox(height: 4),
              title,
              const SizedBox(height: 3),
              location,
            ],
          );
        },
      ),
    );
    void open() => canOpen
        ? onOpen(item.courseId!)
        : showScheduleItemDetails(context, item);
    return Tooltip(
      message: '${item.courseName}\n${item.timeLabel}\n${item.location}',
      child: StudySurface(
        radius: 12,
        tone: StudyPalette.course(context, item.courseId ?? item.courseName),
        onTap: open,
        child: content,
      ),
    );
  }
}
