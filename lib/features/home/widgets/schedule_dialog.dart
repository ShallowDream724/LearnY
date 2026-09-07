import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../../../core/semester/academic_calendar.dart';
import '../../../core/semester/semester_models.dart';
import '../../../core/semester/semester_switcher.dart';
import '../providers/home_schedule_provider.dart';
import '../../auth/widgets/campus_authorization_screen.dart';
import 'schedule_status.dart';
import 'weekly_timetable.dart';
import 'schedule_pager.dart';
import 'schedule_semester_confirmation.dart';

Future<void> showScheduleDialog(
  BuildContext context, {
  required DateTime initialDate,
  required ValueChanged<String> onOpenCourse,
}) {
  final container = ProviderScope.containerOf(context);
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: ScheduleDialog(
        initialDate: initialDate,
        onOpenCourse: onOpenCourse,
      ),
    ),
  );
}

class ScheduleDialog extends ConsumerStatefulWidget {
  const ScheduleDialog({
    super.key,
    required this.initialDate,
    required this.onOpenCourse,
  });
  final DateTime initialDate;
  final ValueChanged<String> onOpenCourse;
  @override
  ConsumerState<ScheduleDialog> createState() => _ScheduleDialogState();
}

class _ScheduleDialogState extends ConsumerState<ScheduleDialog> {
  static final _firstWeek = DateTime(1970, 1, 5);
  static final _lastWeek = scheduleWeekStart(DateTime(2100, 12, 31));
  late DateTime _focusDate = widget.initialDate;
  DateTime get _week => scheduleWeekStart(_focusDate);
  String? _semesterId;
  bool _navigating = false;
  bool _showWeekends = false;

  AcademicTermDates? get _term {
    final navigation = ref.read(scheduleSemesterNavigationProvider);
    return navigation.datesFor(_semesterId) ?? navigation.termOn(_focusDate);
  }

  void _go(DateTime date) {
    final week = scheduleWeekStart(date);
    if (week.isBefore(_firstWeek) || week.isAfter(_lastWeek)) return;
    final term = ref.read(scheduleSemesterNavigationProvider).termOn(date);
    setState(() {
      _focusDate = date;
      _semesterId = term?.id;
    });
  }

  void _move(int direction) {
    if (_navigating) return;
    final date = _week.add(Duration(days: direction * 7));
    if (date.isBefore(_firstWeek) || date.isAfter(_lastWeek)) return;
    final term = _term;
    if (term != null &&
        (date.isBefore(scheduleWeekStart(DateTime.parse(term.start))) ||
            date.isAfter(scheduleWeekStart(DateTime.parse(term.end))))) {
      _crossBoundary(direction);
      return;
    }
    _goWithinTerm(date);
  }

  void _goWithinTerm(DateTime date) {
    final id = _term?.id;
    setState(() {
      _focusDate = date;
      _semesterId = id;
    });
  }

  Future<void> _crossBoundary(int direction) async {
    if (_navigating) return;
    _navigating = true;
    try {
      final navigation = ref.read(scheduleSemesterNavigationProvider);
      final term = _term;
      if (term == null) return;
      final adjacent = navigation.adjacent(term.id, direction);
      final next = navigation.datesFor(adjacent?.id);
      if (next == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              adjacent == null
                  ? '暂无相邻学期信息'
                  : '${semesterLabel(adjacent.id)}的起止日期待确认',
            ),
          ),
        );
        return;
      }
      final accepted = await confirmScheduleSemesterChange(
        context,
        semesterId: next.id,
        home: false,
        direction: direction,
      );
      if (accepted && mounted) {
        setState(() {
          _semesterId = next.id;
          _focusDate = navigation.boundaryDate(next, direction);
        });
      }
    } finally {
      _navigating = false;
    }
  }

  Future<void> _pickSemester() async {
    if (_navigating) return;
    _navigating = true;
    try {
      final id = await showSemesterPicker(
        context,
        selectedId: _term?.id,
        requireCalendarDates: true,
      );
      if (id == null || !mounted) return;
      final navigation = ref.read(scheduleSemesterNavigationProvider);
      final term = navigation.datesFor(id);
      if (term == null) return;
      setState(() {
        _semesterId = id;
        _focusDate = navigation.initialDate(
          term,
          ref.read(homeScheduleTodayProvider),
        );
      });
    } finally {
      _navigating = false;
    }
  }

  Future<void> _pickDate() async {
    final term = _term;
    final first = term == null ? _firstWeek : DateTime.parse(term.start);
    final last = term == null
        ? DateTime(2100, 12, 31)
        : DateTime.parse(term.end);
    final initial = _focusDate.isBefore(first)
        ? first
        : _focusDate.isAfter(last)
        ? last
        : _focusDate;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      currentDate: ref.read(homeScheduleTodayProvider),
      firstDate: first,
      lastDate: last,
    );
    if (date != null && mounted) _go(date);
  }

  Future<void> _openItem(TodayScheduleItem item) async {
    final open = await showScheduleItemDetails(context, item);
    if (open == true && mounted) {
      Navigator.pop(context);
      widget.onOpenCourse(item.courseId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(homeScheduleTodayProvider);
    ref.watch(scheduleSemesterNavigationProvider);
    final term = _term;
    final firstWeek = term == null
        ? _firstWeek
        : scheduleWeekStart(DateTime.parse(term.start));
    final lastWeek = term == null
        ? _lastWeek
        : scheduleWeekStart(DateTime.parse(term.end));
    final state = ref.watch(scheduleWeekProvider(_week));
    final loading =
        state.isLoading || (state.valueOrNull?.isRefreshing ?? false);
    final last = _week.add(const Duration(days: 6));
    final compact = MediaQuery.sizeOf(context).width < 600;
    final label =
        '${_week.year}年 ${_week.month}/${_week.day} - ${last.year == _week.year ? '' : '${last.year}/'}${last.month}/${last.day}';
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _ChangeWeekIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _ChangeWeekIntent(1),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.pop(context);
              return null;
            },
          ),
          _ChangeWeekIntent: CallbackAction<_ChangeWeekIntent>(
            onInvoke: (intent) {
              _move(intent.delta);
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: compact ? 10 : 32,
              vertical: compact ? 28 : 32,
            ),
            constraints: const BoxConstraints(maxWidth: 1440),
            backgroundColor: context.colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(compact ? 12 : 20, 6, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: '切换课表学期',
                          child: TextButton(
                            style: TextButton.styleFrom(
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.zero,
                            ),
                            onPressed: _pickSemester,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    compact
                                        ? semesterLabel(
                                            term?.id,
                                          ).replaceFirst(' ', '\n')
                                        : semesterLabel(term?.id),
                                    maxLines: compact ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.colors.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const Icon(Icons.expand_more, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '回到今天',
                        onPressed: () => _go(today),
                        icon: const Icon(Icons.today_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: '刷新本周课表',
                        onPressed: loading
                            ? null
                            : () => ref
                                  .read(scheduleWeekActionsProvider(_week))
                                  .refresh(),
                        icon: loading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.refresh, size: 20),
                      ),
                      PopupMenuButton<String>(
                        tooltip: '课表显示选项',
                        onSelected: (value) async {
                          if (value == 'weekends') {
                            setState(() => _showWeekends = !_showWeekends);
                          } else if (await showCampusAuthorization(
                                context,
                                _week,
                              ) &&
                              mounted) {
                            await ref
                                .read(scheduleWeekActionsProvider(_week))
                                .refresh();
                          }
                        },
                        itemBuilder: (_) => [
                          CheckedPopupMenuItem(
                            value: 'weekends',
                            checked: _showWeekends,
                            child: const Text('始终显示周末'),
                          ),
                          const PopupMenuItem(
                            value: 'authorize',
                            child: Text('校园访问授权'),
                          ),
                        ],
                        icon: const Icon(Icons.more_horiz, size: 20),
                      ),
                      IconButton(
                        tooltip: '关闭课表',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: '上一周',
                        onPressed: _week.isAfter(_firstWeek)
                            ? () => _move(-1)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: _pickDate,
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.colors.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '下一周',
                        onPressed: _week.isBefore(_lastWeek)
                            ? () => _move(1)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SchedulePager(
                    date: _week,
                    firstDate: firstWeek,
                    lastDate: lastWeek,
                    stepDays: 7,
                    onDateChanged: _goWithinTerm,
                    onBoundary: _crossBoundary,
                    itemBuilder: (_, week) => _ScheduleWeekPage(
                      week: week,
                      term: term,
                      showWeekends: _showWeekends,
                      onOpenItem: _openItem,
                      onOpenCourse: (id) {
                        Navigator.pop(context);
                        widget.onOpenCourse(id);
                      },
                    ),
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

class _ChangeWeekIntent extends Intent {
  const _ChangeWeekIntent(this.delta);
  final int delta;
}

class _ScheduleWeekPage extends ConsumerWidget {
  const _ScheduleWeekPage({
    required this.week,
    required this.showWeekends,
    required this.onOpenItem,
    required this.onOpenCourse,
    this.term,
  });
  final DateTime week;
  final bool showWeekends;
  final ValueChanged<TodayScheduleItem> onOpenItem;
  final ValueChanged<String> onOpenCourse;
  final AcademicTermDates? term;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scheduleWeekProvider(week));
    final state = async.valueOrNull;
    final rawSnapshot =
        state?.snapshot ?? emptyScheduleSnapshot(buildHomeScheduleDays(week));
    final snapshot = term == null
        ? rawSnapshot
        : HomeScheduleSnapshot(
            days: rawSnapshot.days,
            hasRoutineData: rawSnapshot.hasRoutineData,
            unscheduledCourses: rawSnapshot.unscheduledCourses
                .where(
                  (course) =>
                      course.semesterId == null ||
                      course.semesterId == term!.id,
                )
                .toList(),
            itemsByDateKey: {
              for (final day in rawSnapshot.days)
                day.dateKey: term!.contains(day.date)
                    ? rawSnapshot.itemsFor(day)
                    : const [],
            },
          );
    final failure =
        state?.failure ?? (async.hasError ? ScheduleFailure.storage : null);
    final loading = async.isLoading || (state?.isRefreshing ?? false);
    final hasItems = hasScheduleItems(snapshot);
    final usable = hasItems || snapshot.hasRoutineData;
    final message = failure != null && !usable
        ? scheduleFailureLabel(failure)
        : loading && !hasItems
        ? '正在加载课表'
        : !(state?.hasCalendarData ?? false) && !hasItems
        ? '暂无课表缓存'
        : null;
    return Column(
      children: [
        if (message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.colors.subtitle,
                    ),
                  ),
                ),
                if (failure != null)
                  IconButton(
                    tooltip: '重试课表',
                    onPressed: () =>
                        ref.read(scheduleWeekActionsProvider(week)).refresh(),
                    icon: const Icon(Icons.refresh, size: 18),
                  ),
              ],
            ),
          ),
        Expanded(
          child: message != null && !hasItems
              ? const SizedBox.expand()
              : WeeklyTimetable(
                  snapshot: snapshot,
                  showEmptyWeekends: showWeekends,
                  onOpenItem: onOpenItem,
                ),
        ),
        ScheduleNotes(snapshot: snapshot, onOpenCourse: onOpenCourse),
      ],
    );
  }
}
