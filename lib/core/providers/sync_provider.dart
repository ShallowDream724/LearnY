// Data sync providers — fetch data from API and cache in DB.
//
// This file focuses on state transitions and user-facing sync state.
// The orchestration and cooldown policy live in `core/sync/`.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/enums.dart';
import '../api/models.dart' as api;
import '../files/file_repository.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_timing_tracker.dart';
import 'providers.dart';
import 'sync_models.dart';

// Re-export so consumers only need one import.
export 'sync_models.dart';
export 'home_data_provider.dart';

final _syncTimingTrackerProvider = Provider<SyncTimingTracker>((ref) {
  return SyncTimingTracker();
});

final _syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    apiClient: ref.watch(apiClientProvider),
    database: ref.watch(databaseProvider),
    fileRepository: ref.watch(fileRepositoryProvider),
    setCurrentSemesterId: (semesterId) {
      ref.read(currentSemesterIdProvider.notifier).state = semesterId;
    },
  );
});

final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(
    ref,
    engine: ref.read(_syncEngineProvider),
    timingTracker: ref.read(_syncTimingTrackerProvider),
  );
});

class SyncNotifier extends StateNotifier<SyncState> {
  SyncNotifier(
    this._ref, {
    required SyncEngine engine,
    required SyncTimingTracker timingTracker,
  }) : _engine = engine,
       _timingTracker = timingTracker,
       super(const SyncState());

  final Ref _ref;
  final SyncEngine _engine;
  final SyncTimingTracker _timingTracker;

  Future<void> syncAll() async {
    await _runSync(
      cooldown: _timingTracker.checkFullSync(DateTime.now()),
      action: _engine.syncAll,
      fallbackErrorMessage: (error) => '同步失败: $error',
      onSuccess: (result, finishedAt) {
        _timingTracker.recordFullSync(result.syncedCourseIds, finishedAt);
      },
    );
  }

  Future<void> syncHomeworksOnly() async {
    await _runSync(
      cooldown: _timingTracker.checkHomeworkSync(DateTime.now()),
      action: () =>
          _engine.syncHomeworksOnly(_ref.read(currentSemesterIdProvider)),
      fallbackErrorMessage: (error) => '$error',
      onSuccess: (_, finishedAt) {
        _timingTracker.recordHomeworkSync(finishedAt);
      },
    );
  }

  Future<void> syncFilesOnly() async {
    await _runSync(
      cooldown: _timingTracker.checkFileSync(DateTime.now()),
      action: () => _engine.syncFilesOnly(_ref.read(currentSemesterIdProvider)),
      fallbackErrorMessage: (error) => '$error',
      onSuccess: (_, finishedAt) {
        _timingTracker.recordFileSync(finishedAt);
      },
    );
  }

  Future<void> syncCourse(String courseId) async {
    await _runSync(
      cooldown: _timingTracker.checkCourseSync(courseId, DateTime.now()),
      action: () => _engine.syncCourse(courseId),
      fallbackErrorMessage: (error) => '$error',
      onSuccess: (_, finishedAt) {
        _timingTracker.recordCourseSync(courseId, finishedAt);
      },
    );
  }

  Future<void> _runSync({
    required SyncCooldownDecision? cooldown,
    required Future<SyncExecutionResult> Function() action,
    required String Function(Object error) fallbackErrorMessage,
    required void Function(SyncExecutionResult result, DateTime finishedAt)
    onSuccess,
  }) async {
    if (state.status == SyncStatus.syncing) return;

    if (cooldown != null) {
      state = SyncState(
        status: SyncStatus.cooldown,
        cooldownSeconds: cooldown.cooldownSeconds,
        lastSynced: cooldown.lastSynced,
      );
      return;
    }

    state = const SyncState(status: SyncStatus.syncing);

    try {
      final result = await action();
      final finishedAt = DateTime.now();
      onSuccess(result, finishedAt);

      state = SyncState(
        status: SyncStatus.success,
        lastSynced: finishedAt,
        syncWarnings: result.warnings,
        updatedCount: result.updatedCount,
      );
    } on api.ApiError catch (error) {
      _handleApiError(error);
    } catch (error) {
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: fallbackErrorMessage(error),
      );
    }
  }

  bool _isSessionError(api.ApiError error) {
    return error.reason == FailReason.notLoggedIn ||
        error.reason == FailReason.noCredential;
  }

  void _handleApiError(api.ApiError error) {
    if (_isSessionError(error)) {
      state = const SyncState(
        status: SyncStatus.sessionExpired,
        errorMessage: '会话过期，请重新登录',
      );
    } else {
      state = SyncState(status: SyncStatus.error, errorMessage: '同步失败: $error');
    }
  }
}
