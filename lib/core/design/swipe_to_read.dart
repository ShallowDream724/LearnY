import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app_surfaces.dart';
import 'app_theme_colors.dart';
import 'app_toast.dart';
import 'responsive.dart';
import 'read_action_feedback.dart';

/// Gesture, pointer, and keyboard paths share one operation. Data owns removal.
class SwipeToRead extends StatefulWidget {
  const SwipeToRead({
    super.key,
    required this.child,
    required this.onSwipe,
    this.isRead = false,
    this.removesOnRead = false,
    this.actionId,
    this.onUndo,
    this.readMenuTitle,
  }) : assert(onUndo == null || actionId != null);
  final Widget child;
  final Future<void> Function() onSwipe;
  final bool isRead;
  final bool removesOnRead;
  final Object? actionId;
  final Future<void> Function()? onUndo;

  /// Notifications expose the same read action through a contextual menu.
  /// Files supply their own richer menu inside [child].
  final String? readMenuTitle;

  @override
  State<SwipeToRead> createState() => _SwipeToReadState();
}

class _SwipeToReadState extends State<SwipeToRead> {
  bool _busy = false;
  bool _menuOpen = false;

  Future<void> _showReadMenu(Offset anchor) async {
    if (_busy || _menuOpen) return;
    _menuOpen = true;
    try {
      final overlay =
          Overlay.of(context, rootOverlay: true).context.findRenderObject()!
              as RenderBox;
      final point = overlay.globalToLocal(anchor);
      final selected = await showMenu<bool>(
        context: context,
        useRootNavigator: true,
        position: RelativeRect.fromRect(
          point & const Size(1, 1),
          Offset.zero & overlay.size,
        ),
        items: [
          PopupMenuItem<bool>(
            enabled: false,
            child: Text(
              widget.readMenuTitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const PopupMenuDivider(),
          PopupMenuItem<bool>(
            value: true,
            child: Row(
              children: [
                Icon(
                  widget.isRead
                      ? Icons.mark_email_unread_outlined
                      : Icons.mark_email_read_outlined,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(widget.isRead ? '标为未读' : '标为已读'),
              ],
            ),
          ),
        ],
      );
      if (selected == true && mounted) await _apply();
    } finally {
      _menuOpen = false;
    }
  }

  Future<bool> _apply() async {
    if (_busy) return false;
    final feedback = ReadActionFeedback.of(context);
    final wasRead = widget.isRead;
    final undo = widget.onUndo;
    final id = widget.actionId;
    final touch = !usesDesktopControls(context);
    setState(() => _busy = true);
    try {
      await widget.onSwipe();
      if (undo != null && id != null) {
        feedback?.record(id: id, wasRead: wasRead, undo: undo);
      }
      if (touch) HapticFeedback.selectionClick().ignore();
      return true;
    } catch (_) {
      if (feedback != null) {
        feedback.showFailure();
      } else if (mounted) {
        AppToast.showError(context, message: '已读状态未能更新');
      }
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.readMenuTitle == null
        ? widget.child
        : GestureDetector(
            onLongPressStart: (details) =>
                _showReadMenu(details.globalPosition),
            onSecondaryTapDown: (details) =>
                _showReadMenu(details.globalPosition),
            child: widget.child,
          );
    final label = widget.isRead ? '标为未读' : '标为已读';
    final icon = widget.isRead
        ? Icons.mark_email_unread_outlined
        : Icons.drafts_outlined;
    if (usesDesktopControls(context)) {
      return Row(
        children: [
          IconButton(
            tooltip: label,
            color: context.colors.subtitle,
            onPressed: _busy ? null : _apply,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, size: 18),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: AnimatedOpacity(
              opacity: _busy ? 0.6 : 1,
              duration: AppMotion.duration(context, AppMotion.feedback),
              child: content,
            ),
          ),
        ],
      );
    }
    // Read items stay still on mobile; the context menu can restore unread.
    if (widget.isRead) return content;
    return Semantics(
      customSemanticsActions: _busy
          ? null
          : {CustomSemanticsAction(label: label): _apply},
      child: Dismissible(
        key: ValueKey(this),
        direction: _busy ? DismissDirection.none : DismissDirection.endToStart,
        movementDuration: AppMotion.duration(context),
        // The list owns vertical reflow; Dismissible only owns horizontal motion.
        resizeDuration: null,
        background: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: context.colors.infoAccent.withAlpha(18),
            borderRadius: BorderRadius.circular(12),
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
          final removesOnRead = widget.removesOnRead;
          return await _apply() && removesOnRead;
        },
        child: content,
      ),
    );
  }
}
