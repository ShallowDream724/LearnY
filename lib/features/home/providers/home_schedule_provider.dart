import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/providers/api_client_provider.dart';
import '../../../core/providers/time_tick_provider.dart';
import '../../../core/providers/course_catalog_provider.dart';
import '../../../core/providers/sync_models.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../../../core/schedule/schedule_repository.dart';
import '../../../core/schedule/schedule_semester_navigation.dart';
import '../../../core/semester/semester_repository.dart';
import '../../../core/sync/sync_actions.dart';
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
      final access = ref.watch(
        authProvider.select(
          (auth) => (auth.canAccessCachedData, auth.isLoggedIn),
        ),
      );
      ref.watch(dataSessionEpochProvider);
      final days = buildHomeScheduleDays(
        weekStart,
        today: ref.watch(homeScheduleTodayProvider),
      );
      final operation = SyncOperation();
      Timer? retry;
      ref.onDispose(() {
        retry?.cancel();
        operation.cancel();
      });

      if (!access.$1) {
        return Stream.value(
          ScheduleState(snapshot: emptyScheduleSnapshot(days)),
        );
      }
      return ref
          .watch(scheduleRepositoryProvider)
          .watch(days: days, fetchRemote: access.$2, operation: operation)
          .map((state) {
            retry?.cancel();
            // Mounted views recover transient failures; genuine identity
            // challenges wait for authentication instead of resubmitting.
            if (access.$2 &&
                !state.isRefreshing &&
                const {
                  ScheduleFailure.network,
                  ScheduleFailure.timeout,
                  ScheduleFailure.registrarUnavailable,
                }.contains(state.failure)) {
              retry = Timer(const Duration(minutes: 2), ref.invalidateSelf);
            }
            return state;
          });
    });

final homeScheduleActionsProvider = Provider<HomeScheduleActions>((ref) {
  return ref.watch(
    scheduleWeekActionsProvider(ref.watch(homeScheduleWeekStartProvider)),
  );
});

final homeRefreshActionsProvider = Provider<HomeRefreshActions>((ref) {
  var active = true;
  ref.onDispose(() => active = false);
  final owner = ref.watch(authProvider.select((auth) => auth.username));
  final epoch = ref.watch(dataSessionEpochProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  final scheduleActions = ref.watch(homeScheduleActionsProvider);
  return HomeRefreshActions(
    refreshContent: () async =>
        (await ref.read(syncActionsProvider).refreshAll()).state,
    refreshSchedule: scheduleActions.refresh,
    isCurrent: () =>
        active &&
        ref.read(authProvider).username == owner &&
        ref.read(dataSessionEpochProvider) == epoch &&
        ref.read(currentSemesterIdProvider) == semesterId,
  );
});

final scheduleWeekActionsProvider = Provider.autoDispose
    .family<HomeScheduleActions, DateTime>((ref, weekStart) {
      var active = true;
      final waiters = <_ScheduleRefreshWaiter>{};
      ref.onDispose(() {
        active = false;
        for (final waiter in waiters.toList()) {
          waiter.cancel();
        }
      });
      final expectRemote = ref.watch(
        authProvider.select((auth) => auth.isLoggedIn),
      );
      final stateProvider = scheduleWeekProvider(weekStart);
      ref.listen(stateProvider, (_, next) {
        if (next.isLoading) return;
        if (next.hasError) {
          for (final waiter in waiters.toList()) {
            waiter.fail(next.error!, next.stackTrace);
          }
          return;
        }
        final state = next.valueOrNull;
        if (state == null) return;
        for (final waiter in waiters.toList()) {
          waiter.add(state);
        }
      });
      return HomeScheduleActions(
        repository: ref.watch(scheduleRepositoryProvider),
        firstDay: buildHomeScheduleDays(weekStart).first.dateKey,
        refreshProvider: () async {
          if (!active) throw StateError('Schedule refresh scope changed');
          final keepAlive = ref.keepAlive();
          final waiter = _ScheduleRefreshWaiter(expectRemote: expectRemote);
          waiters.add(waiter);
          try {
            ref.invalidate(stateProvider);
            ref.read(stateProvider);
            return await waiter.future;
          } finally {
            waiters.remove(waiter);
            keepAlive.close();
          }
        },
        invalidate: () {
          if (active) ref.invalidate(scheduleWeekProvider(weekStart));
        },
      );
    });

class HomeScheduleActions {
  const HomeScheduleActions({
    required this.repository,
    required this.firstDay,
    required this.refreshProvider,
    required this.invalidate,
  });

  final ScheduleRepository repository;
  final String firstDay;
  final Future<ScheduleState> Function() refreshProvider;
  final void Function() invalidate;

  Future<bool> refresh() async {
    try {
      await repository.resetRemoteRefresh(firstDay);
      final state = await refreshProvider();
      return state.failure == null;
    } catch (_) {
      invalidate();
      return false;
    }
  }
}

class HomeRefreshResult {
  const HomeRefreshResult({
    required this.syncState,
    required this.scheduleRefreshed,
    this.isCurrent = true,
  });

  final SyncState syncState;
  final bool scheduleRefreshed;
  final bool isCurrent;
}

class HomeRefreshActions {
  HomeRefreshActions({
    required this.refreshContent,
    required this.refreshSchedule,
    bool Function()? isCurrent,
  }) : isCurrent = isCurrent ?? _alwaysCurrent;

  final Future<SyncState> Function() refreshContent;
  final Future<bool> Function() refreshSchedule;
  final bool Function() isCurrent;
  Future<HomeRefreshResult>? _active;

  Future<HomeRefreshResult> refresh() {
    final active = _active;
    if (active != null) return active;
    late final Future<HomeRefreshResult> operation;
    operation = _refresh().whenComplete(() {
      if (identical(_active, operation)) _active = null;
    });
    _active = operation;
    return operation;
  }

  Future<HomeRefreshResult> _refresh() async {
    final syncState = await refreshContent();
    if (!isCurrent()) {
      return HomeRefreshResult(
        syncState: syncState,
        scheduleRefreshed: false,
        isCurrent: false,
      );
    }
    final scheduleRefreshed = await refreshSchedule();
    return HomeRefreshResult(
      syncState: syncState,
      scheduleRefreshed: scheduleRefreshed,
      isCurrent: isCurrent(),
    );
  }

  static bool _alwaysCurrent() => true;
}

class _ScheduleRefreshWaiter {
  _ScheduleRefreshWaiter({required bool expectRemote})
    : _refreshStarted = !expectRemote;

  final _completer = Completer<ScheduleState>();
  bool _refreshStarted;

  Future<ScheduleState> get future => _completer.future;

  void add(ScheduleState state) {
    if (_completer.isCompleted) return;
    if (state.failure != null) {
      _completer.complete(state);
    } else if (state.isRefreshing) {
      _refreshStarted = true;
    } else if (_refreshStarted) {
      _completer.complete(state);
    }
  }

  void cancel() {
    if (!_completer.isCompleted) {
      _completer.completeError(StateError('Schedule refresh scope changed'));
    }
  }

  void fail(Object error, StackTrace? stackTrace) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}
