import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/router/router.dart';
import '../../../core/schedule/schedule_models.dart';
import '../../../core/schedule/schedule_projection.dart';
import '../providers/home_schedule_provider.dart';
import '../../auth/widgets/campus_authorization_screen.dart';
import 'schedule_browser.dart';
import 'schedule_dialog.dart';

bool shouldShowHomeTodayScheduleSection(AuthState auth) =>
    auth.canAccessCachedData;

class HomeTodayScheduleSection extends ConsumerWidget {
  const HomeTodayScheduleSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!shouldShowHomeTodayScheduleSection(ref.watch(authProvider))) {
      return const SizedBox.shrink();
    }
    final today = ref.watch(homeScheduleTodayProvider);
    final selected = ref.watch(homeScheduleSelectedDateProvider) ?? today;
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
        onDateSelected: (date) {
          ref.read(homeScheduleSelectedDateProvider.notifier).state =
              DateUtils.isSameDay(date, today) ? null : date;
        },
        snapshot: current?.snapshot ?? emptyScheduleSnapshot(days),
        isLoading: asyncState.isLoading || (current?.isRefreshing ?? false),
        hasCalendarData: current?.hasCalendarData ?? false,
        failure:
            current?.failure ??
            (asyncState.hasError ? ScheduleFailure.storage : null),
        onRetry: () async {
          final refreshed = await ref
              .read(homeScheduleActionsProvider)
              .refresh();
          if (!refreshed && context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('课表刷新失败，请稍后重试')));
          }
        },
        onOpenCourse: (id) => context.push(Routes.courseDetail(id)),
        onAuthorize: () async {
          if (await showCampusAuthorization(context, selected) &&
              context.mounted) {
            await ref.read(homeScheduleActionsProvider).refresh();
          }
        },
        onOpenWeek: () => showScheduleDialog(
          context,
          initialDate: selected,
          onOpenCourse: (id) => context.push(Routes.courseDetail(id)),
        ),
      ),
    );
  }
}
