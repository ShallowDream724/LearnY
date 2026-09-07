import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import 'schedule_course_entry.dart';

enum ScheduleView { day, week }

/// Navigation is local UI state; the selected date and data belong to the caller.
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
    this.isLoading = false,
    this.hasCalendarData = true,
    this.failure,
  });

  final List<HomeScheduleDayOption> days;
  final DateTime today;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final HomeScheduleSnapshot snapshot;
  final ValueChanged<String> onOpenCourse;
  final VoidCallback onRetry;
  final bool isLoading;
  final bool hasCalendarData;
  final ScheduleFailure? failure;

  @override
  State<ScheduleBrowser> createState() => _ScheduleBrowserState();
}

class _ScheduleBrowserState extends State<ScheduleBrowser> {
  final _focus = FocusNode(debugLabel: 'schedule-navigation');
  ScheduleView? _view;
  bool _showWeekend = false;
  bool _expandedDay = false;

  @override
  void didUpdateWidget(covariant ScheduleBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!DateUtils.isSameDay(oldWidget.selectedDate, widget.selectedDate)) {
      _expandedDay = false;
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _select(DateTime date) {
    _focus.requestFocus();
    widget.onDateSelected(DateUtils.dateOnly(date));
  }

  void _moveWeek(int direction) =>
      _select(widget.selectedDate.add(Duration(days: 7 * direction)));

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      currentDate: widget.today,
      firstDate: DateTime(1970),
      lastDate: DateTime(2100, 12, 31),
      helpText: '选择课表日期',
    );
    if (date != null && mounted) _select(date);
  }

  KeyEventResult _onKey(KeyEvent event, ScheduleView view) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      final step = view == ScheduleView.week ? 7 : 1;
      _select(
        widget.selectedDate.add(
          Duration(days: key == LogicalKeyboardKey.arrowLeft ? -step : step),
        ),
      );
    } else if (key == LogicalKeyboardKey.home) {
      _select(widget.today);
    } else if (key == LogicalKeyboardKey.end) {
      _select(widget.days.last.date);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String get _failureMessage => switch (widget.failure) {
    ScheduleFailure.timeout => '课表更新超时',
    ScheduleFailure.sessionExpired => '会话已过期，请重新登录',
    ScheduleFailure.network => '课表暂时无法更新',
    ScheduleFailure.storage => '课表缓存读取失败',
    null => '',
  };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final wide = constraints.maxWidth >= 820 * math.min(scale, 1.5);
      final view = _view ?? (wide ? ScheduleView.week : ScheduleView.day);
      final allEmpty = !hasScheduleItems(widget.snapshot);
      final activeDays = widget.snapshot.itemsByDateKey.values.where(
        (items) => items.isNotEmpty,
      );
      final sparse =
          activeDays.length <= 2 &&
          activeDays.fold<int>(0, (sum, items) => sum + items.length) <= 3;
      final controls = _modeControls(view, showWeekOptions: wide);
      final navigation = _weekNavigation();
      return Focus(
        focusNode: _focus,
        onKeyEvent: (_, event) => _onKey(event, view),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (wide)
              Row(
                children: [
                  Text('课表', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 20),
                  navigation,
                  const Spacer(),
                  controls,
                ],
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '课表',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  controls,
                ],
              ),
              Align(alignment: Alignment.centerLeft, child: navigation),
            ],
            if (widget.failure != null && !allEmpty)
              _status('$_failureMessage，显示已保存课程', error: true),
            if (view == ScheduleView.day) ...[
              _dayStrip(),
              _dayAgenda(wide: constraints.maxWidth >= 640),
            ] else if (allEmpty)
              _emptyMessage(week: true)
            else if (wide)
              !_showWeekend && sparse ? _sparseWeekAgenda() : _weekColumns()
            else
              _weekList(),
          ],
        ),
      );
    },
  );

  Widget _modeControls(ScheduleView view, {required bool showWeekOptions}) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<ScheduleView>(
            segments: const [
              ButtonSegment(value: ScheduleView.day, label: Text('日')),
              ButtonSegment(value: ScheduleView.week, label: Text('周')),
            ],
            selected: {view},
            showSelectedIcon: false,
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Theme.of(context).colorScheme.onSurface.withAlpha(24)
                    : null,
              ),
              foregroundColor: WidgetStatePropertyAll(
                Theme.of(context).colorScheme.onSurface,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              side: WidgetStatePropertyAll(
                BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(36, 32)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
            onSelectionChanged: (value) => setState(() => _view = value.single),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: widget.isLoading ? '正在更新课表' : '刷新课表',
            onPressed: widget.isLoading ? null : widget.onRetry,
            icon: widget.isLoading
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 19),
          ),
          if (view == ScheduleView.week && showWeekOptions)
            PopupMenuButton<bool>(
              tooltip: '课表显示选项',
              icon: const Icon(Icons.more_horiz, size: 19),
              onSelected: (value) => setState(() => _showWeekend = value),
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: !_showWeekend,
                  checked: _showWeekend,
                  child: const Text('始终显示周末'),
                ),
              ],
            ),
        ],
      );

  Widget _weekNavigation() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      IconButton(
        tooltip: '上一周',
        onPressed: () => _moveWeek(-1),
        icon: const Icon(Icons.chevron_left, size: 20),
      ),
      Flexible(
        child: TextButton(
          onPressed: _pickDate,
          child: Text(
            '${DateFormat(widget.days.first.date.year == widget.today.year ? 'M/d' : 'yyyy/M/d').format(widget.days.first.date)} - ${DateFormat('M/d').format(widget.days.last.date)}',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
      IconButton(
        tooltip: '下一周',
        onPressed: () => _moveWeek(1),
        icon: const Icon(Icons.chevron_right, size: 20),
      ),
      IconButton(
        tooltip: '回到今天',
        onPressed: () => _select(widget.today),
        icon: const Icon(Icons.today_outlined, size: 18),
      ),
    ],
  );

  Widget _dayStrip() => Row(
    children: [
      for (final day in widget.days)
        Expanded(
          child: Semantics(
            selected: DateUtils.isSameDay(day.date, widget.selectedDate),
            child: TextButton(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 6),
                minimumSize: const Size(32, 40),
                backgroundColor:
                    DateUtils.isSameDay(day.date, widget.selectedDate)
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () => _select(day.date),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    day.isToday ? '今天' : day.weekdayLabel,
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text('${day.date.day}', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _dayAgenda({required bool wide}) {
    final day = widget.days.firstWhere(
      (day) => DateUtils.isSameDay(day.date, widget.selectedDate),
      orElse: () => widget.days.first,
    );
    final items = widget.snapshot.itemsFor(day);
    final visible = wide || _expandedDay ? items : items.take(3).toList();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > 80) {
          _select(
            widget.selectedDate.add(Duration(days: velocity < 0 ? 1 : -1)),
          );
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isEmpty)
            _emptyMessage(week: false)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = wide
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  children: [
                    for (final item in visible)
                      SizedBox(
                        width: width,
                        child: ScheduleCourseEntry(
                          item: item,
                          onOpen: widget.onOpenCourse,
                        ),
                      ),
                  ],
                );
              },
            ),
          if (visible.length < items.length)
            TextButton.icon(
              onPressed: () => setState(() => _expandedDay = true),
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text('还有 ${items.length - visible.length} 节课'),
            ),
        ],
      ),
    );
  }

  List<HomeScheduleDayOption> get _visibleWeekDays => widget.days
      .where(
        (day) =>
            _showWeekend ||
            widget.isLoading ||
            widget.failure != null ||
            !widget.hasCalendarData ||
            day.date.weekday <= 5 ||
            widget.snapshot.itemsFor(day).isNotEmpty,
      )
      .toList();

  void _openDay(HomeScheduleDayOption day) {
    setState(() => _view = ScheduleView.day);
    _select(day.date);
  }

  Widget _weekColumns() => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in _visibleWeekDays)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _openDay(day),
                    child: Text(
                      '${day.isToday ? '今天' : day.weekdayLabel} ${day.shortDateLabel}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  for (final item in widget.snapshot.itemsFor(day).take(3))
                    ScheduleCourseEntry(
                      item: item,
                      onOpen: widget.onOpenCourse,
                      stacked: true,
                    ),
                  if (widget.snapshot.itemsFor(day).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        '无课',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                  if (widget.snapshot.itemsFor(day).length > 3)
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => _openDay(day),
                      child: Text(
                        '+${widget.snapshot.itemsFor(day).length - 3} 节',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget _sparseWeekAgenda() => Column(
    children: [
      for (final day in widget.days)
        if (widget.snapshot.itemsFor(day).isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 112,
                child: TextButton(
                  onPressed: () => _openDay(day),
                  child: Text(
                    '${day.isToday ? '今天' : day.weekdayLabel} ${day.shortDateLabel}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    for (final item in widget.snapshot.itemsFor(day))
                      ScheduleCourseEntry(
                        item: item,
                        onOpen: widget.onOpenCourse,
                      ),
                  ],
                ),
              ),
            ],
          ),
    ],
  );

  Widget _weekList() => Column(
    children: [
      for (final day in _visibleWeekDays)
        if (widget.snapshot.itemsFor(day).isNotEmpty)
          InkWell(
            onTap: () => _openDay(day),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 62,
                    child: Text(
                      '${day.weekdayLabel}\n${day.shortDateLabel}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.snapshot
                          .itemsFor(day)
                          .map((item) => item.courseName)
                          .join('、'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.snapshot.itemsFor(day).length} 节',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const Icon(Icons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
    ],
  );

  Widget _emptyMessage({required bool week}) {
    final message = widget.isLoading && !widget.hasCalendarData
        ? '正在更新课表'
        : widget.failure != null
        ? _failureMessage
        : !widget.hasCalendarData
        ? '暂无这周的课表缓存'
        : week
        ? '本周没有课'
        : DateUtils.isSameDay(widget.selectedDate, widget.today)
        ? '今天没有课'
        : '${DateFormat('M月d日').format(widget.selectedDate)} 没有课';
    return _status(message, error: widget.failure != null);
  }

  Widget _status(String message, {bool error = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      children: [
        Icon(
          error ? Icons.cloud_off_outlined : Icons.event_available_outlined,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: Theme.of(context).textTheme.bodySmall),
        ),
        if (error && !widget.isLoading)
          TextButton(onPressed: widget.onRetry, child: const Text('重试')),
      ],
    ),
  );
}
