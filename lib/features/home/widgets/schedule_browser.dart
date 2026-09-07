import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_theme_colors.dart';
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
    required this.onRetry,
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
  final VoidCallback onRetry;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.isToday ? '今日课程' : '课程安排',
                  style: AppTypography.headlineSmall.copyWith(color: c.text),
                ),
              ),
              if (!day.isToday)
                IconButton(
                  tooltip: '回到今天',
                  onPressed: () => widget.onDateSelected(widget.today),
                  icon: const Icon(Icons.today_outlined, size: 19),
                ),
              IconButton(
                tooltip: '刷新课表',
                onPressed: widget.isLoading ? null : widget.onRetry,
                icon: widget.isLoading
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh, size: 19),
              ),
              IconButton(
                tooltip: '查看整周课表',
                onPressed: widget.onOpenWeek,
                icon: const Icon(Icons.calendar_view_week_outlined, size: 20),
              ),
            ],
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  items.length == 1 || constraints.maxWidth < 280 || scale > 1.4
                  ? 1
                  : constraints.maxWidth >= 840
                  ? 3
                  : 2;
              final tileHeight = 76.0 * scale;
              final rows = (items.length / columns).ceil();
              final contentHeight = items.isEmpty
                  ? (widget.failure != null ? 58.0 : 38.0) * scale
                  : rows * tileHeight + math.max(0, rows - 1) * 6 + 8;
              return Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: '前一天',
                        onPressed: () => _move(-1),
                        icon: const Icon(Icons.chevron_left, size: 18),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _pickDate,
                          child: Text(
                            '${day.isToday ? '今天 · ' : ''}${day.weekdayLabel} · ${day.shortDateLabel}',
                            style: AppTypography.labelMedium.copyWith(
                              color: c.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '后一天',
                        onPressed: () => _move(1),
                        icon: const Icon(Icons.chevron_right, size: 18),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
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
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                              child: Row(
                                children: [
                                  Icon(
                                    widget.failure == null
                                        ? Icons.event_available_outlined
                                        : Icons.cloud_off_outlined,
                                    size: 17,
                                    color: c.tertiary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      text,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: c.subtitle,
                                      ),
                                    ),
                                  ),
                                  if (widget.failure != null)
                                    IconButton(
                                      tooltip: '重试课表',
                                      onPressed: widget.onRetry,
                                      icon: const Icon(Icons.refresh, size: 18),
                                    ),
                                ],
                              ),
                            );
                          }
                          return GridView.builder(
                            primary: false,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                          IconButton(
                            tooltip: '重试课表',
                            onPressed: widget.onRetry,
                            icon: const Icon(Icons.refresh, size: 18),
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
    return Tooltip(
      message: '${item.courseName}\n${item.timeLabel}\n${item.location}',
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: canOpen
              ? () => onOpen(item.courseId!)
              : () => showScheduleItemDetails(context, item),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.startTime.isEmpty ? '待定' : item.startTime,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    if (canOpen)
                      Icon(Icons.chevron_right, size: 14, color: c.tertiary),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.location.isEmpty ? '地点待定' : item.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.1,
                    color: c.tertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
