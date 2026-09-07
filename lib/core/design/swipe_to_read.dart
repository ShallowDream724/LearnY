import 'dart:async';

import 'package:flutter/material.dart';

import 'app_surfaces.dart';
import 'app_theme_colors.dart';
import 'app_toast.dart';
import 'responsive.dart';

/// Gesture, pointer, and keyboard paths share one operation. Data owns removal.
class SwipeToRead extends StatefulWidget {
  const SwipeToRead({
    super.key,
    required this.child,
    required this.onSwipe,
    this.isRead = false,
  });
  final Widget child;
  final FutureOr<void> Function() onSwipe;
  final bool isRead;

  @override
  State<SwipeToRead> createState() => _SwipeToReadState();
}

class _SwipeToReadState extends State<SwipeToRead> {
  bool _busy = false;

  Future<void> _apply() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onSwipe();
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '已读状态未能更新');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.isRead ? '标为未读' : '标为已读';
    final icon = widget.isRead ? Icons.mark_email_unread_outlined : Icons.done;
    final content = Row(
      children: [
        Expanded(child: widget.child),
        IconButton(
          tooltip: label,
          onPressed: _busy ? null : _apply,
          icon: _busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 19),
        ),
      ],
    );
    if (usesDesktopControls(context)) return content;
    return Dismissible(
      key: ValueKey(this),
      direction: _busy ? DismissDirection.none : DismissDirection.endToStart,
      movementDuration: AppMotion.duration(context),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: context.colors.infoAccent.withAlpha(18),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: context.colors.infoAccent, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _apply();
        // Successful writes update the source list; failed writes stay visible.
        return false;
      },
      child: content,
    );
  }
}
