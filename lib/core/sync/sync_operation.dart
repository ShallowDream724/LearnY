class SyncCancelled implements Exception {
  const SyncCancelled();
}

class SyncOperation {
  SyncOperation({bool Function()? isCurrent}) : _isCurrent = isCurrent;

  final bool Function()? _isCurrent;
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  void ensureActive() {
    if (_cancelled || !(_isCurrent?.call() ?? true)) {
      throw const SyncCancelled();
    }
  }
}
