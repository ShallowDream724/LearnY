import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/router/router.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../providers/home_schedule_provider.dart';

bool shouldShowHomeTodayScheduleSection(AuthState auth) =>
    auth.canAccessCachedData;

class HomeTodayScheduleSection extends ConsumerWidget {
  const HomeTodayScheduleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shouldShowHomeTodayScheduleSection(ref.watch(authProvider))) {
      return const SizedBox.shrink();
    }
    final semesterId = ref.watch(currentSemesterIdProvider);
    final days = ref.watch(homeScheduleVisibleDaysProvider);
    final asyncState = ref.watch(homeScheduleProvider).unwrapPrevious();
    final state = asyncState.valueOrNull;
    final current =
        state?.semesterId == semesterId &&
            state?.snapshot.days.first.dateKey == days.first.dateKey
        ? state
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ScheduleBrowser(
        key: ValueKey('$semesterId/${days.first.dateKey}'),
        days: days,
        snapshot: current?.snapshot ?? emptyScheduleSnapshot(days),
        isLoading: asyncState.isLoading,
        isRefreshing: current?.isRefreshing ?? false,
        isHistorical: current?.isHistorical ?? false,
        failure:
            current?.failure ??
            (asyncState.hasError ? ScheduleFailure.storage : null),
        onRetry: () async {
          final refreshed = await ref
              .read(homeScheduleActionsProvider)
              .refresh();
          if (!refreshed && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('课表刷新失败，请稍后重试')));
          }
        },
        onOpenCourse: (id) => context.push(Routes.courseDetail(id)),
      ),
    );
  }
}

/// A date navigator shared by mouse, keyboard and touch input.
class ScheduleBrowser extends StatefulWidget {
  const ScheduleBrowser({
    super.key,
    required this.days,
    required this.snapshot,
    required this.onOpenCourse,
    required this.onRetry,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isHistorical = false,
    this.failure,
  }) : assert(days.length > 0);

  final List<HomeScheduleDayOption> days;
  final HomeScheduleSnapshot snapshot;
  final ValueChanged<String> onOpenCourse;
  final VoidCallback onRetry;
  final bool isLoading;
  final bool isRefreshing;
  final bool isHistorical;
  final ScheduleFailure? failure;

  @override
  State<ScheduleBrowser> createState() => _ScheduleBrowserState();
}

class _ScheduleBrowserState extends State<ScheduleBrowser>
    with TickerProviderStateMixin {
  late TabController _tabs;
  final _navigationFocus = FocusNode(debugLabel: 'schedule-dates');

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: widget.days.length, vsync: this)
      ..addListener(_onTabChanged);
  }

  @override
  void didUpdateWidget(covariant ScheduleBrowser oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days.length != widget.days.length) {
      _tabs.dispose();
      _tabs = TabController(length: widget.days.length, vsync: this)
        ..addListener(_onTabChanged);
    } else if (oldWidget.days.first.dateKey != widget.days.first.dateKey) {
      _tabs.index = 0;
    }
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _navigationFocus.dispose();
    super.dispose();
  }

  void _select(int index) {
    if (index < 0 || index >= _tabs.length) return;
    _navigationFocus.requestFocus();
    _tabs.animateTo(index, duration: const Duration(milliseconds: 180));
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _select(_tabs.index - 1);
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _select(_tabs.index + 1);
    } else if (key == LogicalKeyboardKey.home) {
      _select(0);
    } else if (key == LogicalKeyboardKey.end) {
      _select(_tabs.length - 1);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final busy = widget.isLoading || widget.isRefreshing;
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100
            ? 3
            : constraints.maxWidth >= 600
            ? 2
            : 1;
        final rowHeight = 112.0 * math.max(1.0, scale);
        final mostItems = widget.days
            .map((day) => widget.snapshot.itemsFor(day).length)
            .reduce(math.max);
        final rows = math.max(1, (mostItems / columns).ceil());
        final viewportHeight = math.min(
          rows * (rowHeight + 8),
          math.max(rowHeight, MediaQuery.sizeOf(context).height * 0.5),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '课程安排',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.failure != null)
                  Tooltip(
                    message: _failureMessage(widget.failure!),
                    child: Icon(
                      Icons.error_outline,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                  ),
                IconButton(
                  tooltip: '刷新课表',
                  onPressed: busy ? null : widget.onRetry,
                  icon: busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 20),
                ),
              ],
            ),
            Focus(
              focusNode: _navigationFocus,
              debugLabel: 'schedule-date-navigation',
              onKeyEvent: _onKey,
              child: Row(
                children: [
                  IconButton(
                    tooltip: '前一天',
                    onPressed: _tabs.index > 0
                        ? () => _select(_tabs.index - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: TabBar(
                      controller: _tabs,
                      onTap: (_) => _navigationFocus.requestFocus(),
                      isScrollable:
                          constraints.maxWidth < 540 * math.min(scale, 2),
                      tabAlignment:
                          constraints.maxWidth < 540 * math.min(scale, 2)
                          ? TabAlignment.start
                          : TabAlignment.fill,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerHeight: 0,
                      tabs: [
                        for (final day in widget.days)
                          Tab(
                            height: 52 * math.max(1.0, scale),
                            child: Tooltip(
                              message:
                                  '${day.label} ${day.weekdayLabel} ${day.shortDateLabel}',
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    day.label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    day.shortDateLabel,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '后一天',
                    onPressed: _tabs.index < _tabs.length - 1
                        ? () => _select(_tabs.index + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 10),
            SizedBox(
              height: viewportHeight,
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final day in widget.days)
                    _ScheduleDayView(
                      key: ValueKey(day.dateKey),
                      day: day,
                      items: widget.snapshot.itemsFor(day),
                      columns: columns,
                      rowHeight: rowHeight,
                      isLoading: busy,
                      isHistorical: widget.isHistorical,
                      failure: widget.failure,
                      onOpenCourse: widget.onOpenCourse,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

String _failureMessage(ScheduleFailure failure) => switch (failure) {
  ScheduleFailure.timeout => '课表更新超时，请重试',
  ScheduleFailure.sessionExpired => '会话已过期，请重新登录',
  ScheduleFailure.network => '课表暂时无法更新，请检查网络后重试',
  ScheduleFailure.storage => '课表缓存读取失败，请重试',
};

class _ScheduleDayView extends StatelessWidget {
  const _ScheduleDayView({
    super.key,
    required this.day,
    required this.items,
    required this.columns,
    required this.rowHeight,
    required this.isLoading,
    required this.isHistorical,
    required this.failure,
    required this.onOpenCourse,
  });

  final HomeScheduleDayOption day;
  final List<TodayScheduleItem> items;
  final int columns;
  final double rowHeight;
  final bool isLoading;
  final bool isHistorical;
  final ScheduleFailure? failure;
  final ValueChanged<String> onOpenCourse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      final message = isLoading
          ? '正在获取课程安排'
          : failure != null
          ? _failureMessage(failure!)
          : isHistorical
          ? '所选学期暂无近期课程'
          : buildHomeScheduleEmptyLabel(day);
      return Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                failure != null
                    ? Icons.cloud_off_outlined
                    : Icons.event_available_outlined,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      primary: false,
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: rowHeight,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final courseId = item.courseId;
        return Material(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: courseId == null || courseId.isEmpty
                ? null
                : () => onOpenCourse(courseId),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item.timeLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    item.courseName.isEmpty ? '课程待定' : item.courseName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  Text(
                    item.location.isEmpty ? '地点待定' : item.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
