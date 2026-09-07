import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/utils/stream_combiner.dart';

void main() {
  test(
    'slow cancellation of one source does not keep other sources alive',
    () async {
      final gate = Completer<void>();
      var secondCancelled = false;
      final first = StreamController<int>(onCancel: () => gate.future);
      final second = StreamController<int>(
        onCancel: () {
          secondCancelled = true;
        },
      );
      final subscription = combineLatest2(
        first.stream,
        second.stream,
        (int a, int b) => a + b,
      ).listen((_) {});
      final cancelled = subscription.cancel();
      await Future<void>.delayed(Duration.zero);
      expect(secondCancelled, isTrue);
      gate.complete();
      await cancelled;
      await first.close();
      await second.close();
    },
  );
}
