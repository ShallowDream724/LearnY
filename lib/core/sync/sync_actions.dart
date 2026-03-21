import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/sync_provider.dart';

class SyncActionResult {
  const SyncActionResult(this.state);

  final SyncState state;

  bool get isSuccess => state.status == SyncStatus.success;
  bool get isCooldown => state.status == SyncStatus.cooldown;
  bool get isSessionExpired => state.status == SyncStatus.sessionExpired;
  bool get isError => state.status == SyncStatus.error;
}

class SyncActions {
  const SyncActions(this._ref);

  final Ref _ref;

  Future<SyncActionResult> refreshAll() async {
    await _ref.read(syncStateProvider.notifier).syncAll();
    return SyncActionResult(_ref.read(syncStateProvider));
  }

  Future<SyncActionResult> refreshHomeworksOnly() async {
    await _ref.read(syncStateProvider.notifier).syncHomeworksOnly();
    return SyncActionResult(_ref.read(syncStateProvider));
  }

  Future<SyncActionResult> refreshFilesOnly() async {
    await _ref.read(syncStateProvider.notifier).syncFilesOnly();
    return SyncActionResult(_ref.read(syncStateProvider));
  }

  Future<SyncActionResult> refreshCourse(String courseId) async {
    await _ref.read(syncStateProvider.notifier).syncCourse(courseId);
    return SyncActionResult(_ref.read(syncStateProvider));
  }
}

final syncActionsProvider = Provider<SyncActions>((ref) {
  return SyncActions(ref);
});
