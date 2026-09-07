import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/api_client_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
import '../../../core/providers/course_catalog_provider.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../../../core/schedule/schedule_repository.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/utils/deadline_time.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepository(
    database: ref.watch(databaseProvider),
    apiClient: ref.watch(learningReadApiProvider),
    courseCatalog: ref.watch(courseCatalogRepositoryProvider),
  );
});

final homeScheduleTodayProvider = Provider<DateTime>((ref) {
  final now = ref.watch(minuteTickProvider).valueOrNull ?? nowInShanghai();
  return DateTime(now.year, now.month, now.day);
});

final homeScheduleVisibleDaysProvider = Provider<List<HomeScheduleDayOption>>((
  ref,
) {
  final today = ref.watch(homeScheduleTodayProvider);
  return buildHomeScheduleDays(
    ref.watch(homeScheduleWeekStartProvider),
    today: today,
  );
});

final homeScheduleWeekStartProvider = Provider<DateTime>((ref) {
  final selected = ref.watch(homeScheduleSelectedDateProvider);
  return scheduleWeekStart(selected ?? ref.watch(homeScheduleTodayProvider));
});

final homeScheduleSelectedDateProvider = StateProvider<DateTime?>((ref) {
  ref.watch(dataSessionEpochProvider);
  return null;
});

final homeScheduleProvider = Provider.autoDispose<AsyncValue<ScheduleState>>((
  ref,
) {
  return ref.watch(
    scheduleWeekProvider(ref.watch(homeScheduleWeekStartProvider)),
  );
});

final scheduleWeekProvider = StreamProvider.autoDispose
    .family<ScheduleState, DateTime>((ref, weekStart) {
      final auth = ref.watch(authProvider);
      ref.watch(dataSessionEpochProvider);
      final days = buildHomeScheduleDays(
        weekStart,
        today: ref.watch(homeScheduleTodayProvider),
      );
      final operation = SyncOperation();
      ref.onDispose(operation.cancel);

      if (!auth.canAccessCachedData) {
        return Stream.value(
          ScheduleState(snapshot: emptyScheduleSnapshot(days)),
        );
      }
      return ref
          .watch(scheduleRepositoryProvider)
          .watch(
            days: days,
            fetchRemote: auth.isLoggedIn,
            operation: operation,
          );
    });

final homeScheduleActionsProvider = Provider<HomeScheduleActions>((ref) {
  return ref.watch(
    scheduleWeekActionsProvider(ref.watch(homeScheduleWeekStartProvider)),
  );
});

final scheduleWeekActionsProvider = Provider.autoDispose
    .family<HomeScheduleActions, DateTime>((ref, weekStart) {
      var active = true;
      ref.onDispose(() => active = false);
      return HomeScheduleActions(
        repository: ref.watch(scheduleRepositoryProvider),
        firstDay: buildHomeScheduleDays(weekStart).first.dateKey,
        invalidate: () {
          if (active) ref.invalidate(scheduleWeekProvider(weekStart));
        },
      );
    });

class HomeScheduleActions {
  const HomeScheduleActions({
    required this.repository,
    required this.firstDay,
    required this.invalidate,
  });

  final ScheduleRepository repository;
  final String firstDay;
  final void Function() invalidate;

  Future<bool> refresh() async {
    try {
      await repository.resetRemoteRefresh(firstDay);
      return true;
    } catch (_) {
      return false;
    } finally {
      invalidate();
    }
  }
}
