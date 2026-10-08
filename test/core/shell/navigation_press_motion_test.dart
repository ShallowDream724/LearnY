import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/shell/navigation_press_motion.dart';

void main() {
  for (final duration in [0, 16, 60]) {
    testWidgets('a ${duration}ms tap completes one restrained pulse', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox());
      final press = NavigationPressMotion(tester);
      press.begin(immediate: false);
      await tester.pump();
      await tester.pump(Duration(milliseconds: duration));
      final beforeRelease = press.value;
      press.end(cancelled: false, immediate: false);
      expect(press.value, beforeRelease);
      final samples = <double>[];
      for (var i = 0; i < 45; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        samples.add(press.value.clamp(0, 1));
      }
      final peak = samples.reduce((a, b) => a > b ? a : b);
      expect(peak, inExclusiveRange(.12, .30));
      final peakIndex = samples.indexOf(peak);
      for (var i = peakIndex + 1; i < samples.length; i++) {
        expect(samples[i], lessThanOrEqualTo(samples[i - 1] + .0005));
      }
      expect(press.value, 0);
      expect(tester.hasRunningAnimations, isFalse);
      press.dispose();
    });
  }

  testWidgets('hold and drag expand continuously, cancel never expands later', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final press = NavigationPressMotion(tester);
    press.begin(immediate: false);
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(press.value, greaterThan(.9));
    press.end(cancelled: false, immediate: false);
    await tester.pump(const Duration(milliseconds: 32));
    final releaseValue = press.value;
    press.begin(immediate: false);
    expect(press.value, releaseValue);
    press.track(immediate: false);
    expect(press.value, releaseValue);
    await tester.pump(const Duration(milliseconds: 32));
    press.end(cancelled: true, immediate: false);
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(press.value, 0);
    press.begin(immediate: false);
    press.end(cancelled: true, immediate: false);
    await tester.pump(const Duration(milliseconds: 150));
    expect(press.value, 0);
    press.dispose();
  });

  testWidgets('reduced motion and disposal cancel the pending hold', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    final press = NavigationPressMotion(tester);
    press.begin(immediate: false);
    press.reset(pressed: true);
    expect(press.value, 1);
    press.end(cancelled: false, immediate: true);
    expect(press.value, 0);
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.hasRunningAnimations, isFalse);
    press.begin(immediate: false);
    press.dispose();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.takeException(), isNull);
  });
}
