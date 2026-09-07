import 'package:flutter/material.dart';

/// Bounded pages stop at the semester edge. Only a deliberate outward drag
/// requests a semester change; programmatic jumps never trigger that request.
class SchedulePager extends StatelessWidget {
  const SchedulePager({
    super.key,
    required this.date,
    required this.firstDate,
    required this.lastDate,
    required this.stepDays,
    required this.onDateChanged,
    required this.itemBuilder,
    this.onBoundary,
  });
  final DateTime date;
  final DateTime firstDate;
  final DateTime lastDate;
  final int stepDays;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int>? onBoundary;
  final Widget Function(BuildContext, DateTime) itemBuilder;

  @override
  Widget build(BuildContext context) => _SchedulePager(
    key: ValueKey((firstDate, lastDate, stepDays)),
    configuration: this,
  );
}

class _SchedulePager extends StatefulWidget {
  const _SchedulePager({super.key, required this.configuration});
  final SchedulePager configuration;
  @override
  State<_SchedulePager> createState() => _SchedulePagerState();
}

class _SchedulePagerState extends State<_SchedulePager> {
  SchedulePager get config => widget.configuration;
  int _pageFor(DateTime date) =>
      date.difference(config.firstDate).inDays ~/ config.stepDays;
  int get _lastPage => _pageFor(config.lastDate);
  late final _controller = PageController(
    initialPage: _pageFor(config.date).clamp(0, _lastPage),
  );
  bool _dragging = false;
  bool _boundaryHandled = false;
  double _overscroll = 0;

  @override
  void didUpdateWidget(covariant _SchedulePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _pageFor(config.date).clamp(0, _lastPage);
    if (_controller.hasClients && _controller.page?.round() != page) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(_pageFor(config.date).clamp(0, _lastPage));
        }
      });
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal || notification.depth != 0) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragging = true;
      _boundaryHandled = false;
      _overscroll = 0;
    }
    if (notification is OverscrollNotification &&
        _dragging &&
        !_boundaryHandled) {
      _overscroll += notification.overscroll;
      if (_overscroll.abs() >= 20) {
        _boundaryHandled = true;
        final direction = _overscroll > 0 ? 1 : -1;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) config.onBoundary?.call(direction);
        });
      }
    }
    if (notification is ScrollEndNotification) _dragging = false;
    return false;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: PageView.builder(
          controller: _controller,
          physics: const PageScrollPhysics(parent: ClampingScrollPhysics()),
          itemCount: _lastPage + 1,
          onPageChanged: (page) {
            final date = config.firstDate.add(
              Duration(days: page * config.stepDays),
            );
            if (!DateUtils.isSameDay(date, config.date)) {
              config.onDateChanged(date);
            }
          },
          itemBuilder: (context, page) => config.itemBuilder(
            context,
            config.firstDate.add(Duration(days: page * config.stepDays)),
          ),
        ),
      );
}
