import '../api/learning_read_api.dart';
import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../semester/academic_calendar.dart';
import '../sync/sync_operation.dart';
import 'schedule_cache_codec.dart';
import 'schedule_models.dart';
import 'schedule_projection.dart';

/// Account-owned calendar transfers. Changing the visible week does not abandon
/// a semester transfer or enqueue another authentication attempt.
class CalendarRangeRepository {
  CalendarRangeRepository({
    required this.database,
    required this.apiClient,
    required this.now,
    required this.failureFor,
  });

  static const snapshotScope = 'calendar-v2';
  final AppDatabase database;
  final LearningReadApi apiClient;
  final DateTime Function() now;
  final ScheduleFailure Function(Object) failureFor;
  final _lifetime = SyncOperation();
  final _requests = <String, _CalendarTransfer>{};

  void dispose() => _lifetime.cancel();

  String refreshKey(AcademicTermDates term) => AppStateKeys.scheduleWeekRefresh(
    'calendar-term-v1',
    '${term.id}:${term.start}:${term.end}',
  );

  Future<void> reset(AcademicTermDates term) async {
    final key = refreshKey(term);
    if (_requests[key]?.completed == true) _requests.remove(key);
    await database.deleteState(key);
  }

  Future<void> refresh(AcademicTermDates term) {
    _lifetime.ensureActive();
    final key = refreshKey(term);
    final previous = _requests[key];
    if (previous != null &&
        (!previous.completed ||
            now().difference(previous.startedAt) <
                const Duration(minutes: 1))) {
      return previous.future;
    }
    final transfer = _CalendarTransfer(now());
    _requests[key] = transfer;
    transfer.future = () async {
      try {
        await _refresh(term, key);
      } finally {
        transfer.completed = true;
      }
    }();
    return transfer.future;
  }

  Future<void> _refresh(AcademicTermDates term, String key) async {
    try {
      final events = await apiClient.getCalendar(term.start, term.end);
      _lifetime.ensureActive();
      await database.transaction(() async {
        final start = DateTime.parse(term.start);
        final end = DateTime.parse(term.end);
        for (
          var week = scheduleWeekStart(start);
          !week.isAfter(end);
          week = week.add(const Duration(days: 7))
        ) {
          _lifetime.ensureActive();
          final days = buildHomeScheduleDays(week);
          final snapshotKey = AppStateKeys.scheduleWeekSnapshot(
            snapshotScope,
            days.first.dateKey,
          );
          final raw = await database.getState(snapshotKey);
          final cached = raw == null
              ? null
              : decodeHomeScheduleSnapshotCachePayload(
                  semesterId: snapshotScope,
                  days: days,
                  raw: raw,
                );
          final remote = buildHomeScheduleSnapshotFromCalendarEvents(
            days: days,
            events: events,
          );
          // Empty school responses must not erase an earlier actual timetable.
          final retained = !hasScheduleItems(remote) && cached != null
              ? cached
              : HomeScheduleSnapshot(
                  days: days,
                  itemsByDateKey: {
                    for (final day in days)
                      day.dateKey: term.contains(day.date)
                          ? remote.itemsFor(day)
                          : cached?.itemsFor(day) ?? [],
                  },
                );
          await database.setState(
            snapshotKey,
            encodeHomeScheduleSnapshotCachePayload(
              semesterId: snapshotScope,
              snapshot: retained,
            ),
          );
        }
        await _saveRefresh(key, true);
        _lifetime.ensureActive();
      });
    } on SyncCancelled {
      rethrow;
    } catch (error) {
      _lifetime.ensureActive();
      await database.transaction(() async {
        _lifetime.ensureActive();
        await _saveRefresh(key, false, failureFor(error));
        _lifetime.ensureActive();
      });
      rethrow;
    }
  }

  Future<void> _saveRefresh(
    String key,
    bool success, [
    ScheduleFailure? failure,
  ]) => database.setState(
    key,
    encodeHomeScheduleRemoteRefreshPayload(
      HomeScheduleRemoteRefreshState(
        semesterId: snapshotScope,
        lastAttemptAt: now(),
        hasSuccessfulRefresh: success,
        failure: failure,
      ),
    ),
  );
}

class _CalendarTransfer {
  _CalendarTransfer(this.startedAt);
  final DateTime startedAt;
  bool completed = false;
  late final Future<void> future;
}
