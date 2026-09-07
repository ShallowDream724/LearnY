import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/enums.dart';
import '../api/models.dart' as api;
import '../files/file_repository.dart';
import '../semester/semester_repository.dart';
import '../sync/sync_engine.dart';
import '../sync/sync_operation.dart';
import '../sync/sync_timing_tracker.dart';
import 'providers.dart';
import 'sync_models.dart';

import 'course_catalog_provider.dart';

export 'sync_models.dart';
export 'home_data_provider.dart';

final syncTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 90),
);

final _syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    apiClient: ref.watch(learningReadApiProvider),
    database: ref.watch(databaseProvider),
    fileRepository: ref.watch(fileRepositoryProvider),
    semesterRepository: ref.watch(semesterRepositoryProvider),
    courseCatalog: ref.watch(courseCatalogRepositoryProvider),
  );
});

final syncStateProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final notifier = SyncNotifier(
    ref,
    engine: ref.watch(_syncEngineProvider),
    timingTracker: SyncTimingTracker(),
  );
  ref.listen(currentSemesterIdProvider, (previous, next) {
    if (previous != next) notifier.invalidateScope();
  });
  ref.listen(dataSessionEpochProvider, (_, _) => notifier.invalidateScope());
  ref.listen(authProvider.select((auth) => auth.username), (previous, next) {
    if (previous != next) notifier.invalidateScope();
  });
  return notifier;
});

enum _SyncKind { all, homeworks, files, course }

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
  Future<void> _tail = Future.value();
  Future<void> _selectionTail = Future.value();
  int _selectionRequest = 0;
  final _pending = <String, Future<SyncState>>{};
  final _operations = <SyncOperation>{};
  int _generation = 0;
  bool _settingInitialSelection = false;

  Future<SyncState> syncAll({bool force = false}) =>
      _enqueue(_SyncKind.all, force: force);
  Future<SyncState> syncHomeworksOnly({bool force = false}) =>
      _enqueue(_SyncKind.homeworks, force: force);
  Future<SyncState> syncFilesOnly({bool force = false}) =>
      _enqueue(_SyncKind.files, force: force);
  Future<SyncState> syncCourse(String courseId, {bool force = false}) =>
      _enqueue(_SyncKind.course, courseId: courseId, force: force);

  Future<SyncState> selectSemester(String id) {
    invalidateScope();
    final request = ++_selectionRequest;
    final owner = _ref.read(authProvider).username;
    final epoch = _ref.read(dataSessionEpochProvider);
    final operation = SyncOperation(
      isCurrent: () =>
          mounted &&
          _ref.read(authProvider).username == owner &&
          _ref.read(dataSessionEpochProvider) == epoch,
    );
    final selection = _selectionTail.then<SyncState>((_) async {
      if (request != _selectionRequest || !mounted) {
        return const SyncState(status: SyncStatus.cancelled);
      }
      return _persistSelection(id, operation);
    });
    _selectionTail = selection.then<void>((_) {}).catchError((Object _) {});
    return selection.then<SyncState>((result) {
      if (result.status != SyncStatus.idle) return result;
      if (!mounted || request != _selectionRequest) {
        return const SyncState(status: SyncStatus.cancelled);
      }
      return syncAll(force: true);
    });
  }

  Future<SyncState> _persistSelection(
    String id,
    SyncOperation operation,
  ) async {
    try {
      operation.ensureActive();
      final repository = _ref.read(semesterRepositoryProvider);
      await repository.database.transaction(() async {
        operation.ensureActive();
        await repository.ensureSemester(
          id,
          ensureActive: operation.ensureActive,
        );
        await repository.saveSelection(id);
        operation.ensureActive();
      });
      operation.ensureActive();
      _ref.read(currentSemesterIdProvider.notifier).state = id;
      return const SyncState();
    } on SyncCancelled {
      return const SyncState(status: SyncStatus.cancelled);
    } catch (error) {
      const result = SyncState(
        status: SyncStatus.error,
        errorMessage: '学期切换失败，请重试',
      );
      if (mounted) state = result;
      return result;
    }
  }

  void invalidateScope() {
    if (_settingInitialSelection) return;
    _generation++;
    for (final operation in _operations) {
      operation.cancel();
    }
    _tail = Future.value();
    _pending.clear();
    if (mounted) state = const SyncState();
  }

  Future<SyncState> _enqueue(
    _SyncKind kind, {
    String? courseId,
    required bool force,
  }) {
    final generation = _generation;
    final key = '$generation/${kind.name}/${courseId ?? ''}/$force';
    final pending = _pending[key];
    if (pending != null && !force) return pending;
    final task = _tail.then<SyncState>((_) {
      if (!mounted || generation != _generation) {
        return const SyncState(status: SyncStatus.cancelled);
      }
      return _run(
        kind,
        courseId: courseId,
        force: force,
        generation: generation,
      );
    });
    _pending[key] = task;
    _tail = task.then<void>((_) {}).catchError((Object _) {});
    unawaited(
      task.then<void>(
        (_) {
          if (identical(_pending[key], task)) _pending.remove(key);
        },
        onError: (Object error, StackTrace stack) {
          if (identical(_pending[key], task)) _pending.remove(key);
        },
      ),
    );
    return task;
  }

  String get _scope =>
      '${_ref.read(authProvider).username ?? ''}::${_ref.read(currentSemesterIdProvider) ?? ''}';

  Future<SyncState> _run(
    _SyncKind kind, {
    required String? courseId,
    required bool force,
    required int generation,
  }) async {
    final owner = _ref.read(authProvider).username;
    if (owner == null) return const SyncState(status: SyncStatus.cancelled);
    final operation = SyncOperation(
      isCurrent: () =>
          mounted &&
          generation == _generation &&
          _ref.read(authProvider).username == owner,
    );
    _operations.add(operation);
    final previousSync = state.lastSynced;
    try {
      final now = DateTime.now();
      final cooldown = force
          ? null
          : switch (kind) {
              _SyncKind.all => _timingTracker.checkFullSync(now, scope: _scope),
              _SyncKind.homeworks => _timingTracker.checkHomeworkSync(
                now,
                scope: _scope,
              ),
              _SyncKind.files => _timingTracker.checkFileSync(
                now,
                scope: _scope,
              ),
              _SyncKind.course => _timingTracker.checkCourseSync(
                courseId!,
                now,
                scope: _scope,
              ),
            };
      if (cooldown != null) {
        return state = SyncState(
          status: SyncStatus.cooldown,
          cooldownSeconds: cooldown.cooldownSeconds,
          lastSynced: cooldown.lastSynced,
        );
      }
      state = SyncState(status: SyncStatus.syncing, lastSynced: previousSync);
      final result = await _execute(
        kind,
        courseId,
        operation,
      ).timeout(_ref.read(syncTimeoutProvider));
      operation.ensureActive();
      final finishedAt = DateTime.now();
      if (result.warnings.isEmpty) {
        switch (kind) {
          case _SyncKind.all:
            _timingTracker.recordFullSync(
              result.syncedCourseIds,
              finishedAt,
              scope: _scope,
            );
          case _SyncKind.homeworks:
            _timingTracker.recordHomeworkSync(finishedAt, scope: _scope);
          case _SyncKind.files:
            _timingTracker.recordFileSync(finishedAt, scope: _scope);
          case _SyncKind.course:
            _timingTracker.recordCourseSync(
              courseId!,
              finishedAt,
              scope: _scope,
            );
        }
      }
      return state = SyncState(
        status: SyncStatus.success,
        lastSynced: finishedAt,
        syncWarnings: result.warnings,
        updatedCount: result.updatedCount,
      );
    } catch (error) {
      if (!mounted || generation != _generation || error is SyncCancelled) {
        return const SyncState(status: SyncStatus.cancelled);
      }
      final expired =
          error is api.ApiError &&
          (error.reason == FailReason.notLoggedIn ||
              error.reason == FailReason.noCredential);
      return state = SyncState(
        status: expired ? SyncStatus.sessionExpired : SyncStatus.error,
        lastSynced: previousSync,
        errorMessage: expired ? '会话已过期，请重新登录' : _errorMessage(error),
        syncWarnings: error is SyncContentFailure ? error.warnings : const [],
      );
    } finally {
      operation.cancel();
      _operations.remove(operation);
    }
  }

  Future<SyncExecutionResult> _execute(
    _SyncKind kind,
    String? courseId,
    SyncOperation operation,
  ) async {
    var semesterId = _ref.read(currentSemesterIdProvider);
    if (kind == _SyncKind.all) {
      final repository = _ref.read(semesterRepositoryProvider);
      String? catalogWarning;
      try {
        final catalog = await repository.refreshCatalog(
          ensureActive: operation.ensureActive,
        );
        semesterId ??= catalog.currentId;
        catalogWarning = catalog.warning;
      } on SyncCancelled {
        rethrow;
      } catch (_) {
        if (semesterId == null) rethrow;
        catalogWarning = '学期信息未能更新，正在使用已保存的学期';
      }
      operation.ensureActive();
      if (semesterId == null) throw StateError('学期信息暂不可用');
      if (_ref.read(currentSemesterIdProvider) == null) {
        await repository.database.transaction(() async {
          operation.ensureActive();
          await repository.saveSelection(semesterId!);
          operation.ensureActive();
        });
        operation.ensureActive();
        _settingInitialSelection = true;
        try {
          _ref.read(currentSemesterIdProvider.notifier).state = semesterId;
        } finally {
          _settingInitialSelection = false;
        }
      }
      final result = await _engine.syncAll(semesterId, operation: operation);
      return SyncExecutionResult(
        updatedCount: result.updatedCount,
        syncedCourseIds: result.syncedCourseIds,
        warnings: [?catalogWarning, ...result.warnings],
      );
    }
    operation.ensureActive();
    return switch (kind) {
      _SyncKind.homeworks => _engine.syncHomeworksOnly(
        semesterId,
        operation: operation,
      ),
      _SyncKind.files => _engine.syncFilesOnly(
        semesterId,
        operation: operation,
      ),
      _SyncKind.course => _engine.syncCourse(courseId!, operation: operation),
      _SyncKind.all => throw StateError('Invalid sync kind'),
    };
  }

  String _errorMessage(Object error) {
    if (error is TimeoutException) return '同步超时，已保留本地缓存，请重试';
    if (error is SyncContentFailure) return error.toString();
    if (error is DioException) return '暂时无法连接网络学堂，已保留本地缓存';
    return '同步未完成，已保留本地缓存，请稍后重试';
  }

  @override
  void dispose() {
    for (final operation in _operations) {
      operation.cancel();
    }
    super.dispose();
  }
}
