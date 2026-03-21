import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_toast.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/file_type_utils.dart';
import '../../../core/design/swipe_to_read.dart';
import '../../../core/design/typography.dart';
import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_models.dart';
import '../../../core/router/router.dart';
import '../../files/providers/file_bookmark_providers.dart';
import '../providers/home_schedule_provider.dart';
import '../providers/home_providers.dart';
import 'notification_card.dart';
import 'stat_card.dart';
import 'urgent_deadline_banner.dart';

class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    required this.count,
    required this.color,
  });

  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title, style: AppTypography.headlineSmall.copyWith(color: c.text)),
        const Spacer(),
        if (count > 0)
          Text(
            '$count 项',
            style: AppTypography.bodySmall.copyWith(color: c.tertiary),
          ),
      ],
    );
  }
}

class HomeStatsSection extends ConsumerWidget {
  const HomeStatsSection({super.key, this.onUnreadTap});

  final VoidCallback? onUnreadTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(
      homeDataProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.totalCourses,
                async.valueOrNull!.pendingAssignments,
                async.valueOrNull!.unreadCount,
              ),
      ),
    );
    final favoriteCount =
        ref.watch(bookmarkedFileCountProvider).valueOrNull ?? 0;

    if (stats == null) return const SizedBox.shrink();

    final (totalCourses, pendingAssignments, unreadCount) = stats;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: '课程',
            value: totalCourses.toString(),
            icon: Icons.school_rounded,
            color: AppColors.primary,
            onTap: () => context.go(Routes.courses),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '待交',
            value: pendingAssignments.toString(),
            icon: Icons.assignment_late_rounded,
            color: pendingAssignments > 0
                ? AppColors.warning
                : AppColors.success,
            onTap: () => context.go(Routes.assignments),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '未读',
            value: unreadCount.toString(),
            icon: Icons.notifications_none_rounded,
            color: unreadCount > 0 ? AppColors.unreadBadge : AppColors.success,
            onTap: onUnreadTap,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: StatCard(
            label: '收藏',
            value: favoriteCount.toString(),
            icon: Icons.bookmark_rounded,
            color: AppColors.warning,
            onTap: () => context.push(Routes.favoriteFiles),
          ),
        ),
      ],
    );
  }
}

class HomeUrgentAssignmentsSection extends ConsumerWidget {
  const HomeUrgentAssignmentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignments = ref.watch(
      homeDataProvider.select((async) => async.valueOrNull?.urgentAssignments),
    );

    if (assignments == null || assignments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        UrgentDeadlineBanner(
          assignments: assignments,
          onTap: (hw) => context.push(
            Routes.homeworkDetail(
              homeworkId: hw.id,
              courseId: hw.courseId,
              courseName: hw.courseName,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class HomeTodayScheduleSection extends ConsumerStatefulWidget {
  const HomeTodayScheduleSection({super.key});

  @override
  ConsumerState<HomeTodayScheduleSection> createState() =>
      _HomeTodayScheduleSectionState();
}

class _HomeTodayScheduleSectionState
    extends ConsumerState<HomeTodayScheduleSection>
    with AutomaticKeepAliveClientMixin<HomeTodayScheduleSection> {
  late final PageController _pageController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: ref.read(homeSchedulePageIndexProvider),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authState = ref.watch(authProvider);
    if (!authState.isLoggedIn) {
      return const SizedBox.shrink();
    }

    final scheduleAsync = ref.watch(homeScheduleSnapshotProvider);
    final currentDay = ref.watch(homeScheduleCurrentDayProvider);
    final currentPage = ref.watch(homeSchedulePageIndexProvider);
    final days = ref.watch(homeScheduleVisibleDaysProvider);
    final currentItems =
        scheduleAsync.valueOrNull?.itemsFor(currentDay) ??
        const <TodayScheduleItem>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: buildHomeScheduleSectionTitle(),
          count: currentItems.length,
          color: AppColors.primary,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: _scheduleCardHeight(currentItems),
          child: _SchedulePagerCard(
            pageController: _pageController,
            days: days,
            currentPage: currentPage,
            scheduleAsync: scheduleAsync,
            onPageChanged: (index) {
              ref.read(homeSchedulePageIndexProvider.notifier).state = index;
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class HomeUnreadNotificationsSection extends ConsumerWidget {
  const HomeUnreadNotificationsSection({super.key, this.onBeforeSwipeRead});

  final VoidCallback? onBeforeSwipeRead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(
      homeDataProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.unreadNotifications,
                async.valueOrNull!.unreadCount,
              ),
      ),
    );

    if (data == null) return const SizedBox.shrink();

    final actions = ref.read(learningDataActionsProvider);
    final (notifications, unreadCount) = data;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HomeSectionTitle(
          title: '未读通知',
          count: unreadCount,
          color: AppColors.info,
        ),
        const SizedBox(height: 12),
        if (notifications.isNotEmpty)
          ...notifications.map(
            (notification) => KeyedSubtree(
              key: ValueKey('home_notification_${notification.id}'),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SwipeToRead(
                  key: ValueKey(notification.id),
                  exitOnSwipe: true,
                  onSwipe: () {
                    onBeforeSwipeRead?.call();
                    actions.markNotificationRead(notification.id);
                  },
                  child: NotificationCard(
                    notification: notification,
                    onTap: () {
                      actions.markNotificationRead(notification.id);
                      context.push(
                        Routes.notificationDetail(
                          notificationId: notification.id,
                          courseId: notification.courseId,
                          courseName: notification.courseName,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
              final c = context.colors;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '暂无未读通知',
                  style: AppTypography.bodyMedium.copyWith(color: c.tertiary),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class HomeUnreadFilesSection extends ConsumerStatefulWidget {
  const HomeUnreadFilesSection({super.key});

  @override
  ConsumerState<HomeUnreadFilesSection> createState() =>
      _HomeUnreadFilesSectionState();
}

class _HomeUnreadFilesSectionState
    extends ConsumerState<HomeUnreadFilesSection> {
  final Set<String> _optimisticallyReadIds = <String>{};

  Future<void> _markFileReadOptimistically(FileSummary file) async {
    if (_optimisticallyReadIds.contains(file.id)) return;

    setState(() {
      _optimisticallyReadIds.add(file.id);
    });

    try {
      await ref.read(learningDataActionsProvider).markFileRead(file.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _optimisticallyReadIds.remove(file.id);
      });
      AppToast.showError(
        context,
        message: '标记文件已读失败',
        duration: const Duration(milliseconds: 2600),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(
      homeDataProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.newFiles,
                async.valueOrNull!.totalUnreadFiles,
              ),
      ),
    );

    if (data == null) return const SizedBox.shrink();

    final (allFiles, totalUnreadFiles) = data;
    final visibleFiles = <FileSummary>[];
    var optimisticUnreadReduction = 0;

    for (final file in allFiles) {
      if (_optimisticallyReadIds.contains(file.id)) {
        optimisticUnreadReduction++;
        continue;
      }
      if (visibleFiles.length < 5) {
        visibleFiles.add(file);
      }
    }

    final effectiveTotalUnreadFiles =
        (totalUnreadFiles - optimisticUnreadReduction).clamp(
          0,
          totalUnreadFiles,
        );

    if (visibleFiles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: HomeSectionTitle(
                title: '未读文件',
                count: effectiveTotalUnreadFiles > 5
                    ? 0
                    : effectiveTotalUnreadFiles,
                color: const Color(0xFF7B1FA2),
              ),
            ),
            if (effectiveTotalUnreadFiles > 5) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => context.push(Routes.unreadFiles),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '查看全部($effectiveTotalUnreadFiles)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ...visibleFiles.map(
          (file) => KeyedSubtree(
            key: ValueKey('home_file_${file.id}'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SwipeToRead(
                key: ValueKey(file.id),
                exitOnSwipe: false,
                onSwipe: () {
                  unawaited(_markFileReadOptimistically(file));
                },
                child: HomeNewFileCard(
                  file: file,
                  onTap: () {
                    context.push(
                      Routes.fileDetail(
                        fileId: file.id,
                        courseId: file.courseId,
                        courseName: file.courseName,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class HomeEmptyStateSection extends ConsumerWidget {
  const HomeEmptyStateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(
      homeDataProvider.select(
        (async) => async.valueOrNull == null
            ? null
            : (
                async.valueOrNull!.urgentAssignments.length,
                async.valueOrNull!.unreadNotifications.length,
                async.valueOrNull!.newFiles.length,
              ),
      ),
    );

    if (counts == null) return const SizedBox.shrink();

    final (urgentCount, notificationCount, fileCount) = counts;
    if (urgentCount != 0 || notificationCount != 0 || fileCount != 0) {
      return const SizedBox.shrink();
    }

    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: c.tertiary,
            ),
            const SizedBox(height: 16),
            Text(
              '一切完成',
              style: AppTypography.headlineSmall.copyWith(color: c.tertiary),
            ),
            const SizedBox(height: 4),
            Text(
              '没有紧急事项',
              style: AppTypography.bodyMedium.copyWith(color: c.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeNewFileCard extends StatelessWidget {
  const HomeNewFileCard({super.key, required this.file, this.onTap});

  final FileSummary file;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ext = FileTypeUtils.extractExt(file.title, file.fileType);
    final color = FileTypeUtils.color(ext);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(FileTypeUtils.icon(ext), color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    style: AppTypography.titleMedium.copyWith(color: c.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    file.courseName,
                    style: AppTypography.bodySmall.copyWith(
                      color: c.tertiary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  ext.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  file.size.isNotEmpty ? file.size : '',
                  style: TextStyle(fontSize: 10, color: c.subtitle),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 16, color: c.tertiary),
          ],
        ),
      ),
    );
  }
}

const int _scheduleGridColumnCount = 2;
const int _scheduleMaxVisibleTiles = 6;
const double _scheduleGridTileHeight = 64;
const double _scheduleGridSpacing = 6;
const double _scheduleCardHeaderHeight = 38;
const double _scheduleCardBottomPadding = 4;

double _scheduleCardHeight(List<TodayScheduleItem> items) {
  if (items.isEmpty) {
    return 74;
  }
  final visibleCount = items.length.clamp(1, _scheduleMaxVisibleTiles);
  final columnCount = visibleCount == 1 ? 1 : _scheduleGridColumnCount;
  final visibleRows = ((visibleCount + columnCount - 1) ~/ columnCount).clamp(
    1,
    3,
  );
  return _scheduleCardHeaderHeight +
      visibleRows * _scheduleGridTileHeight +
      (visibleRows - 1) * _scheduleGridSpacing +
      _scheduleCardBottomPadding;
}

class _SchedulePagerCard extends StatelessWidget {
  const _SchedulePagerCard({
    required this.pageController,
    required this.days,
    required this.currentPage,
    required this.scheduleAsync,
    required this.onPageChanged,
  });

  final PageController pageController;
  final List<HomeScheduleDayOption> days;
  final int currentPage;
  final AsyncValue<HomeScheduleSnapshot> scheduleAsync;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final resolvedPage = currentPage.clamp(0, days.length - 1);
    final activeDay = days[resolvedPage];
    final title = activeDay.label == activeDay.weekdayLabel
        ? '${activeDay.weekdayLabel} · ${activeDay.shortDateLabel}'
        : '${activeDay.label} · ${activeDay.weekdayLabel} · ${activeDay.shortDateLabel}';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: AppTypography.labelMedium.copyWith(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                _ScheduleDots(currentPage: resolvedPage, count: days.length),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: pageController,
              onPageChanged: onPageChanged,
              itemCount: days.length,
              itemBuilder: (context, index) {
                final day = days[index];
                final items =
                    scheduleAsync.valueOrNull?.itemsFor(day) ??
                    const <TodayScheduleItem>[];

                if (scheduleAsync.isLoading &&
                    scheduleAsync.valueOrNull == null) {
                  return const _ScheduleLoadingPage();
                }
                return _ScheduleDayPage(day: day, items: items);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleDayPage extends StatelessWidget {
  const _ScheduleDayPage({required this.day, required this.items});

  final HomeScheduleDayOption day;
  final List<TodayScheduleItem> items;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 2, 12, _scheduleCardBottomPadding),
        child: Row(
          children: [
            Icon(Icons.event_available_rounded, size: 16, color: c.tertiary),
            const SizedBox(width: 8),
            Text(
              buildHomeScheduleEmptyLabel(day),
              style: AppTypography.bodyMedium.copyWith(color: c.tertiary),
            ),
          ],
        ),
      );
    }

    final columnCount = items.length == 1 ? 1 : _scheduleGridColumnCount;

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, _scheduleCardBottomPadding),
      physics: items.length > _scheduleMaxVisibleTiles
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      primary: false,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columnCount,
        crossAxisSpacing: 8,
        mainAxisSpacing: _scheduleGridSpacing,
        mainAxisExtent: _scheduleGridTileHeight,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _TodayScheduleTile(item: items[index]);
      },
    );
  }
}

class _ScheduleLoadingPage extends StatelessWidget {
  const _ScheduleLoadingPage();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, _scheduleCardBottomPadding),
      child: Container(
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: c.tertiary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '正在加载课表...',
              style: AppTypography.bodyMedium.copyWith(color: c.tertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayScheduleTile extends StatelessWidget {
  const _TodayScheduleTile({required this.item});

  final TodayScheduleItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasCourseName = item.courseName.isNotEmpty;
    final hasLocation = item.location.isNotEmpty;
    final isNavigable = item.courseId != null && item.courseId!.isNotEmpty;
    final startTime = item.startTime.isNotEmpty ? item.startTime : '待定';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isNavigable
            ? () => context.push(Routes.courseDetail(item.courseId!))
            : null,
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(10, 7, 9, 7),
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(c.isDark ? 36 : 18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      startTime,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        height: 1,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isNavigable)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 15,
                      color: c.tertiary,
                    ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                hasCourseName ? item.courseName : '课程待定',
                style: AppTypography.labelMedium.copyWith(
                  color: c.text,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  height: 1.05,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                hasLocation ? item.location : '地点待定',
                style: AppTypography.bodySmall.copyWith(
                  color: c.tertiary,
                  fontSize: 10.5,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleDots extends StatelessWidget {
  const _ScheduleDots({required this.currentPage, required this.count});

  final int currentPage;
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: List<Widget>.generate(count, (index) {
        final active = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: index == count - 1 ? 0 : 4),
          width: active ? 14 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : c.border,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
