import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

/// Keeps the sliver's individual child identity during arbitrary reordering,
/// while allowing each row to fit its own title and metadata content.
class CourseGridDelegate extends SliverGridDelegate {
  const CourseGridDelegate({
    required this.columns,
    required this.cardWidth,
    required this.rowExtents,
  });

  final int columns;
  final double cardWidth;
  final List<double> rowExtents;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) =>
      _CourseGridLayout(
        columns: columns,
        cardWidth: cardWidth,
        rowExtents: rowExtents,
        reverseCrossAxis: axisDirectionIsReversed(
          constraints.crossAxisDirection,
        ),
      );

  @override
  bool shouldRelayout(CourseGridDelegate oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.cardWidth != cardWidth ||
      !listEquals(oldDelegate.rowExtents, rowExtents);
}

class _CourseGridLayout extends SliverGridLayout {
  _CourseGridLayout({
    required this.columns,
    required this.cardWidth,
    required this.rowExtents,
    required this.reverseCrossAxis,
  }) {
    var offset = 0.0;
    for (final extent in rowExtents) {
      rowOffsets.add(offset);
      offset += extent + 12;
    }
  }

  final int columns;
  final double cardWidth;
  final List<double> rowExtents;
  final bool reverseCrossAxis;
  final List<double> rowOffsets = [];

  int _rowAt(double offset) {
    var low = 0;
    var high = rowOffsets.length - 1;
    while (low < high) {
      final middle = (low + high + 1) ~/ 2;
      if (rowOffsets[middle] <= offset) {
        low = middle;
      } else {
        high = middle - 1;
      }
    }
    return low;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset) =>
      _rowAt(scrollOffset) * columns;

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset) =>
      (_rowAt(scrollOffset) + 1) * columns - 1;

  @override
  SliverGridGeometry getGeometryForChildIndex(int index) {
    final row = index ~/ columns;
    final column = reverseCrossAxis
        ? columns - 1 - index % columns
        : index % columns;
    return SliverGridGeometry(
      scrollOffset: rowOffsets[row],
      crossAxisOffset: column * (cardWidth + 12),
      mainAxisExtent: rowExtents[row],
      crossAxisExtent: cardWidth,
    );
  }

  @override
  double computeMaxScrollOffset(int childCount) {
    if (childCount == 0 || rowExtents.isEmpty) return 0;
    final row = (childCount - 1) ~/ columns;
    return rowOffsets[row] + rowExtents[row];
  }
}
