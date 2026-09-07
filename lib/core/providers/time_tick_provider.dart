import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/deadline_time.dart';

Stream<DateTime> minuteTickStream() {
  Timer? timer;
  late StreamController<DateTime> controller;
  void emit() {
    final now = nowInShanghai();
    controller.add(now);
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));

    timer = Timer(nextMinute.difference(now), emit);
  }

  controller = StreamController<DateTime>(
    onListen: emit,
    onPause: () => timer?.cancel(),
    onResume: emit,
    onCancel: () => timer?.cancel(),
  );
  return controller.stream;
}

final minuteTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return minuteTickStream();
});
