import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../providers/home_schedule_provider.dart';
import '../../auth/widgets/campus_authorization_screen.dart';
import 'schedule_status.dart';
import 'weekly_timetable.dart';

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
  late DateTime _week = scheduleWeekStart(widget.initialDate);
  late final _pages = PageController(initialPage: _pageFor(_week));
  bool _showWeekends = false;
  int _pageFor(DateTime date) =>
      scheduleWeekStart(date).difference(_firstWeek).inDays ~/ 7;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(DateTime date) {
    final week = scheduleWeekStart(date);
    if (week.isBefore(_firstWeek) || week.isAfter(_lastWeek)) return;
    _pages.jumpToPage(_pageFor(week));
    setState(() => _week = week);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _week,
      currentDate: ref.read(homeScheduleTodayProvider),
      firstDate: _firstWeek,
      lastDate: DateTime(2100, 12, 31),
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
              _go(_week.add(Duration(days: intent.delta * 7)));
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
                        child: Text(
                          '课表',
                          style: Theme.of(context).textTheme.titleMedium,
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
                            ? () => _go(_week.subtract(const Duration(days: 7)))
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
                            ? () => _go(_week.add(const Duration(days: 7)))
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: _pageFor(_lastWeek) + 1,
                    onPageChanged: (page) => setState(
                      () => _week = _firstWeek.add(Duration(days: page * 7)),
                    ),
                    itemBuilder: (_, page) => _ScheduleWeekPage(
                      week: _firstWeek.add(Duration(days: page * 7)),
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
  });
  final DateTime week;
  final bool showWeekends;
  final ValueChanged<TodayScheduleItem> onOpenItem;
  final ValueChanged<String> onOpenCourse;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(scheduleWeekProvider(week));
    final state = async.valueOrNull;
    final snapshot =
        state?.snapshot ?? emptyScheduleSnapshot(buildHomeScheduleDays(week));
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
