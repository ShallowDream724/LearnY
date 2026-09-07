import 'dart:async';

import '../api/enums.dart';
import '../api/learning_read_api.dart';
import '../api/models.dart' as api;
import '../api/registrar_calendar_api.dart';
import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../sync/sync_operation.dart';
import '../semester/academic_calendar.dart';
import '../courses/course_catalog_repository.dart';
import 'schedule_cache_codec.dart';
import 'schedule_models.dart';
import 'schedule_projection.dart';
import 'semester_schedule_cache.dart' show parseCourseSchedule;

class ScheduleRepository {
  // The v1 cache codec names this field semesterId; the calendar now has one
  // date-based scope, independent of the selected Learn semester.
  static const calendarCacheScope = 'calendar-v2';
  ScheduleRepository({
    required AppDatabase database,
    required LearningReadApi apiClient,
    DateTime Function()? now,
    this.requestTimeout = const Duration(seconds: 20),
    this.academicCalendar = const AcademicCalendar(),
    CourseCatalogRepository? courseCatalog,
  }) : _database = database,
       _apiClient = apiClient,
       _now = now ?? DateTime.now,
       _courseCatalog =
           courseCatalog ??
           CourseCatalogRepository(database: database, apiClient: apiClient);

  final AppDatabase _database;
  final LearningReadApi _apiClient;
  final DateTime Function() _now;
  final Duration requestTimeout;
  final AcademicCalendar academicCalendar;
  final CourseCatalogRepository _courseCatalog;

  Stream<ScheduleState> watch({
    required List<HomeScheduleDayOption> days,
    required bool fetchRemote,
    required SyncOperation operation,
  }) async* {
    const semesterId = calendarCacheScope;
    var displayed = emptyScheduleSnapshot(days);
    var hasCalendarData = false;
    var routineChecked = false;
    ScheduleFailure? routineFailure;
    final snapshotKey = AppStateKeys.scheduleWeekSnapshot(
      semesterId,
      days.first.dateKey,
    );
    final refreshKey = AppStateKeys.scheduleWeekRefresh(
      semesterId,
      days.first.dateKey,
    );
    try {
      await for (final storedCourses in _database.watchScheduleCourses()) {
        var courses = storedCourses;
        operation.ensureActive();
        final semesters = await _database.getAllSemesters();
        var withdrawn = {
          for (final semester in semesters)
            semester.id: await _courseCatalog.withdrawnCourseIdsByName(
              semester.id,
            ),
        };
        final local = await _routineSnapshot(days, semesters, courses);
        final raw = await _database.getState(snapshotKey);
        final cached = raw == null
            ? await _legacySnapshot(days, semesters)
            : decodeHomeScheduleSnapshotCachePayload(
                semesterId: semesterId,
                days: days,
                raw: raw,
              );
        final refreshRaw = await _database.getState(refreshKey);
        final refreshState = refreshRaw == null
            ? null
            : decodeHomeScheduleRemoteRefreshPayload(refreshRaw);
        operation.ensureActive();

        var fallback = local;
        displayed = cached == null
            ? fallback
            : _reconcile(
                _linkCourses(cached, semesters, courses, withdrawn),
                fallback,
                courses,
              );
        hasCalendarData = cached != null || fallback.hasRoutineData;
        final shouldRefresh =
            fetchRemote &&
            shouldFetchHomeScheduleRemoteSnapshot(
              semesterId: semesterId,
              cachedSnapshot: cached,
              localSnapshot: local,
              refreshState: refreshState,
              now: _now(),
            );
        final previousFailure =
            refreshState?.semesterId == semesterId &&
            refreshState?.hasSuccessfulRefresh == false;
        yield ScheduleState(
          snapshot: displayed,
          hasCalendarData: hasCalendarData,
          failure:
              routineFailure ??
              (!shouldRefresh && previousFailure
                  ? refreshState?.failure ?? ScheduleFailure.network
                  : null),
        );
        var refreshedRoutine = false;
        if (fetchRemote && !routineChecked) {
          refreshedRoutine = true;
          routineChecked = true;
          for (final semester in semesters) {
            final bounds = academicCalendar.datesFor(semester);
            if (bounds == null ||
                !days.any((day) => bounds.contains(day.date))) {
              continue;
            }
            final lastSync = DateTime.tryParse(
              await _database.getState(
                    AppStateKeys.courseCatalogUpdatedAt(semester.id),
                  ) ??
                  '',
            );
            if (lastSync != null &&
                _now().difference(lastSync) < const Duration(minutes: 15)) {
              continue;
            }
            yield ScheduleState(
              snapshot: displayed,
              hasCalendarData: hasCalendarData,
              isRefreshing: true,
            );
            try {
              await _courseCatalog.refresh(semester.id, operation);
              routineFailure = null;
            } on SyncCancelled {
              return;
            } catch (error) {
              routineFailure = _failureFor(error);
            }
          }
          operation.ensureActive();
          courses = await _database.getAllCourses();
          withdrawn = {
            for (final semester in semesters)
              semester.id: await _courseCatalog.withdrawnCourseIdsByName(
                semester.id,
              ),
          };
          fallback = await _routineSnapshot(days, semesters, courses);
          displayed = cached == null
              ? fallback
              : _reconcile(
                  _linkCourses(cached, semesters, courses, withdrawn),
                  fallback,
                  courses,
                );
          hasCalendarData = cached != null || fallback.hasRoutineData;
        }
        if (!shouldRefresh) {
          if (refreshedRoutine) {
            yield ScheduleState(
              snapshot: displayed,
              hasCalendarData: hasCalendarData,
              failure:
                  routineFailure ??
                  (previousFailure
                      ? refreshState?.failure ?? ScheduleFailure.network
                      : null),
            );
          }
          continue;
        }

        operation.ensureActive();
        yield ScheduleState(
          snapshot: displayed,
          hasCalendarData: hasCalendarData,
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
          );
          // Match only courses whose semester includes the occurrence date.
          final linkedRemote = _linkCourses(
            remote,
            semesters,
            courses,
            withdrawn,
          );
          // An empty response may mean this semester is no longer published.
          // Preserve the last actual snapshot rather than erasing its history.
          final retained = hasScheduleItems(linkedRemote) || cached == null
              ? linkedRemote
              : _linkCourses(cached, semesters, courses, withdrawn);
          final merged = _reconcile(retained, fallback, courses);
          await _database.transaction(() async {
            operation.ensureActive();
            await _database.setState(
              snapshotKey,
              encodeHomeScheduleSnapshotCachePayload(
                semesterId: semesterId,
                snapshot: retained,
              ),
            );
            await _database.setState(
              refreshKey,
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
          hasCalendarData = true;
          yield ScheduleState(
            snapshot: displayed,
            hasCalendarData: true,
            failure: routineFailure,
          );
        } on SyncCancelled {
          return;
        } catch (error) {
          operation.ensureActive();
          await _saveRefreshState(
            HomeScheduleRemoteRefreshState(
              semesterId: semesterId,
              lastAttemptAt: _now(),
              hasSuccessfulRefresh: false,
              failure: _failureFor(error),
            ),
            operation,
            refreshKey,
          );
          operation.ensureActive();
          yield ScheduleState(
            snapshot: displayed,
            hasCalendarData: hasCalendarData,
            failure: _failureFor(error),
          );
        }
      }
    } on SyncCancelled {
      return;
    } catch (_) {
      if (!operation.isActive) return;
      yield ScheduleState(
        snapshot: displayed,
        hasCalendarData: hasCalendarData,
        failure: ScheduleFailure.storage,
      );
    }
  }

  Future<void> resetRemoteRefresh(String firstDay) async {
    await _database.deleteState(
      AppStateKeys.scheduleWeekRefresh(calendarCacheScope, firstDay),
    );
    final days = buildHomeScheduleDays(DateTime.parse(firstDay));
    for (final semester in await _database.getAllSemesters()) {
      final bounds = academicCalendar.datesFor(semester);
      if (bounds != null && days.any((day) => bounds.contains(day.date))) {
        await _database.deleteState(
          AppStateKeys.courseCatalogUpdatedAt(semester.id),
        );
      }
    }
  }

  Future<HomeScheduleSnapshot> _routineSnapshot(
    List<HomeScheduleDayOption> days,
    List<Semester> semesters,
    List<Course> courses,
  ) async {
    var snapshot = emptyScheduleSnapshot(days);
    for (final semester in semesters) {
      final bounds = academicCalendar.datesFor(semester);
      if (bounds == null || !days.any((day) => bounds.contains(day.date))) {
        continue;
      }
      final enrolled = courses
          .where((course) => course.semesterId == semester.id)
          .toList();
      if (enrolled.isEmpty &&
          await _database.getState(
                AppStateKeys.courseCatalogUpdatedAt(semester.id),
              ) ==
              null) {
        continue;
      }
      final routine = buildHomeScheduleSnapshotFromCachedCourses(
        days: days,
        courses: enrolled,
        semesterStartDate: bounds.start,
        semesterEndDate: bounds.end,
      );
      final unassigned = <UnscheduledCourse>[];
      for (final course in enrolled) {
        final unresolved = parseCourseSchedule(
          course.timeAndLocationJson,
        ).unresolved;
        if (unresolved.isNotEmpty) {
          unassigned.add(
            UnscheduledCourse(
              courseId: course.id,
              courseName: course.chineseName.isNotEmpty
                  ? course.chineseName
                  : course.name,
              details: unresolved,
            ),
          );
        }
      }
      snapshot = mergeHomeScheduleSnapshots(
        primary: snapshot,
        fallback: HomeScheduleSnapshot(
          days: days,
          itemsByDateKey: routine.itemsByDateKey,
          hasRoutineData: true,
          unscheduledCourses: unassigned,
        ),
      );
    }
    return snapshot;
  }

  HomeScheduleSnapshot _reconcile(
    HomeScheduleSnapshot calendar,
    HomeScheduleSnapshot routine,
    List<Course> courses,
  ) {
    final now = _now();
    return reconcileScheduleSources(
      calendar: calendar,
      routine: routine,
      enrolledCourseIds: courses.map((course) => course.id).toSet(),
      today: DateTime(now.year, now.month, now.day),
    );
  }

  HomeScheduleSnapshot _linkCourses(
    HomeScheduleSnapshot snapshot,
    List<Semester> semesters,
    List<Course> courses,
    Map<String, Map<String, String>> withdrawn,
  ) {
    final linked = <String, List<TodayScheduleItem>>{};
    for (final day in snapshot.days) {
      final termId = academicCalendar.termOn(day.date, semesters)?.id;
      final ids = uniqueCourseIdsByName(
        courses.where((course) => course.semesterId == termId).toList(),
      );
      linked[day.dateKey] = [
        for (final item in snapshot.itemsFor(day))
          TodayScheduleItem(
            courseId:
                ids[item.courseName.trim()] ??
                item.courseId ??
                withdrawn[termId]?[item.courseName.trim()],
            courseName: item.courseName,
            startTime: item.startTime,
            endTime: item.endTime,
            location: item.location,
            source: item.source,
            endTimeInferred: item.endTimeInferred,
            periodLabel: item.periodLabel,
          ),
      ];
    }
    return HomeScheduleSnapshot(
      days: snapshot.days,
      itemsByDateKey: linked,
      hasRoutineData: snapshot.hasRoutineData,
      unscheduledCourses: snapshot.unscheduledCourses,
    );
  }

  Future<HomeScheduleSnapshot?> _legacySnapshot(
    List<HomeScheduleDayOption> days,
    List<Semester> semesters,
  ) async {
    HomeScheduleSnapshot? result;
    for (final key in [
      AppStateKeys.homeScheduleSnapshot,
      for (final semester in semesters)
        AppStateKeys.scheduleWeekSnapshot(semester.id, days.first.dateKey),
    ]) {
      final raw = await _database.getState(key);
      if (raw == null) continue;
      final snapshot = decodeHomeScheduleSnapshotCachePayload(
        days: days,
        raw: raw,
      );
      if (snapshot == null) continue;
      result = result == null
          ? snapshot
          : mergeHomeScheduleSnapshots(primary: result, fallback: snapshot);
    }
    return result;
  }

  Future<void> _saveRefreshState(
    HomeScheduleRemoteRefreshState state,
    SyncOperation operation,
    String key,
  ) {
    return _database.transaction(() async {
      operation.ensureActive();
      await _database.setState(
        key,
        encodeHomeScheduleRemoteRefreshPayload(state),
      );
      operation.ensureActive();
    });
  }

  ScheduleFailure _failureFor(Object error) {
    if (error is TimeoutException) return ScheduleFailure.timeout;
    if (error is RegistrarException) {
      return switch (error.failure) {
        RegistrarFailure.authorization =>
          ScheduleFailure.registrarAuthorization,
        RegistrarFailure.campusAccess => ScheduleFailure.campusAccess,
        RegistrarFailure.invalidCalendar => ScheduleFailure.invalidCalendar,
        RegistrarFailure.ticket ||
        RegistrarFailure.unavailable => ScheduleFailure.registrarUnavailable,
      };
    }
    if (error is api.ApiError &&
        (error.reason == FailReason.notLoggedIn ||
            error.reason == FailReason.noCredential)) {
      return ScheduleFailure.sessionExpired;
    }
    return ScheduleFailure.network;
  }
}
