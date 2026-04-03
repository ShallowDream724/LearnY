import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/deadline_time.dart';

Stream<DateTime> minuteTickStream() async* {
  yield nowInShanghai();

  while (true) {
    final now = nowInShanghai();
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 1));

    await Future<void>.delayed(nextMinute.difference(now));
    yield nowInShanghai();
  }
}

final minuteTickProvider = StreamProvider.autoDispose<DateTime>((ref) {
  return minuteTickStream();
});
