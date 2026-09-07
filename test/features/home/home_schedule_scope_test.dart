import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/auth_controller.dart';
import 'package:learn_y/core/api/learning_read_api.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/app_providers.dart';
import 'package:learn_y/core/providers/api_client_provider.dart';
import 'package:learn_y/core/providers/time_tick_provider.dart';
import 'package:learn_y/core/schedule/schedule_cache_codec.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/semester/semester_repository.dart';
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';

void main() {
  test('the visible date window advances at Shanghai midnight', () async {
    final ticks = StreamController<DateTime>();
    final container = ProviderContainer(
      overrides: [minuteTickProvider.overrideWith((ref) => ticks.stream)],
    );
    addTearDown(container.dispose);
    addTearDown(ticks.close);
    container.listen(homeScheduleVisibleDaysProvider, (_, _) {});
    ticks.add(DateTime(2026, 9, 7, 23, 59));
    await container.read(minuteTickProvider.future);
    expect(
      container.read(homeScheduleVisibleDaysProvider).first.dateKey,
      '2026-09-07',
    );
    ticks.add(DateTime(2026, 9, 8));
    await container.pump();
    expect(
      container.read(homeScheduleVisibleDaysProvider).first.dateKey,
      '2026-09-08',
    );
  });

  test(
    'missing official semester metadata does not hide validated local cache or request a calendar',
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
      final state = await container.read(homeScheduleProvider.future);
      expect(
        state.snapshot.itemsFor(days.first).single.courseName,
        'Cached course',
      );
      expect(state.isHistorical, isFalse);
    },
  );
}

class _CachedAuth extends StateNotifier<AuthState> implements AuthController {
  _CachedAuth()
    : super(const AuthState.authenticated(username: 'test-student'));
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected auth operation');
}

class _NoCalendarCalls implements LearningReadApi {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'Calendar must not be fetched without a confirmed official semester',
  );
}
