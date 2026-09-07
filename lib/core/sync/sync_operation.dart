class SyncCancelled implements Exception {
  const SyncCancelled();
}

class SyncOperation {
  SyncOperation({bool Function()? isCurrent}) : _isCurrent = isCurrent;

  final bool Function()? _isCurrent;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  bool get isActive => !_cancelled && (_isCurrent?.call() ?? true);

  void ensureActive() {
    if (!isActive) {
      throw const SyncCancelled();
    }
  }
}
