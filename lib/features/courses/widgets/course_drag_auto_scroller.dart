import 'package:flutter/widgets.dart';

Rect expandCourseDragRectForViewportObstruction(
  Rect dragRect, {
  EdgeInsets viewportObstruction = EdgeInsets.zero,
}) {
  return Rect.fromLTRB(
    dragRect.left - viewportObstruction.left,
    dragRect.top - viewportObstruction.top,
    dragRect.right + viewportObstruction.right,
    dragRect.bottom + viewportObstruction.bottom,
  );
}

class CourseDragAutoScroller {
  CourseDragAutoScroller({
    required ScrollController scrollController,
    this.velocityScalar = 38,
  }) : _scrollController = scrollController;

  final ScrollController _scrollController;
  final double velocityScalar;

  ScrollableState? _scrollable;
  EdgeInsets _viewportObstruction = EdgeInsets.zero;
  EdgeDraggingAutoScroller? _delegate;

  void attach(
    ScrollableState scrollable, {
    EdgeInsets viewportObstruction = EdgeInsets.zero,
  }) {
    final needsRebind =
        _scrollable != scrollable || _viewportObstruction != viewportObstruction;
    _scrollable = scrollable;
    _viewportObstruction = viewportObstruction;
    if (!needsRebind) {
      return;
    }
    _delegate = EdgeDraggingAutoScroller(
      scrollable,
      velocityScalar: velocityScalar,
      onScrollViewScrolled: () {
        if (!_scrollController.hasClients) {
          _delegate?.stopAutoScroll();
        }
      },
    );
  }

  void updateDragRect(Rect dragRect) {
    if (!_scrollController.hasClients) {
      return;
    }
    final adjustedRect = expandCourseDragRectForViewportObstruction(
      dragRect,
      viewportObstruction: _viewportObstruction,
    );
    _delegate?.startAutoScrollIfNecessary(
      adjustedRect,
    );
  }

  void stop() {
    _delegate?.stopAutoScroll();
  }

  void dispose() {
    stop();
    _scrollable = null;
    _delegate = null;
  }
}
