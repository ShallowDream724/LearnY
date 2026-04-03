import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/features/courses/widgets/course_drag_auto_scroller.dart';

void main() {
  testWidgets(
    'auto scrolls the inner vertical list while dragging inside a nested PageView',
    (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: _NestedCourseDragHarness(scrollController: scrollController),
        ),
      );
      await tester.pumpAndSettle();

      final itemFinder = find.byKey(const ValueKey('drag-card-0'));
      expect(itemFinder, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(itemFinder));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 80));

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      await gesture.moveTo(Offset(screen.width / 2, screen.height - 24));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(scrollController.offset, greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'auto scroll still advances when drag targets reorder items during the drag',
    (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          home: _NestedReorderCourseDragHarness(
            scrollController: scrollController,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final itemFinder = find.byKey(const ValueKey('reorder-drag-card-0'));
      expect(itemFinder, findsOneWidget);

      final gesture = await tester.startGesture(tester.getCenter(itemFinder));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 80));

      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      await gesture.moveTo(Offset(screen.width / 2, screen.height - 24));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(scrollController.offset, greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}

class _NestedCourseDragHarness extends StatefulWidget {
  const _NestedCourseDragHarness({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_NestedCourseDragHarness> createState() =>
      _NestedCourseDragHarnessState();
}

class _NestedCourseDragHarnessState extends State<_NestedCourseDragHarness> {
  late final CourseDragAutoScroller _autoScroller;

  @override
  void initState() {
    super.initState();
    _autoScroller = CourseDragAutoScroller(
      scrollController: widget.scrollController,
    );
  }

  @override
  void dispose() {
    _autoScroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: PageController(initialPage: 1),
      children: [
        const SizedBox.expand(),
        Scaffold(
          body: CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              SliverList.builder(
                itemCount: 16,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Builder(
                      builder: (localContext) {
                        final scrollable = Scrollable.maybeOf(
                          localContext,
                          axis: Axis.vertical,
                        );
                        if (scrollable != null) {
                          _autoScroller.attach(scrollable);
                        }

                        return LongPressDraggable<int>(
                          data: index,
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          feedback: _DragCard(index: index),
                          onDragUpdate: (details) {
                            _autoScroller.updateDragRect(
                              Rect.fromLTWH(
                                details.globalPosition.dx,
                                details.globalPosition.dy,
                                220,
                                140,
                              ),
                            );
                          },
                          onDragEnd: (_) => _autoScroller.stop(),
                          onDragCompleted: _autoScroller.stop,
                          childWhenDragging: const SizedBox(height: 140),
                          child: _DragCard(index: index),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DragCard extends StatelessWidget {
  const _DragCard({required this.index, this.keyPrefix = 'drag-card'});

  final int index;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('$keyPrefix-$index'),
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text('Course $index'),
    );
  }
}

class _NestedReorderCourseDragHarness extends StatefulWidget {
  const _NestedReorderCourseDragHarness({required this.scrollController});

  final ScrollController scrollController;

  @override
  State<_NestedReorderCourseDragHarness> createState() =>
      _NestedReorderCourseDragHarnessState();
}

class _NestedReorderCourseDragHarnessState
    extends State<_NestedReorderCourseDragHarness> {
  late final CourseDragAutoScroller _autoScroller;
  final List<int> _items = List<int>.generate(16, (index) => index);
  int? _draggingItem;

  @override
  void initState() {
    super.initState();
    _autoScroller = CourseDragAutoScroller(
      scrollController: widget.scrollController,
    );
  }

  @override
  void dispose() {
    _autoScroller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: PageController(initialPage: 1),
      children: [
        const SizedBox.expand(),
        Scaffold(
          body: CustomScrollView(
            controller: widget.scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList.builder(
                  itemCount: (_items.length / 2).ceil(),
                  itemBuilder: (context, rowIndex) {
                    final start = rowIndex * 2;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          for (var column = 0; column < 2; column += 1) ...[
                            if (column > 0) const SizedBox(width: 10),
                            Expanded(
                              child: start + column < _items.length
                                  ? _buildReorderCell(
                                      context,
                                      _items[start + column],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReorderCell(BuildContext context, int item) {
    return Builder(
      builder: (localContext) {
        final scrollable = Scrollable.maybeOf(localContext, axis: Axis.vertical);
        if (scrollable != null) {
          _autoScroller.attach(scrollable);
        }

        return DragTarget<int>(
          onWillAcceptWithDetails: (details) => details.data != item,
          onMove: (details) {
            final dragged = details.data;
            final draggedIndex = _items.indexOf(dragged);
            final targetIndex = _items.indexOf(item);
            if (draggedIndex == -1 ||
                targetIndex == -1 ||
                draggedIndex == targetIndex) {
              return;
            }
            setState(() {
              final removed = _items.removeAt(draggedIndex);
              _items.insert(targetIndex, removed);
            });
          },
          builder: (context, _, _) {
            return LongPressDraggable<int>(
              data: item,
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: SizedBox(
                width: 160,
                child: _DragCard(index: item, keyPrefix: 'reorder-drag-card'),
              ),
              childWhenDragging: const SizedBox(height: 140),
              onDragStarted: () {
                setState(() {
                  _draggingItem = item;
                });
              },
              onDragUpdate: (details) {
                _autoScroller.updateDragRect(
                  Rect.fromLTWH(
                    details.globalPosition.dx,
                    details.globalPosition.dy,
                    160,
                    140,
                  ),
                );
              },
              onDragEnd: (_) {
                _autoScroller.stop();
                setState(() {
                  _draggingItem = null;
                });
              },
              onDragCompleted: () {
                _autoScroller.stop();
                setState(() {
                  _draggingItem = null;
                });
              },
              child: Opacity(
                opacity: _draggingItem == item ? 0.3 : 1,
                child: _DragCard(index: item, keyPrefix: 'reorder-drag-card'),
              ),
            );
          },
        );
      },
    );
  }
}
