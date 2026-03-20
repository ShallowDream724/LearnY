/// Apple-style cooldown toast — a capsule pill that slides down from the
/// top of the screen with frosted glass background.
///
/// Usage:
///   CooldownToast.show(context, seconds: 23);
///
/// Design:
/// - Slides down from behind SafeArea with spring curve
/// - Frosted glass capsule (BackdropFilter blur)
/// - Checkmark icon + "已是最新 · Xs 后可刷新"
/// - Auto-dismisses after 2s with fade-out
/// - Only one toast at a time (previous dismissed)
library;

import 'dart:ui';

import 'package:flutter/material.dart';

class CooldownToast {
  static OverlayEntry? _current;

  /// Show a cooldown toast. [seconds] = remaining cooldown.
  static void show(BuildContext context, {required int seconds}) {
    // Dismiss any existing toast
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _CooldownToastWidget(
        seconds: seconds,
        onDismiss: () {
          entry.remove();
          if (_current == entry) _current = null;
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }
}

class _CooldownToastWidget extends StatefulWidget {
  final int seconds;
  final VoidCallback onDismiss;

  const _CooldownToastWidget({
    required this.seconds,
    required this.onDismiss,
  });

  @override
  State<_CooldownToastWidget> createState() => _CooldownToastWidgetState();
}

class _CooldownToastWidgetState extends State<_CooldownToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // Slide: 0→1 (enter, 0-300ms), hold (300-1800ms), 1→0 (exit, 1800-2500ms)
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 12, // 300ms
      ),
      TweenSequenceItem(
        tween: ConstantTween(0.0),
        weight: 60, // 1500ms hold
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: -1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 28, // 700ms
      ),
    ]).animate(_controller);

    // Opacity: fade in fast, hold, fade out
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: 62,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 28,
      ),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: topPadding + 4),
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value * 60),
              child: Opacity(
                opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xCC2C2C2E)
                  : const Color(0xCCF2F2F7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(10),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 40 : 15),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Color(0xFF34C759),
                ),
                const SizedBox(width: 6),
                Text(
                  '已是最新 · ${widget.seconds}s 后可刷新',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? Colors.white.withAlpha(220)
                        : Colors.black.withAlpha(200),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
