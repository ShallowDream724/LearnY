import 'dart:async';

import '../api/enums.dart';
import '../api/learning_read_api.dart';
import '../api/models.dart' as api;
import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../sync/sync_operation.dart';
import 'schedule_cache_codec.dart';
import 'schedule_models.dart';
import 'schedule_projection.dart';
import 'semester_schedule_cache.dart';

class ScheduleRepository {
  ScheduleRepository({
    required AppDatabase database,
    required LearningReadApi apiClient,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 20),
  }) : _database = database,
       _apiClient = apiClient,
       _now = now ?? DateTime.now;

  final AppDatabase _database;
  final LearningReadApi _apiClient;
  final DateTime Function() _now;
  final Duration requestTimeout;

  Stream<ScheduleState> watch({
    required String semesterId,
    required List<HomeScheduleDayOption> days,
    required bool fetchRemote,
    required SyncOperation operation,
  }) async* {
    var displayed = emptyScheduleSnapshot(days);
    try {
      await for (final courses in _database.watchCoursesBySemester(
        semesterId,
      )) {
        operation.ensureActive();
        final semester = await _database.getSemesterById(semesterId);
        final local = buildHomeScheduleSnapshotFromCachedCourses(
          days: days,
          courses: courses,
          semesterStartDate: semester?.startDate ?? '',
        );
        final semesterRaw = await _database.getState(
          AppStateKeys.homeScheduleSemesterCache(semesterId),
        );
        final semesterCache = semesterRaw == null
            ? null
            : decodeSemesterScheduleCachePayload(
                semesterId: semesterId,
                raw: semesterRaw,
              );
        final semesterSnapshot = semesterCache == null
            ? null
            : buildHomeScheduleSnapshotFromSemesterScheduleCache(
                days: days,
                cache: semesterCache,
              );
        final raw = await _database.getState(AppStateKeys.homeScheduleSnapshot);
        final cached = raw == null
            ? null
            : decodeHomeScheduleSnapshotCachePayload(
                semesterId: semesterId,
                days: days,
                raw: raw,
              );
        final refreshRaw = await _database.getState(
          AppStateKeys.homeScheduleRemoteRefreshState,
        );
        final refreshState = refreshRaw == null
            ? null
            : decodeHomeScheduleRemoteRefreshPayload(refreshRaw);
        operation.ensureActive();

        final fallback = mergeLocalScheduleSnapshot(
          currentSnapshot: local,
          semesterSnapshot: semesterSnapshot,
        );
        displayed = cached == null
            ? fallback
            : mergeHomeScheduleSnapshots(primary: cached, fallback: fallback);
        final shouldRefresh =
            fetchRemote &&
            shouldFetchHomeScheduleRemoteSnapshot(
              semesterId: semesterId,
              cachedSnapshot: cached,
              localSnapshot: local,
              semesterSnapshot: semesterSnapshot,
              refreshState: refreshState,
              now: _now(),
            );
        final previousFailure =
            refreshState?.semesterId == semesterId &&
            refreshState?.hasSuccessfulRefresh == false;
        yield ScheduleState(
          semesterId: semesterId,
          snapshot: displayed,
          failure: !shouldRefresh && previousFailure
              ? ScheduleFailure.network
              : null,
        );
        if (!shouldRefresh) {
          continue;
        }

        operation.ensureActive();
        await _saveRefreshState(
          HomeScheduleRemoteRefreshState(
            semesterId: semesterId,
            lastAttemptAt: _now(),
            hasSuccessfulRefresh: false,
          ),
          operation,
        );
        yield ScheduleState(
          semesterId: semesterId,
          snapshot: displayed,
          isRefreshing: true,
        );
        try {
          final events = await _apiClient
              .getCalendar(days.first.dateKey, days.last.dateKey)
              .timeout(requestTimeout);
          operation.ensureActive();
          final remote = buildHomeScheduleSnapshotFromCalendarEvents(
            days: days,
            events: events,
            courseIdsByName: uniqueCourseIdsByName(courses),
          );
          final merged = mergeHomeScheduleSnapshots(
            primary: remote,
            fallback: fallback,
          );
          await _database.transaction(() async {
            operation.ensureActive();
            await _database.setState(
              AppStateKeys.homeScheduleSnapshot,
              encodeHomeScheduleSnapshotCachePayload(
                semesterId: semesterId,
                snapshot: merged,
              ),
            );
            await _database.setState(
              AppStateKeys.homeScheduleRemoteRefreshState,
              encodeHomeScheduleRemoteRefreshPayload(
                HomeScheduleRemoteRefreshState(
                  semesterId: semesterId,
                  lastAttemptAt: _now(),
                  hasSuccessfulRefresh: true,
                ),
              ),
            );
            operation.ensureActive();
          });
          operation.ensureActive();
          displayed = merged;
          yield ScheduleState(semesterId: semesterId, snapshot: displayed);
        } on SyncCancelled {
          return;
        } catch (error) {
          operation.ensureActive();
          yield ScheduleState(
            semesterId: semesterId,
            snapshot: displayed,
            failure: _failureFor(error),
          );
        }
      }
    } on SyncCancelled {
      return;
    } catch (_) {
      if (!operation.isActive) return;
      yield ScheduleState(
        semesterId: semesterId,
        snapshot: displayed,
        failure: ScheduleFailure.storage,
      );
    }
  }

  Future<void> resetRemoteRefresh() =>
      _database.deleteState(AppStateKeys.homeScheduleRemoteRefreshState);

  Future<void> _saveRefreshState(
    HomeScheduleRemoteRefreshState state,
    SyncOperation operation,
  ) {
    return _database.transaction(() async {
      operation.ensureActive();
      await _database.setState(
        AppStateKeys.homeScheduleRemoteRefreshState,
        encodeHomeScheduleRemoteRefreshPayload(state),
      );
      operation.ensureActive();
    });
  }

  ScheduleFailure _failureFor(Object error) {
    if (error is TimeoutException) return ScheduleFailure.timeout;
    if (error is api.ApiError &&
        (error.reason == FailReason.notLoggedIn ||
            error.reason == FailReason.noCredential)) {
      return ScheduleFailure.sessionExpired;
    }
    return ScheduleFailure.network;
  }
}
