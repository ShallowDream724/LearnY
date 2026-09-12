import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/router/router.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/sync_provider.dart';
import '../../../core/semester/semester_repository.dart';
import '../../../core/semester/semester_models.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../providers/home_schedule_provider.dart';
import 'schedule_browser.dart';
import 'schedule_dialog.dart';
import 'schedule_semester_confirmation.dart';

bool shouldShowHomeTodayScheduleSection(AuthState auth) =>
    auth.canAccessCachedData;

class HomeTodayScheduleSection extends ConsumerStatefulWidget {
  const HomeTodayScheduleSection({super.key});

  @override
  ConsumerState<HomeTodayScheduleSection> createState() =>
      _HomeTodayScheduleSectionState();
}

class _HomeTodayScheduleSectionState
    extends ConsumerState<HomeTodayScheduleSection> {
  bool _navigating = false;

  Future<void> _navigate(DateTime date, {int? boundary}) async {
    if (_navigating) return;
    _navigating = true;
    final epoch = ref.read(dataSessionEpochProvider);
    final originalSemester = ref.read(currentSemesterIdProvider);
    try {
      if (!ref.read(semesterCatalogProvider).hasValue) {
        await ref.read(semesterCatalogProvider.future);
      }
      if (!mounted || ref.read(dataSessionEpochProvider) != epoch) return;
      final navigation = ref.read(scheduleSemesterNavigationProvider);
      final currentTerm =
          navigation.datesFor(originalSemester) ??
          navigation.termOn(ref.read(homeScheduleBrowseDateProvider));
      final adjacent = boundary != null && currentTerm != null
          ? navigation.adjacent(currentTerm.id, boundary)
          : null;
      final target = boundary == null
          ? navigation.termOn(date)
          : navigation.datesFor(adjacent?.id);
      if (boundary == null &&
          target == null &&
          currentTerm != null &&
          !currentTerm.contains(date)) {
        _message('该日期的学期信息尚未确定');
        return;
      }
      if (boundary != null && target == null) {
        _message(
          adjacent == null
              ? '暂无相邻学期信息'
              : '${semesterLabel(adjacent.id)}的起止日期待确认',
        );
        return;
      }
      if (target != null && target.id != originalSemester) {
        final accepted = await confirmScheduleSemesterChange(
          context,
          semesterId: target.id,
          home: true,
          direction: boundary,
        );
        if (!accepted ||
            !mounted ||
            ref.read(dataSessionEpochProvider) != epoch ||
            ref.read(currentSemesterIdProvider) != originalSemester) {
          return;
        }
        final result = await ref
            .read(syncStateProvider.notifier)
            .selectSemester(target.id, waitForRefresh: false);
        if (!mounted || ref.read(dataSessionEpochProvider) != epoch) return;
        if (ref.read(currentSemesterIdProvider) != target.id) {
          if (result.errorMessage != null) _message(result.errorMessage!);
          return;
        }
      }
      final destination = boundary != null && target != null
          ? navigation.boundaryDate(target, boundary)
          : date;
      ref.read(homeScheduleSelectedDateProvider.notifier).state =
          DateUtils.isSameDay(destination, ref.read(homeScheduleTodayProvider))
          ? null
          : destination;
    } catch (_) {
      if (mounted) _message('暂时无法切换日期，请重试');
    } finally {
      _navigating = false;
    }
  }

  void _message(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    if (!shouldShowHomeTodayScheduleSection(ref.watch(authProvider))) {
      return const SizedBox.shrink();
    }
    final today = ref.watch(homeScheduleTodayProvider);
    final selected = ref.watch(homeScheduleBrowseDateProvider);
    final navigation = ref.watch(scheduleSemesterNavigationProvider);
    final term =
        navigation.datesFor(ref.watch(currentSemesterIdProvider)) ??
        navigation.termOn(selected);
    final days = ref.watch(homeScheduleVisibleDaysProvider);
    final asyncState = ref.watch(homeScheduleProvider).unwrapPrevious();
    final state = asyncState.valueOrNull;
    final current = state?.snapshot.days.first.dateKey == days.first.dateKey
        ? state
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ScheduleBrowser(
        days: days,
        today: today,
        selectedDate: selected,
        onDateSelected: _navigate,
        firstDate: term == null ? null : DateTime.parse(term.start),
        lastDate: term == null ? null : DateTime.parse(term.end),
        onBoundary: (direction) => _navigate(selected, boundary: direction),
        snapshot: current?.snapshot ?? emptyScheduleSnapshot(days),
        isLoading: asyncState.isLoading || (current?.isRefreshing ?? false),
        hasCalendarData: current?.hasCalendarData ?? false,
        failure:
            current?.failure ??
            (asyncState.hasError ? ScheduleFailure.storage : null),
        onOpenCourse: (id) => context.push(Routes.courseDetail(id)),
        onOpenWeek: () => showScheduleDialog(
          context,
          initialDate: today,
          onOpenCourse: (id) => context.push(Routes.courseDetail(id)),
        ),
      ),
    );
  }
}
