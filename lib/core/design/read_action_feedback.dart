import 'dart:async';

import 'package:flutter/material.dart';

import 'app_surfaces.dart';
import 'app_theme_colors.dart';
import 'app_toast.dart';

/// A list owns its undo receipt, so removing a row cannot remove its feedback.
/// Repeated operations share one inline receipt and never queue success toasts.
class ReadActionFeedback extends StatefulWidget {
  const ReadActionFeedback({
    super.key,
    required this.child,
    this.expand = true,
  });

  final Widget child;
  final bool expand;

  static ReadActionFeedbackState? of(BuildContext context) =>
      context.findAncestorStateOfType<ReadActionFeedbackState>();

  @override
  State<ReadActionFeedback> createState() => ReadActionFeedbackState();
}

class ReadActionFeedbackState extends State<ReadActionFeedback> {
  final _changes = <Object, _ReadChange>{};
  Timer? _expiry;
  bool _undoing = false;
  bool _hovered = false;
  bool _focused = false;

  void record({
    required Object id,
    required bool wasRead,
    required Future<void> Function() undo,
  }) {
    if (!mounted) return;
    setState(() {
      final original = _changes[id];
      // A second toggle returns this item to its original state.
      if (original != null && original.wasRead == !wasRead) {
        _changes.remove(id);
      } else {
        _changes.putIfAbsent(id, () => _ReadChange(wasRead, undo));
      }
    });
    _expireLater();
  }

  void showFailure() {
    if (mounted) AppToast.showError(context, message: '已读状态未能更新');
  }

  void _expireLater() {
    _expiry?.cancel();
    if (_changes.isEmpty ||
        _hovered ||
        _focused ||
        MediaQuery.accessibleNavigationOf(context)) {
      return;
    }
    _expiry = Timer(const Duration(seconds: 8), _dismiss);
  }

  void _dismiss() {
    _expiry?.cancel();
    if (mounted) setState(_changes.clear);
  }

  Future<void> _undo() async {
    if (_undoing) return;
    _expiry?.cancel();
    final batch = _changes.entries.toList().reversed.toList();
    setState(() {
      _changes.clear();
      _undoing = true;
    });
    var failed = false;
    for (final entry in batch) {
      if (!mounted) return;
      // A more recent action on this item takes precedence over this batch.
      if (_changes.containsKey(entry.key)) continue;
      try {
        await entry.value.undo();
      } catch (_) {
        failed = true;
        _changes.putIfAbsent(entry.key, () => entry.value);
      }
    }
    if (!mounted) return;
    setState(() => _undoing = false);
    if (failed) AppToast.showError(context, message: '部分状态未能恢复，可重试撤销');
    _expireLater();
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = _changes.length;
    final allRead = _changes.values.every((entry) => !entry.wasRead);
    final allUnread = _changes.values.every((entry) => entry.wasRead);
    final message = _undoing
        ? '正在撤销'
        : allRead
        ? '$count 项已标为已读'
        : allUnread
        ? '$count 项已标为未读'
        : '已更新 $count 项阅读状态';
    return Column(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.expand) Expanded(child: widget.child) else widget.child,
        AnimatedSize(
          duration: AppMotion.duration(context),
          alignment: Alignment.topCenter,
          child: count == 0 && !_undoing
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MouseRegion(
                    onEnter: (_) {
                      _hovered = true;
                      _expiry?.cancel();
                    },
                    onExit: (_) {
                      _hovered = false;
                      _expireLater();
                    },
                    child: Focus(
                      onFocusChange: (focused) {
                        _focused = focused;
                        _expireLater();
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              message,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: context.colors.subtitle),
                            ),
                          ),
                          TextButton(
                            onPressed: _undoing ? null : _undo,
                            child: const Text('撤销'),
                          ),
                          IconButton(
                            tooltip: '关闭已读操作提示',
                            onPressed: _dismiss,
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReadChange {
  const _ReadChange(this.wasRead, this.undo);
  final bool wasRead;
  final Future<void> Function() undo;
}
