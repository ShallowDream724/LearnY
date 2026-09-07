import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/api_client_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
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

final homeScheduleProvider = StreamProvider.autoDispose<ScheduleState>((ref) {
  final auth = ref.watch(authProvider);
  ref.watch(dataSessionEpochProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  final days = ref.watch(homeScheduleVisibleDaysProvider);
  final operation = SyncOperation();
  ref.onDispose(operation.cancel);

  if (semesterId == null || !auth.canAccessCachedData) {
    return Stream.value(
      ScheduleState(
        semesterId: semesterId,
        snapshot: emptyScheduleSnapshot(days),
      ),
    );
  }
  return ref
      .watch(scheduleRepositoryProvider)
      .watch(
        semesterId: semesterId,
        days: days,
        fetchRemote: auth.isLoggedIn,
        operation: operation,
      );
});

final homeScheduleActionsProvider = Provider<HomeScheduleActions>((ref) {
  var active = true;
  ref.onDispose(() => active = false);
  return HomeScheduleActions(
    repository: ref.watch(scheduleRepositoryProvider),
    semesterId: ref.watch(currentSemesterIdProvider),
    firstDay: ref.watch(homeScheduleVisibleDaysProvider).first.dateKey,
    invalidate: () {
      if (active) ref.invalidate(homeScheduleProvider);
    },
  );
});

class HomeScheduleActions {
  const HomeScheduleActions({
    required this.repository,
    required this.semesterId,
    required this.firstDay,
    required this.invalidate,
  });

  final ScheduleRepository repository;
  final String? semesterId;
  final String firstDay;
  final void Function() invalidate;

  Future<bool> refresh() async {
    try {
      if (semesterId != null) {
        await repository.resetRemoteRefresh(semesterId!, firstDay);
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      invalidate();
    }
  }
}
