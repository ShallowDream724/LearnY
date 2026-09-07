import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/api_client_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../../../core/schedule/schedule_repository.dart';
import '../../../core/semester/semester_repository.dart';
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
  return buildHomeScheduleDays(ref.watch(homeScheduleTodayProvider));
});

final homeScheduleProvider = StreamProvider.autoDispose<ScheduleState>((ref) {
  final auth = ref.watch(authProvider);
  ref.watch(dataSessionEpochProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  final official = ref.watch(serverCurrentSemesterIdProvider);
  final days = ref.watch(homeScheduleVisibleDaysProvider);
  final operation = SyncOperation();
  ref.onDispose(operation.cancel);

  if (semesterId == null ||
      !auth.canAccessCachedData ||
      (official.valueOrNull != null && official.valueOrNull != semesterId)) {
    return Stream.value(
      ScheduleState(
        semesterId: semesterId,
        snapshot: emptyScheduleSnapshot(days),
        isRefreshing: official.isLoading,
        failure: official.hasError ? ScheduleFailure.storage : null,
        isHistorical:
            official.valueOrNull != null && semesterId != official.valueOrNull,
      ),
    );
  }
  return ref
      .watch(scheduleRepositoryProvider)
      .watch(
        semesterId: semesterId,
        days: days,
        fetchRemote: auth.isLoggedIn && official.valueOrNull == semesterId,
        operation: operation,
      );
});

final homeScheduleActionsProvider = Provider<HomeScheduleActions>((ref) {
  var active = true;
  ref.onDispose(() => active = false);
  return HomeScheduleActions(
    repository: ref.watch(scheduleRepositoryProvider),
    invalidate: () {
      if (active) ref.invalidate(homeScheduleProvider);
    },
  );
});

class HomeScheduleActions {
  const HomeScheduleActions({
    required this.repository,
    required this.invalidate,
  });

  final ScheduleRepository repository;
  final void Function() invalidate;

  Future<bool> refresh() async {
    try {
      await repository.resetRemoteRefresh();
      return true;
    } catch (_) {
      return false;
    } finally {
      invalidate();
    }
  }
}
