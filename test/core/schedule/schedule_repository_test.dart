import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learning_read_api.dart';
import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/schedule/schedule_cache_codec.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/schedule/schedule_repository.dart';
import 'package:learn_y/core/sync/sync_operation.dart';

void main() {
  const semester = '2026-2027-1';
  final days = buildHomeScheduleDays(DateTime(2026, 9, 7));

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
        .watch(
          semesterId: semester,
          days: days,
          fetchRemote: true,
          operation: SyncOperation(),
        )
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
        .watch(
          semesterId: semester,
          days: days,
          fetchRemote: true,
          operation: SyncOperation(),
        )
        .take(3)
        .toList();
    expect(states.last.isRefreshing, isFalse);
    expect(states.last.failure, isNull);
    expect(states.last.snapshot.itemsFor(days.first), isEmpty);
    expect(await db.getState(AppStateKeys.homeScheduleSnapshot), isNotNull);
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
          .watch(
            semesterId: semester,
            days: days,
            fetchRemote: true,
            operation: SyncOperation(),
          )
          .take(3)
          .toList();
      final state = await repository
          .watch(
            semesterId: semester,
            days: days,
            fetchRemote: true,
            operation: SyncOperation(),
          )
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
          .watch(
            semesterId: semester,
            days: days,
            fetchRemote: true,
            operation: operation,
          )
          .toList();
      await client.started.future;
      operation.cancel();
      await db.clearUserScopedData();
      client.pending!.complete([event]);
      await task;
      expect(await db.getState(AppStateKeys.homeScheduleSnapshot), isNull);
      expect(
        await db.getState(AppStateKeys.homeScheduleRemoteRefreshState),
        isNull,
      );
    },
  );

  test(
    'timeout stops refreshing and late results cannot replace the cache',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = CalendarFake()
        ..pending = Completer<List<api.CalendarEvent>>();
      final repository = ScheduleRepository(
        database: db,
        apiClient: client,
        requestTimeout: const Duration(milliseconds: 30),
      );
      final states = await repository
          .watch(
            semesterId: semester,
            days: days,
            fetchRemote: true,
            operation: SyncOperation(),
          )
          .take(3)
          .toList();
      expect(states.last.failure, ScheduleFailure.timeout);
      expect(states.last.isRefreshing, isFalse);
      client.pending!.complete([event]);
      await Future<void>.delayed(Duration.zero);
      expect(await db.getState(AppStateKeys.homeScheduleSnapshot), isNull);
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
  bool fail = false;
  Completer<List<api.CalendarEvent>>? pending;
  final started = Completer<void>();

  @override
  Future<List<api.CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) async {
    if (!started.isCompleted) started.complete();
    if (fail) throw StateError('offline');
    return pending?.future ?? [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call: ${invocation.memberName}');
}
