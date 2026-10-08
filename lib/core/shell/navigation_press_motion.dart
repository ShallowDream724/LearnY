import 'dart:async';

import 'package:flutter/scheduler.dart';

import '../design/interactive_spring.dart';

/// A light tap gets one complete, restrained pulse. Holding or scrubbing opens
/// the full lens. Navigation still commits on pointer-up, without waiting here.
class NavigationPressMotion extends InteractiveSpring {
  NavigationPressMotion(TickerProvider vsync) : super(vsync, 0);

  Timer? _dwell;
  bool _released = false;

  void begin({required bool immediate}) {
    _dwell?.cancel();
    _released = false;
    moveTo(immediate ? 1 : .28, immediate: immediate);
    if (immediate) return;
    _dwell = Timer(const Duration(milliseconds: 100), () {
      _dwell = null;
      moveTo(_released ? 0 : 1);
    });
  }

  void track({required bool immediate}) {
    _dwell?.cancel();
    _dwell = null;
    moveTo(1, immediate: immediate);
  }

  void end({required bool cancelled, required bool immediate}) {
    _released = true;
    // Finish the small initial response even for a tap between two frames.
    // Cancellation and direct manipulation always release from their current
    // value and velocity; neither queues a later expansion.
    if (!cancelled && !immediate && _dwell?.isActive == true) return;
    _dwell?.cancel();
    _dwell = null;
    moveTo(0, immediate: immediate);
  }

  void reset({required bool pressed}) {
    _dwell?.cancel();
    _dwell = null;
    moveTo(pressed ? 1 : 0, immediate: true);
  }

  @override
  void dispose() {
    _dwell?.cancel();
    super.dispose();
  }
}
