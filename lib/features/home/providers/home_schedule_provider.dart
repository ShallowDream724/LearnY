import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/api_client_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
import '../../../core/providers/course_catalog_provider.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../../../core/schedule/schedule_repository.dart';
import '../../../core/schedule/schedule_semester_navigation.dart';
import '../../../core/semester/semester_repository.dart';
import '../../../core/sync/sync_operation.dart';
import '../../../core/utils/deadline_time.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final repository = ScheduleRepository(
    database: ref.watch(databaseProvider),
    apiClient: ref.watch(learningReadApiProvider),
    courseCatalog: ref.watch(courseCatalogRepositoryProvider),
    academicCalendar: ref.watch(academicCalendarProvider),
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final scheduleSemesterNavigationProvider = Provider<ScheduleSemesterNavigation>(
  (ref) {
    return ScheduleSemesterNavigation(
      ref.watch(semesterCatalogProvider).valueOrNull ?? [],
      ref.watch(academicCalendarProvider),
    );
  },
);

final homeScheduleBrowseDateProvider = Provider<DateTime>((ref) {
  final today = ref.watch(homeScheduleTodayProvider);
  final explicit = ref.watch(homeScheduleSelectedDateProvider);
  final navigation = ref.watch(scheduleSemesterNavigationProvider);
  final term = navigation.datesFor(ref.watch(currentSemesterIdProvider));
  if (explicit != null && (term == null || term.contains(explicit))) {
    return explicit;
  }
  if (term == null) return today;
  final enteredOn = ref.watch(_homeScheduleEnteredOnProvider);
  if (!enteredOn.isAfter(DateTime.parse(term.end))) {
    final start = DateTime.parse(term.start);
    final end = DateTime.parse(term.end);
    return today.isBefore(start)
        ? start
        : today.isAfter(end)
        ? end
        : today;
  }
  return navigation.initialDate(term, today);
});

// Midnight can advance the day, but cannot silently leave the selected term.
final _homeScheduleEnteredOnProvider = Provider<DateTime>((ref) {
  ref.watch(currentSemesterIdProvider);
  ref.watch(dataSessionEpochProvider);
  return ref.read(homeScheduleTodayProvider);
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
  return scheduleWeekStart(ref.watch(homeScheduleBrowseDateProvider));
});

final homeScheduleSelectedDateProvider = StateProvider<DateTime?>((ref) {
  ref.watch(dataSessionEpochProvider);
  ref.watch(currentSemesterIdProvider);
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
