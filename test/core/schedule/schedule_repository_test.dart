import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learning_read_api.dart';
import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/api/registrar_calendar_api.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/schedule/schedule_cache_codec.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/schedule/schedule_repository.dart';
import 'package:learn_y/core/sync/sync_operation.dart';
import 'package:learn_y/core/semester/academic_calendar.dart';

void main() {
  const semester = ScheduleRepository.calendarCacheScope;
  final days = buildHomeScheduleDays(DateTime(2026, 9, 7));

  test(
    'local recurrence respects both semester bounds and updates when dates arrive',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      Future<void> saveTerm(String id, String start, String end) =>
          db.upsertSemester(
            SemestersCompanion.insert(
              id: id,
              startDate: start,
              endDate: end,
              startYear: 2026,
              endYear: 2027,
              type: 'fall',
            ),
          );
      await saveTerm('2025-2026-3', '2026-06-29', '2026-09-13');
      await saveTerm('2026-2027-1', '', '');
      for (final id in ['2025-2026-3', '2026-2027-1']) {
        await db.upsertCourse(
          CoursesCompanion.insert(
            id: id,
            name: id,
            chineseName: id,
            courseType: 'student',
            semesterId: id,
            timeAndLocationJson: Value(jsonEncode(['星期一第1节(全周)，六教101'])),
          ),
        );
      }
      final repository = ScheduleRepository(
        database: db,
        apiClient: CalendarFake(),
        academicCalendar: const AcademicCalendar(supplement: []),
      );
      final subscription = StreamIterator(
        repository.watch(
          days: buildHomeScheduleDays(DateTime(2026, 9, 14)),
          fetchRemote: false,
          operation: SyncOperation(),
        ),
      );
      addTearDown(subscription.cancel);
      await subscription.moveNext();
      expect(
        subscription.current.snapshot.itemsByDateKey.values.expand(
          (items) => items,
        ),
        isEmpty,
      );
      await saveTerm('2026-2027-1', '2026-09-14', '2027-01-17');
      await subscription.moveNext();
      expect(
        subscription.current.snapshot.itemsByDateKey.values
            .expand((items) => items)
            .single
            .courseId,
        '2026-2027-1',
      );
    },
  );

  test('campus authorization failure survives retry backoff', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final client = CalendarFake()
      ..error = const RegistrarException(RegistrarFailure.campusAccess);
    final repository = ScheduleRepository(database: db, apiClient: client);
    await repository
        .watch(days: days, fetchRemote: true, operation: SyncOperation())
        .take(3)
        .toList();
    final state = await repository
        .watch(days: days, fetchRemote: true, operation: SyncOperation())
        .first;
    expect(state.failure, ScheduleFailure.campusAccess);
    expect(state.isRefreshing, isFalse);
    expect(client.calls, hasLength(1));
  });

  test(
    'each week is fetched and cached independently, including a confirmed empty week',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = CalendarFake();
      final repository = ScheduleRepository(database: db, apiClient: client);
      for (final start in [DateTime(2026, 9, 7), DateTime(2026, 9, 14)]) {
        final result = await repository
            .watch(
              days: buildHomeScheduleDays(start),
              fetchRemote: true,
              operation: SyncOperation(),
            )
            .take(3)
            .toList();
        expect(result.last.hasCalendarData, isTrue);
      }
      expect(client.calls, ['2026-09-07/2026-09-13', '2026-09-14/2026-09-20']);
      final cached = await repository
          .watch(days: days, fetchRemote: true, operation: SyncOperation())
          .first;
      expect(cached.hasCalendarData, isTrue);
      expect(cached.isRefreshing, isFalse);
      expect(client.calls, hasLength(2));
      await db.clearUserScopedData();
      for (final first in ['2026-09-07', '2026-09-14']) {
        expect(
          await db.getState(AppStateKeys.scheduleWeekSnapshot(semester, first)),
          isNull,
        );
        expect(
          await db.getState(AppStateKeys.scheduleWeekRefresh(semester, first)),
          isNull,
        );
      }
    },
  );

  test('cached classes remain available when remote refresh fails', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final cached = HomeScheduleSnapshot(
      days: days,
      itemsByDateKey: {
        days.first.dateKey: const [
          TodayScheduleItem(
            courseName: 'Cached course',
            startTime: '08:00',
            endTime: '09:35',
            location: 'Room 101',
          ),
        ],
      },
    );
    await db.setState(
      AppStateKeys.homeScheduleSnapshot,
      encodeHomeScheduleSnapshotCachePayload(
        semesterId: semester,
        snapshot: cached,
      ),
    );
    final client = CalendarFake()..fail = true;
    final repository = ScheduleRepository(database: db, apiClient: client);
    final states = await repository
        .watch(days: days, fetchRemote: true, operation: SyncOperation())
        .take(3)
        .toList();
    expect(
      states.first.snapshot.itemsFor(days.first).single.courseName,
      'Cached course',
    );
    expect(states[1].isRefreshing, isTrue);
    expect(states.last.failure, ScheduleFailure.network);
    expect(
      states.last.snapshot.itemsFor(days.first).single.courseName,
      'Cached course',
    );
  });

  test('confirmed empty calendar ends refreshing without an error', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = ScheduleRepository(
      database: db,
      apiClient: CalendarFake(),
    );
    final states = await repository
        .watch(days: days, fetchRemote: true, operation: SyncOperation())
        .take(3)
        .toList();
    expect(states.last.isRefreshing, isFalse);
    expect(states.last.failure, isNull);
    expect(states.last.snapshot.itemsFor(days.first), isEmpty);
    expect(
      await db.getState(
        AppStateKeys.scheduleWeekSnapshot(semester, days.first.dateKey),
      ),
      isNotNull,
    );
  });

  test(
    'reopening an empty failed schedule preserves its failure during backoff',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = ScheduleRepository(
        database: db,
        apiClient: CalendarFake()..fail = true,
      );
      await repository
          .watch(days: days, fetchRemote: true, operation: SyncOperation())
          .take(3)
          .toList();
      final state = await repository
          .watch(days: days, fetchRemote: true, operation: SyncOperation())
          .first;
      expect(state.failure, ScheduleFailure.network);
      expect(state.isRefreshing, isFalse);
    },
  );

  test(
    'cancelling a request prevents late results from repopulating cleared account data',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = CalendarFake()
        ..pending = Completer<List<api.CalendarEvent>>();
      final operation = SyncOperation();
      final repository = ScheduleRepository(database: db, apiClient: client);
      final task = repository
          .watch(days: days, fetchRemote: true, operation: operation)
          .toList();
      await client.started.future;
      operation.cancel();
      await db.clearUserScopedData();
      client.pending!.complete([event]);
      await task;
      expect(
        await db.getState(
          AppStateKeys.scheduleWeekSnapshot(semester, days.first.dateKey),
        ),
        isNull,
      );
      expect(
        await db.getState(
          AppStateKeys.scheduleWeekRefresh(semester, days.first.dateKey),
        ),
        isNull,
      );
    },
  );

  test(
    'a transport timeout stops refreshing without replacing the cache',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = CalendarFake()
        ..error = TimeoutException('transport timed out');
      final repository = ScheduleRepository(database: db, apiClient: client);
      final states = await repository
          .watch(days: days, fetchRemote: true, operation: SyncOperation())
          .take(3)
          .toList();
      expect(states.last.failure, ScheduleFailure.timeout);
      expect(states.last.isRefreshing, isFalse);
      expect(
        await db.getState(
          AppStateKeys.scheduleWeekSnapshot(semester, days.first.dateKey),
        ),
        isNull,
      );
    },
  );

  test('failed requests back off even when there is no cached schedule', () {
    final now = DateTime(2026, 9, 7, 12);
    expect(
      shouldFetchHomeScheduleRemoteSnapshot(
        semesterId: semester,
        cachedSnapshot: null,
        localSnapshot: emptyScheduleSnapshot(days),
        refreshState: HomeScheduleRemoteRefreshState(
          semesterId: semester,
          lastAttemptAt: now,
          hasSuccessfulRefresh: false,
        ),
        now: now.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });
}

const event = api.CalendarEvent(
  location: 'Room 101',
  status: '',
  startTime: '08:00',
  endTime: '09:35',
  date: '2026-09-07',
  courseName: 'Remote course',
);

class CalendarFake implements LearningReadApi {
  final calls = <String>[];
  bool fail = false;
  Object? error;
  Completer<List<api.CalendarEvent>>? pending;
  final started = Completer<void>();

  @override
  Future<List<api.CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) async {
    calls.add('$startDate/$endDate');
    if (!started.isCompleted) started.complete();
    if (fail) throw StateError('offline');
    if (error != null) throw error!;
    return pending?.future ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}
