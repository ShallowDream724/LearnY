import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/auth_controller.dart';
import 'package:learn_y/core/api/learning_read_api.dart';
import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/app_providers.dart';
import 'package:learn_y/core/providers/api_client_provider.dart';
import 'package:learn_y/core/providers/time_tick_provider.dart';
import 'package:learn_y/core/schedule/schedule_cache_codec.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/schedule/schedule_repository.dart';
import 'package:learn_y/core/semester/semester_repository.dart';
import 'package:learn_y/core/sync/sync_operation.dart';
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';

void main() {
  testWidgets(
    'mounted schedules retry transient failures but not identity challenges',
    (tester) async {
      final repository = _RetryingScheduleRepository();
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith((ref) => _OnlineAuth()),
          homeScheduleTodayProvider.overrideWith((ref) => DateTime(2026, 9, 7)),
          scheduleRepositoryProvider.overrideWithValue(repository),
        ],
      );
      final subscription = container.listen(
        scheduleWeekProvider(DateTime(2026, 9, 7)),
        (_, _) {},
      );
      await tester.pump();
      expect(repository.calls, 1);
      await tester.pump(const Duration(minutes: 1, seconds: 59));
      expect(repository.calls, 1);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(repository.calls, 2);
      await tester.pump(const Duration(minutes: 3));
      expect(
        repository.calls,
        2,
        reason: 'identity verification must not loop',
      );
      subscription.close();
      await tester.pump(const Duration(milliseconds: 1));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  test(
    'calendar can fetch next week before the new semester becomes official',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = _CalendarApi();
      final official = StreamController<String?>.broadcast();
      addTearDown(official.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authProvider.overrideWith((ref) => _OnlineAuth()),
          initialCurrentSemesterIdProvider.overrideWithValue('2026-2027-1'),
          serverCurrentSemesterIdProvider.overrideWith(
            (ref) => official.stream,
          ),
          minuteTickProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 9, 7)),
          ),
          learningReadApiProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      await container.read(minuteTickProvider.future);
      container.read(homeScheduleSelectedDateProvider.notifier).state =
          DateTime(2026, 9, 14);
      final completed = Completer<ScheduleState>();
      container.listen(scheduleWeekProvider(DateTime(2026, 9, 14)), (_, next) {
        final state = next.valueOrNull;
        if (state != null &&
            state.hasCalendarData &&
            !state.isRefreshing &&
            !completed.isCompleted) {
          completed.complete(state);
        }
      });
      final state = await completed.future;
      expect(client.calls, ['2026-09-14/2026-09-20']);
      expect(
        state.snapshot.itemsByDateKey.values.expand((items) => items),
        isEmpty,
      );
      expect(state.isRefreshing, isFalse);
      container.read(homeScheduleSelectedDateProvider.notifier).state =
          DateTime(2026, 9, 15);
      await container.pump();
      expect(client.calls, hasLength(1));
      container.read(currentSemesterIdProvider.notifier).state = '2025-2026-3';
      await container.pump();
      expect(
        client.calls,
        hasLength(1),
        reason: 'Learn semester selection does not invalidate calendar data',
      );
    },
  );

  test(
    'manual refresh waits for a delayed remote failure after cached data',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final client = _DelayedFailingCalendarApi();
      final days = buildHomeScheduleDays(DateTime(2026, 9, 7));
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
      final firstDay = days.first.dateKey;
      await db.setState(
        AppStateKeys.scheduleWeekSnapshot(
          ScheduleRepository.calendarCacheScope,
          firstDay,
        ),
        encodeHomeScheduleSnapshotCachePayload(
          semesterId: ScheduleRepository.calendarCacheScope,
          snapshot: cached,
        ),
      );
      await db.setState(
        AppStateKeys.scheduleWeekRefresh(
          ScheduleRepository.calendarCacheScope,
          firstDay,
        ),
        encodeHomeScheduleRemoteRefreshPayload(
          HomeScheduleRemoteRefreshState(
            semesterId: ScheduleRepository.calendarCacheScope,
            lastAttemptAt: DateTime.now(),
            hasSuccessfulRefresh: true,
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authProvider.overrideWith((ref) => _OnlineAuth()),
          initialCurrentSemesterIdProvider.overrideWithValue('2026-2027-1'),
          serverCurrentSemesterIdProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          minuteTickProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 9, 7)),
          ),
          learningReadApiProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);
      await container.read(minuteTickProvider.future);
      final week = container.read(homeScheduleWeekStartProvider);
      final subscription = container.listen(
        scheduleWeekProvider(week),
        (_, _) {},
      );
      addTearDown(subscription.close);
      final initial = await container.read(scheduleWeekProvider(week).future);
      expect(
        initial.snapshot.itemsFor(days.first).single.courseName,
        'Cached course',
      );

      final refresh = container.read(homeScheduleActionsProvider).refresh();
      await client.started.future;
      var completed = false;
      refresh.whenComplete(() => completed = true);
      await container.pump();
      expect(completed, isFalse);
      client.gate.completeError(StateError('offline'));
      expect(await refresh, isFalse);
    },
  );

  test('the visible date window advances at Shanghai midnight', () async {
    final ticks = StreamController<DateTime>();
    final container = ProviderContainer(
      overrides: [
        minuteTickProvider.overrideWith((ref) => ticks.stream),
        semesterCatalogProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ticks.close);
    container.listen(homeScheduleVisibleDaysProvider, (_, _) {});
    ticks.add(DateTime(2026, 9, 13, 23, 59));
    await container.read(minuteTickProvider.future);
    expect(
      container.read(homeScheduleVisibleDaysProvider).first.dateKey,
      '2026-09-07',
    );
    ticks.add(DateTime(2026, 9, 14));
    await container.pump();
    expect(
      container.read(homeScheduleVisibleDaysProvider).first.dateKey,
      '2026-09-14',
    );
  });

  test(
    'offline cached calendar does not depend on official semester metadata',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final days = buildHomeScheduleDays(DateTime(2026, 9, 7));
      final snapshot = HomeScheduleSnapshot(
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
          semesterId: '2026-2027-1',
          snapshot: snapshot,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          authProvider.overrideWith((ref) => _CachedAuth()),
          initialCurrentSemesterIdProvider.overrideWithValue('2026-2027-1'),
          serverCurrentSemesterIdProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
          minuteTickProvider.overrideWith(
            (ref) => Stream.value(DateTime(2026, 9, 7)),
          ),
          learningReadApiProvider.overrideWithValue(_NoCalendarCalls()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(minuteTickProvider.future);
      await container.read(serverCurrentSemesterIdProvider.future);
      container.listen(homeScheduleProvider, (_, _) {});
      final state = await container.read(
        scheduleWeekProvider(
          container.read(homeScheduleWeekStartProvider),
        ).future,
      );
      expect(
        state.snapshot.itemsFor(days.first).single.courseName,
        'Cached course',
      );
      expect(state.hasCalendarData, isTrue);
      expect(state.isRefreshing, isFalse);
    },
  );
}

class _CachedAuth extends StateNotifier<AuthState> implements AuthController {
  _CachedAuth() : super(const AuthState.cached(username: 'test-student'));
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected auth operation');
}

class _RetryingScheduleRepository implements ScheduleRepository {
  int calls = 0;
  @override
  Stream<ScheduleState> watch({
    required List<HomeScheduleDayOption> days,
    required bool fetchRemote,
    required SyncOperation operation,
  }) {
    calls++;
    return Stream.value(
      ScheduleState(
        snapshot: emptyScheduleSnapshot(days),
        failure: calls == 1
            ? ScheduleFailure.network
            : ScheduleFailure.identityVerification,
      ),
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected repository operation');
}

class _NoCalendarCalls implements LearningReadApi {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Offline identity must not request the calendar');
}

class _OnlineAuth extends StateNotifier<AuthState> implements AuthController {
  _OnlineAuth()
    : super(const AuthState.authenticated(username: 'test-student'));
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected auth operation');
}

class _CalendarApi implements LearningReadApi {
  final calls = <String>[];
  @override
  Future<List<api.CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) async {
    calls.add('$startDate/$endDate');
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call');
}

class _DelayedFailingCalendarApi implements LearningReadApi {
  final started = Completer<void>();
  final gate = Completer<List<api.CalendarEvent>>();

  @override
  Future<List<api.CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) {
    if (!started.isCompleted) started.complete();
    return gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected API call');
}
