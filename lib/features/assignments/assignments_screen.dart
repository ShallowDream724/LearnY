import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surfaces.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/homework_reminder_menu.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/router/router.dart';
import '../../core/semester/semester_switcher.dart';
import '../../core/shell/shell_layout_metrics.dart';
import '../../core/sync/sync_actions.dart';
import '../../core/utils/deadline_time.dart';
import 'providers/assignments_providers.dart';
import 'widgets/assignment_list_item.dart';

class AssignmentsScreen extends ConsumerStatefulWidget {
  const AssignmentsScreen({super.key});
  @override
  ConsumerState<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends ConsumerState<AssignmentsScreen> {
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final result =
        (await ref.read(syncActionsProvider).refreshHomeworksOnly()).state;
    if (!mounted) return;
    ref.invalidate(assignmentHomeworksProvider);
    if (result.status == SyncStatus.cooldown) {
      CooldownToast.show(context, seconds: result.cooldownSeconds);
    } else if (result.status == SyncStatus.error) {
      AppToast.showError(
        context,
        message: '作业未能更新',
        actionLabel: '重试',
        onAction: _refresh,
      );
    }
  }

  Future<void> _reminder(
    Homework homework,
    String courseName,
    bool noSubmissionNeeded,
    Offset anchor,
  ) async {
    final action = await showHomeworkReminderMenu(
      context,
      title: homework.title,
      courseName: courseName,
      isNoSubmissionNeeded: noSubmissionNeeded,
      anchor: anchor,
    );
    if (action == null || !mounted) return;
    final value = action == HomeworkReminderMenuAction.markNoSubmissionNeeded;
    Future<void> save(bool next) async {
      try {
        await ref
            .read(homeworkReminderActionsProvider)
            .setNoSubmissionNeeded(homework.id, noSubmissionNeeded: next);
      } catch (_) {
        if (mounted) AppToast.showError(context, message: '提醒设置未能保存');
        rethrow;
      }
    }

    try {
      await save(value);
      if (!mounted) return;
      AppToast.showInfo(
        context,
        message: value ? '已设为无需提交' : '已恢复提交提醒',
        actionLabel: '撤销',
        onAction: () {
          unawaited(save(!value).catchError((Object _) {}));
        },
      );
    } catch (_) {
      /* The failed write already has local feedback. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final semester = ref.watch(currentSemesterIdProvider);
    ref.listen(currentSemesterIdProvider, (previous, next) {
      if (previous != next && _scroll.hasClients) _scroll.jumpTo(0);
    });
    final filter = ref.watch(homeworkFilterProvider);
    final data = ref.watch(assignmentHomeworksProvider);
    final courses =
        ref.watch(assignmentCourseNameMapProvider).valueOrNull ??
        const <String, String>{};
    final noSubmission =
        ref.watch(homeworkNoSubmissionNeededIdsProvider).valueOrNull ??
        const <String>{};
    final now = ref.watch(minuteTickProvider).valueOrNull ?? nowInShanghai();
    final sync = ref.watch(syncStateProvider);
    final syncing = sync.status == SyncStatus.syncing;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final gutter = pageGutterForWidth(
            constraints.maxWidth,
            maxWidth: 1000,
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: CustomScrollView(
              key: PageStorageKey('assignments-$semester'),
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  toolbarHeight: semesterToolbarHeight(context),
                  title: const SemesterPageTitle(title: '作业'),
                  titleSpacing: gutter,
                  actions: [
                    IconButton(
                      tooltip: '刷新作业',
                      onPressed: syncing ? null : _refresh,
                      icon: syncing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 20),
                    ),
                    SizedBox(width: gutter - 8),
                  ],
                ),
                data.when(
                  skipLoadingOnReload: true,
                  skipLoadingOnRefresh: true,
                  loading: () =>
                      const SliverFillRemaining(child: ListSkeleton()),
                  error: (_, _) => SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: '作业暂时无法读取',
                      action: TextButton(
                        onPressed: _refresh,
                        child: const Text('重试'),
                      ),
                    ),
                  ),
                  data: (all) {
                    if (all.isEmpty) {
                      final failed =
                          sync.status == SyncStatus.error ||
                          sync.status == SyncStatus.sessionExpired ||
                          sync.syncWarnings.isNotEmpty;
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: Icons.assignment_outlined,
                          title: semester == null
                              ? '尚未选择学期'
                              : syncing
                              ? '正在同步作业'
                              : failed
                              ? '暂未取得作业'
                              : '这个学期暂无作业',
                          action: failed
                              ? TextButton(
                                  onPressed: _refresh,
                                  child: const Text('重试'),
                                )
                              : null,
                        ),
                      );
                    }
                    final presentation = buildAssignmentsPresentation(
                      homeworks: all,
                      filter: filter,
                      noSubmissionNeededIds: noSubmission,
                      now: now,
                    );
                    return SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        8,
                        gutter,
                        shellContentBottomInset(context),
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: _AssignmentFilters(
                                current: filter,
                                stats: presentation.stats,
                                total: all.length,
                                onChanged: (value) {
                                  ref
                                          .read(homeworkFilterProvider.notifier)
                                          .state =
                                      value;
                                  if (_scroll.hasClients) _scroll.jumpTo(0);
                                },
                              ),
                            ),
                          ),
                          if (presentation.isEmpty)
                            SliverToBoxAdapter(
                              child: AppEmptyState(
                                icon: Icons.filter_list_off,
                                title: '没有符合条件的作业',
                                action: TextButton(
                                  onPressed: () =>
                                      ref
                                          .read(homeworkFilterProvider.notifier)
                                          .state = HomeworkFilter
                                          .all,
                                  child: const Text('查看全部作业'),
                                ),
                              ),
                            )
                          else
                            for (final section in presentation.sections) ...[
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 12,
                                    top: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _groupLabel(section.group),
                                        style: AppTypography.titleMedium
                                            .copyWith(
                                              color:
                                                  section.group ==
                                                      AssignmentTimelineGroup
                                                          .overdue
                                                  ? Theme.of(
                                                      context,
                                                    ).colorScheme.error
                                                  : context.colors.text,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${section.homeworks.length}',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverList.builder(
                                itemCount: section.homeworks.length,
                                itemBuilder: (context, index) {
                                  final homework = section.homeworks[index];
                                  final course =
                                      courses[homework.courseId] ?? '';
                                  final noSubmissionNeeded =
                                      section.group ==
                                      AssignmentTimelineGroup
                                          .noSubmissionNeeded;
                                  return Padding(
                                    key: ValueKey(homework.id),
                                    padding: EdgeInsets.only(
                                      bottom:
                                          index == section.homeworks.length - 1
                                          ? 24
                                          : 8,
                                    ),
                                    child: AssignmentListItem(
                                      homework: homework,
                                      courseName: course,
                                      now: now,
                                      noSubmissionNeeded: noSubmissionNeeded,
                                      onTap: () => context.push(
                                        Routes.homeworkDetail(
                                          homeworkId: homework.id,
                                          courseId: homework.courseId,
                                          courseName: course,
                                        ),
                                      ),
                                      onReminder: (anchor) => _reminder(
                                        homework,
                                        course,
                                        noSubmissionNeeded,
                                        anchor,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

String _groupLabel(AssignmentTimelineGroup group) => switch (group) {
  AssignmentTimelineGroup.overdue => '已超期',
  AssignmentTimelineGroup.thisWeek => '本周截止',
  AssignmentTimelineGroup.nextWeek => '下周截止',
  AssignmentTimelineGroup.later => '之后截止',
  AssignmentTimelineGroup.done => '已完成',
  AssignmentTimelineGroup.noSubmissionNeeded => '无需提交',
};

String _filterLabel(HomeworkFilter filter) => switch (filter) {
  HomeworkFilter.all => '全部',
  HomeworkFilter.pending => '待提交',
  HomeworkFilter.submitted => '已提交',
  HomeworkFilter.graded => '已批改',
  HomeworkFilter.noSubmissionNeeded => '无需提交',
};

class _AssignmentFilters extends StatelessWidget {
  const _AssignmentFilters({
    required this.current,
    required this.stats,
    required this.total,
    required this.onChanged,
  });
  final HomeworkFilter current;
  final AssignmentStats stats;
  final int total;
  final ValueChanged<HomeworkFilter> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final counts = <HomeworkFilter, int>{
        HomeworkFilter.all: total,
        HomeworkFilter.pending: stats.pending,
        HomeworkFilter.submitted: stats.submitted,
        HomeworkFilter.graded: stats.graded,
        HomeworkFilter.noSubmissionNeeded:
            total - stats.pending - stats.submitted - stats.graded,
      };
      if (constraints.maxWidth >= 760 &&
          MediaQuery.textScalerOf(context).scale(14) < 18) {
        return Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<HomeworkFilter>(
            showSelectedIcon: false,
            segments: [
              for (final value in HomeworkFilter.values)
                ButtonSegment(
                  value: value,
                  label: Text('${_filterLabel(value)} ${counts[value]}'),
                ),
            ],
            selected: {current},
            onSelectionChanged: (values) => onChanged(values.single),
          ),
        );
      }
      return Row(
        children: [
          Expanded(
            child: Text(
              stats.pending == 0 ? '待交作业已处理完' : '${stats.pending} 项待提交',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<HomeworkFilter>(
            tooltip: '筛选作业',
            initialValue: current,
            onSelected: onChanged,
            itemBuilder: (_) => [
              for (final value in HomeworkFilter.values)
                CheckedPopupMenuItem(
                  value: value,
                  checked: current == value,
                  child: Text('${_filterLabel(value)}  ${counts[value]}'),
                ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filterLabel(current),
                    style: TextStyle(color: context.colors.infoAccent),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.expand_more, size: 18),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}
