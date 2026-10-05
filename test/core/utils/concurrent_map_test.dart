import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/utils/concurrent_map.dart';

void main() {
  test(
    'free slots advance without waiting for a slow item and preserve order',
    () async {
      final gates = List.generate(5, (_) => Completer<int>());
      final started = <int>[];
      final fourthStarted = Completer<void>();
      var active = 0;
      var peak = 0;
      final result = mapWithConcurrency<int, int>([0, 1, 2, 3, 4], (
        index,
      ) async {
        started.add(index);
        active++;
        if (active > peak) peak = active;
        if (index == 3) fourthStarted.complete();
        try {
          return await gates[index].future;
        } finally {
          active--;
        }
      });
      expect(started, [0, 1, 2]);
      gates[1].complete(10);
      await fourthStarted.future;
      expect(started, [0, 1, 2, 3]);
      expect(gates[0].isCompleted, isFalse);
      for (final index in [4, 3, 2, 0]) {
        gates[index].complete(index * 10);
      }
      expect(await result, [0, 10, 20, 30, 40]);
      expect(peak, 3);
    },
  );

  test(
    'failure stops new work and waits for active work before returning',
    () async {
      final gates = List.generate(4, (_) => Completer<int>());
      final started = <int>[];
      var completed = false;
      final failure = StateError('cancelled');
      final result = mapWithConcurrency<int, int>([0, 1, 2, 3], (index) {
        started.add(index);
        return gates[index].future;
      }, concurrency: 2);
      final checked = expectLater(
        result,
        throwsA(same(failure)),
      ).then((_) => completed = true);
      gates[0].completeError(failure);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);
      expect(started, [0, 1]);
      gates[1].complete(1);
      await checked;
      expect(started, [0, 1]);
    },
  );

  test('empty inputs and nullable results are supported', () async {
    expect(
      await mapWithConcurrency<int, int>([], (value) async => value),
      isEmpty,
    );
    expect(await mapWithConcurrency<int, int?>([1], (_) async => null), [null]);
    await expectLater(
      mapWithConcurrency<int, int>([], (value) async => value, concurrency: 0),
      throwsArgumentError,
    );
  });
}
