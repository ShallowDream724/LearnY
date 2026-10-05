import 'dart:math' as math;

/// Runs a bounded number of operations while preserving input order.
/// A free slot starts the next item immediately, without waiting for a batch.
/// On failure, no new items start and already running work settles before the
/// error is returned, so a caller cannot accidentally overlap retries.
Future<List<R>> mapWithConcurrency<T, R>(
  List<T> items,
  Future<R> Function(T item) action, {
  int concurrency = 3,
}) async {
  if (concurrency < 1) {
    throw ArgumentError.value(concurrency, 'concurrency', 'Must be positive');
  }
  final results = List<R?>.filled(items.length, null);
  var next = 0;
  var failed = false;
  Future<void> worker() async {
    while (!failed && next < items.length) {
      final index = next++;
      try {
        results[index] = await action(items[index]);
      } catch (_) {
        failed = true;
        rethrow;
      }
    }
  }

  await Future.wait([
    for (var i = 0; i < math.min(concurrency, items.length); i++) worker(),
  ]);
  return results.cast<R>();
}
