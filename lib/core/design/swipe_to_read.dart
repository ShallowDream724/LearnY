/// SwipeToRead — left-swipe gesture to mark items as read.
///
/// When swipe passes threshold and is released:
/// 1. Item slides off-screen to the left with fade-out
/// 2. [onRead] fires after the exit animation completes
///
/// NO haptic feedback — purely visual.
library;

import 'package:flutter/material.dart';

import 'colors.dart';

class SwipeToRead extends StatefulWidget {
  final Widget child;

  /// Called after exit animation completes.
  final VoidCallback onRead;

  /// Whether this item is already read. When true, swipe is disabled
  /// and the widget is not rendered at all (height collapses).
  final bool isRead;

  const SwipeToRead({
    super.key,
    required this.child,
    required this.onRead,
    this.isRead = false,
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
    _resetAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOut),
    );
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
        widget.onRead();
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
    if (widget.isRead || _exiting) return;
    setState(() {
      _dragExtent += details.delta.dx;
      if (_dragExtent > 0) _dragExtent = 0;
      if (_dragExtent < -160) _dragExtent = -160;
      _thresholdReached = _dragExtent.abs() >= _threshold;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.isRead || _exiting) return;
    if (_thresholdReached) {
      // Trigger exit animation — slide off left + fade out
      setState(() => _exiting = true);
      _exitController.forward();
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
    if (widget.isRead) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (_dragExtent.abs() / _threshold).clamp(0.0, 1.0);

    Widget content = Stack(
      children: [
        // Background — green checkmark
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: Color.lerp(
                isDark ? AppColors.darkSurface : AppColors.lightSurface,
                AppColors.success.withAlpha(isDark ? 40 : 25),
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
                    _thresholdReached
                        ? Icons.check_circle_rounded
                        : Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '已读',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 13,
                      fontWeight:
                          _thresholdReached ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Foreground
        Transform.translate(
          offset: Offset(_dragExtent, 0),
          child: GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: widget.child,
          ),
        ),
      ],
    );

    if (_exiting) {
      return SizeTransition(
        sizeFactor: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: _exitController, curve: Curves.easeInOut),
        ),
        child: FadeTransition(
          opacity: Tween<double>(begin: 1, end: 0).animate(
            CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset.zero,
              end: const Offset(-1, 0),
            ).animate(
              CurvedAnimation(
                  parent: _exitController, curve: Curves.easeInOut),
            ),
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}
