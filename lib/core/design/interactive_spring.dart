import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Retargetable direct-manipulation motion. Keeps velocity and stops at rest.
class InteractiveSpring extends ChangeNotifier
    implements ValueListenable<double> {
  InteractiveSpring(TickerProvider vsync, double initial)
    : _value = initial,
      target = initial {
    _ticker = vsync.createTicker(_tick);
  }
  late final Ticker _ticker;
  double _value;
  double target;
  double velocity = 0;
  double stiffness = 440;
  double damping = 34;
  Duration _previous = Duration.zero;
  @override
  double get value => _value;

  void moveTo(double next, {bool immediate = false, bool tracking = false}) {
    target = next;
    stiffness = tracking ? 900 : 440;
    damping = tracking ? 55 : 34;
    if (immediate) {
      _ticker.stop();
      _value = next;
      velocity = 0;
      notifyListeners();
    } else if (!_ticker.isActive) {
      _previous = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    var remaining = math.min((elapsed - _previous).inMicroseconds / 1e6, .05);
    _previous = elapsed;
    while (remaining > 0) {
      final dt = math.min(remaining, 1 / 240);
      velocity += ((target - _value) * stiffness - velocity * damping) * dt;
      _value += velocity * dt;
      remaining -= dt;
    }
    if ((target - _value).abs() < .0005 && velocity.abs() < .005) {
      _value = target;
      velocity = 0;
      _ticker.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
