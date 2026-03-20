/// SwipeToRead — bidirectional left-swipe gesture.
///
/// • Unread items: swipe → green ✓ "标为已读" → [onSwipe] fires
/// • Read items:   swipe → blue ● "标为未读" → [onSwipe] fires
///
/// The parent decides what happens after swipe (mark read/unread,
/// remove from list, etc.).
///
/// NO haptic feedback — purely visual.
library;

import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'colors.dart';

class SwipeToRead extends StatefulWidget {
  final Widget child;

  /// Called after exit animation completes (or immediately if [exitOnSwipe] is false).
  final VoidCallback onSwipe;

  /// Whether this item is currently read.
  /// Controls the visual indicator (green ✓ vs blue ●) and label.
  final bool isRead;

  /// If true, the item plays an exit animation (slide-off + fade + collapse)
  /// after a successful swipe. Use this on pages where the item should
  /// disappear after action (e.g. home screen unread list).
  /// If false, the item snaps back after calling [onSwipe].
  final bool exitOnSwipe;

  const SwipeToRead({
    super.key,
    required this.child,
    required this.onSwipe,
    this.isRead = false,
    this.exitOnSwipe = false,
  });

  @override
  State<SwipeToRead> createState() => _SwipeToReadState();
}

class _SwipeToReadState extends State<SwipeToRead>
    with TickerProviderStateMixin {
  double _dragExtent = 0.0;
  late AnimationController _resetController;
  late Animation<double> _resetAnimation;

  // Exit animation
  late AnimationController _exitController;
  bool _exiting = false;

  static const double _threshold = 80.0;
  bool _thresholdReached = false;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resetAnimation = Tween<double>(
      begin: 0,
      end: 0,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));
    _resetController.addListener(() {
      if (!_exiting) {
        setState(() => _dragExtent = _resetAnimation.value);
      }
    });

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onSwipe();
      }
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (_exiting) return;
    setState(() {
      _dragExtent += details.delta.dx;
      if (_dragExtent > 0) _dragExtent = 0;
      if (_dragExtent < -160) _dragExtent = -160;
      _thresholdReached = _dragExtent.abs() >= _threshold;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_exiting) return;
    if (_thresholdReached) {
      if (widget.exitOnSwipe) {
        // Exit animation — slide off left + fade out + height collapse
        setState(() => _exiting = true);
        _exitController.forward();
      } else {
        // Snap back and fire callback immediately
        _resetAnimation = Tween<double>(begin: _dragExtent, end: 0).animate(
          CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
        );
        _resetController
          ..reset()
          ..forward();
        _thresholdReached = false;
        widget.onSwipe();
      }
    } else {
      // Snap back
      _resetAnimation = Tween<double>(begin: _dragExtent, end: 0).animate(
        CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
      );
      _resetController
        ..reset()
        ..forward();
      _thresholdReached = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final progress = (_dragExtent.abs() / _threshold).clamp(0.0, 1.0);

    // Colors & labels based on read state
    final actionColor = widget.isRead
        ? const Color(0xFF007AFF) // Blue for "mark unread"
        : AppColors.success; // Green for "mark read"
    final actionIcon = widget.isRead
        ? (_thresholdReached
              ? Icons.mark_email_unread_rounded
              : Icons.mark_email_unread_outlined)
        : (_thresholdReached
              ? Icons.check_circle_rounded
              : Icons.check_circle_outline_rounded);
    final actionLabel = widget.isRead ? '标为未读' : '标为已读';

    Widget content = Stack(
      children: [
        // Background — action indicator
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Color.lerp(
                c.surface,
                actionColor.withAlpha(context.isDark ? 40 : 25),
                progress,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: progress,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    actionIcon,
                    size: _thresholdReached ? 22 : 18,
                    color: actionColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    actionLabel,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: actionColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Foreground — the actual card
        Transform.translate(
          offset: Offset(_dragExtent, 0),
          child: widget.child,
        ),
      ],
    );

    // Exit animation: slide left + fade out + height collapse
    if (_exiting) {
      final slide = Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0))
          .animate(
            CurvedAnimation(parent: _exitController, curve: Curves.easeInCubic),
          );
      final fade = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: _exitController,
          curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
        ),
      );
      final collapse = Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(
          parent: _exitController,
          curve: const Interval(0.4, 1.0, curve: Curves.easeInCubic),
        ),
      );

      return SizeTransition(
        sizeFactor: collapse,
        axisAlignment: -1,
        child: SlideTransition(
          position: slide,
          child: FadeTransition(opacity: fade, child: content),
        ),
      );
    }

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: content,
    );
  }
}
