import 'dart:async';

import 'package:flutter/material.dart';

import 'app_surfaces.dart';

/// A lazy list that keeps removed data visible until its row has collapsed.
///
/// [itemId] must return a unique, stable identity. Put row spacing inside
/// [itemBuilder] so that it collapses together with the row.
class AnimatedDataList<T> extends StatefulWidget {
  const AnimatedDataList({
    super.key,
    required this.items,
    required this.itemId,
    required this.itemBuilder,
    this.emptyBuilder,
    this.padding = EdgeInsets.zero,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  });

  final List<T> items;
  final Object Function(T) itemId;
  final Widget Function(BuildContext, T) itemBuilder;
  final WidgetBuilder? emptyBuilder;
  final EdgeInsetsGeometry padding;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final ScrollController? controller;

  @override
  State<AnimatedDataList<T>> createState() => _AnimatedDataListState<T>();
}

class _AnimatedDataListState<T> extends State<AnimatedDataList<T>> {
  final _listKey = GlobalKey<SliverAnimatedListState>();
  final List<_ListEntry<T>> _entries = [];
  Timer? _emptyStateTimer;
  Map<Key, int> _entryIndices = {};
  bool _hasShownItems = false;

  @override
  void initState() {
    super.initState();
    _entries.addAll(widget.items.map(_entryFor));
    assert(
      _entries.map((entry) => entry.id).toSet().length == _entries.length,
      'List item IDs must be unique.',
    );
    _hasShownItems = _entries.isNotEmpty;
    _updateIndices();
  }

  _ListEntry<T> _entryFor(T item) => _ListEntry(widget.itemId(item), item);

  void _updateIndices() {
    _entryIndices = {
      for (var index = 0; index < _entries.length; index++)
        _entries[index].key: index,
    };
  }

  @override
  void didUpdateWidget(covariant AnimatedDataList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextIds = widget.items.map(widget.itemId).toList();
    final nextIdSet = nextIds.toSet();
    assert(nextIdSet.length == nextIds.length, 'List item IDs must be unique.');

    final duration = _hasShownItems
        ? AppMotion.duration(context)
        : Duration.zero;
    for (var index = _entries.length - 1; index >= 0; index--) {
      if (!nextIdSet.contains(_entries[index].id)) {
        _remove(index, oldWidget.itemBuilder, duration);
      }
    }

    final existingIds = _entries.map((entry) => entry.id).toSet();
    for (var index = 0; index < widget.items.length; index++) {
      final id = nextIds[index];
      if (index < _entries.length && _entries[index].id == id) {
        // New stream objects with the same identity update in place.
        _entries[index].item = widget.items[index];
        continue;
      }

      // A moved row leaves its former position and enters at the new one.
      // Each appearance owns a key, so undo during an exit cannot collide
      // with the still-visible snapshot of that same business item.
      final previousIndex = existingIds.contains(id)
          ? _entries.indexWhere((entry) => entry.id == id)
          : -1;
      if (previousIndex != -1) {
        _remove(previousIndex, oldWidget.itemBuilder, duration);
      }
      _entries.insert(index, _entryFor(widget.items[index]));
      _listKey.currentState!.insertItem(index, duration: duration);
    }
    _hasShownItems = _hasShownItems || _entries.isNotEmpty;
    _updateIndices();
  }

  void _remove(
    int index,
    Widget Function(BuildContext, T) itemBuilder,
    Duration duration,
  ) {
    final entry = _entries.removeAt(index);
    final snapshot = entry.item;
    _listKey.currentState!.removeItem(
      index,
      (context, animation) => _buildEntry(
        entry,
        animation,
        itemBuilder(context, snapshot),
        removing: true,
      ),
      duration: duration,
    );

    // Off-screen outgoing rows are not built, so empty-state bookkeeping
    // cannot depend on their animation builder receiving a status callback.
    if (duration != Duration.zero) {
      _emptyStateTimer?.cancel();
      _emptyStateTimer = Timer(duration, () {
        if (!mounted) return;
        setState(() => _emptyStateTimer = null);
      });
    }
  }

  Widget _buildEntry(
    _ListEntry<T> entry,
    Animation<double> animation,
    Widget child, {
    bool removing = false,
  }) {
    final curvedAnimation = animation.drive(CurveTween(curve: AppMotion.curve));
    return SizeTransition(
      key: entry.key,
      sizeFactor: curvedAnimation,
      axisAlignment: -1,
      child: FadeTransition(
        opacity: curvedAnimation,
        child: IgnorePointer(ignoring: removing, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showEmpty =
        _entries.isEmpty &&
        _emptyStateTimer == null &&
        widget.emptyBuilder != null;
    return CustomScrollView(
      primary: widget.shrinkWrap ? false : null,
      controller: widget.controller,
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverAnimatedList(
            key: _listKey,
            initialItemCount: _entries.length,
            findChildIndexCallback: (key) => _entryIndices[key],
            itemBuilder: (context, index, animation) {
              final entry = _entries[index];
              return _buildEntry(
                entry,
                animation,
                widget.itemBuilder(context, entry.item),
              );
            },
          ),
        ),
        if (showEmpty)
          if (widget.shrinkWrap)
            SliverToBoxAdapter(child: widget.emptyBuilder!(context))
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: widget.emptyBuilder!(context),
            ),
      ],
    );
  }

  @override
  void dispose() {
    _emptyStateTimer?.cancel();
    super.dispose();
  }
}

class _ListEntry<T> {
  _ListEntry(this.id, this.item);

  final Object id;
  T item;

  // SliverAnimatedList cannot map outgoing children through its logical-index
  // callback. Preserve their state when another update moves the outgoing
  // slot, including a Dismissible that is still held at its swipe position.
  late final Key key = GlobalObjectKey(this);
}
