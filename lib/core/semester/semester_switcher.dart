import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../providers/sync_provider.dart';
import '../router/router.dart';
import '../design/responsive.dart';
import '../design/app_materials.dart';
import '../utils/china_time.dart';
import '../sync/sync_operation.dart';
import 'semester_models.dart';
import 'semester_repository.dart';

Future<String?> showSemesterPicker(
  BuildContext context, {
  required String? selectedId,
  bool requireCalendarDates = false,
}) {
  final container = ProviderScope.containerOf(context);
  return showDialog<String>(
    context: context,
    builder: (_) => UncontrolledProviderScope(
      container: container,
      child: _SemesterDialog(
        selectedId: selectedId,
        requireCalendarDates: requireCalendarDates,
      ),
    ),
  );
}

Future<void> _selectLearningSemester(
  BuildContext context,
  WidgetRef ref,
) async {
  final selected = ref.read(currentSemesterIdProvider);
  final id = await showSemesterPicker(context, selectedId: selected);
  if (id == null || id == selected || !context.mounted) return;
  if (GoRouterState.of(context).uri.path.startsWith('/courses/')) {
    context.go(Routes.courses);
  }
  unawaited(
    ref
        .read(syncStateProvider.notifier)
        .selectSemester(id, waitForRefresh: false),
  );
}

/// The learning scope occupies the existing title area on compact screens.
double semesterToolbarHeight(BuildContext context) {
  if (shouldShowRail(context)) return 64;
  final scaler = MediaQuery.textScalerOf(context);
  return (scaler.scale(20) * 1.4 + scaler.scale(12) * 1.5 + 8).clamp(
    64,
    double.infinity,
  );
}

class SemesterPageTitle extends ConsumerWidget {
  const SemesterPageTitle({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (shouldShowRail(context)) return Text(title);
    final selected = ref.watch(currentSemesterIdProvider);
    return Tooltip(
      message: '切换浏览学期',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _selectLearningSemester(context, ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      semesterLabel(selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SemesterSelector extends ConsumerWidget {
  const SemesterSelector({super.key, this.iconOnly = false});
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(currentSemesterIdProvider);
    final identity = selected == null
        ? null
        : SemesterIdentity.tryParse(selected);

    return Tooltip(
      message: semesterLabel(selected),
      child: iconOnly
          ? IconButton(
              tooltip: semesterLabel(selected),
              onPressed: () => _selectLearningSemester(context, ref),
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
            )
          : TextButton(
              onPressed: () => _selectLearningSemester(context, ref),
              style: TextButton.styleFrom(
                alignment: Alignment.centerLeft,
                foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      identity != null
                          ? '${identity.startYear}-${identity.endYear} ${identity.termLabel}'
                          : semesterLabel(selected),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 16),
                ],
              ),
            ),
    );
  }
}

class SemesterSyncControl extends ConsumerStatefulWidget {
  const SemesterSyncControl({
    super.key,
    this.showLabel = false,
    this.onRefresh,
    this.refreshTooltip = '刷新当前学期',
  });
  final bool showLabel;
  final Future<void> Function()? onRefresh;
  final String refreshTooltip;

  @override
  ConsumerState<SemesterSyncControl> createState() =>
      _SemesterSyncControlState();
}

class _SemesterSyncControlState extends ConsumerState<SemesterSyncControl> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final callback = widget.onRefresh;
      if (callback != null) {
        await callback();
      } else {
        await ref.read(syncStateProvider.notifier).syncAll(force: true);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sync = ref.watch(syncStateProvider);
    final busy = _refreshing || sync.status == SyncStatus.syncing;
    final failed =
        sync.status == SyncStatus.error ||
        sync.status == SyncStatus.sessionExpired;
    final partial = !failed && sync.syncWarnings.isNotEmpty;
    final hasIssue = failed || partial;
    final label = busy
        ? '正在更新'
        : failed
        ? '更新失败'
        : partial
        ? '部分内容待更新'
        : sync.lastSynced == null
        ? '尚未更新'
        : '已更新';
    void showStatus() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sync.lastSynced != null)
                  Text(
                    '最近更新 ${formatMonthDayHourMinuteInChina(sync.lastSynced!)}',
                  ),
                if (partial)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('可用内容已更新，以下项目仍保留上次的数据。'),
                  ),
                if (sync.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(sync.errorMessage!),
                  ),
                for (final warning
                    in sync.syncWarnings
                        .map((warning) => warning.split(' (').first)
                        .toSet())
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(warning),
                  ),
                if (sync.syncWarnings.any((warning) => warning.contains(' (')))
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('错误详情'),
                    children: [
                      SelectableText(
                        sync.syncWarnings.join('\n\n'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _refresh();
            },
            child: const Text('重试'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showLabel)
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        IconButton(
          tooltip: busy
              ? '正在刷新'
              : hasIssue
              ? '查看同步问题'
              : widget.refreshTooltip,
          onPressed: busy
              ? null
              : hasIssue
              ? showStatus
              : _refresh,
          icon: busy
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  failed
                      ? Icons.error_outline
                      : partial
                      ? Icons.sync_problem_outlined
                      : Icons.refresh,
                  color: failed
                      ? Theme.of(context).colorScheme.error
                      : partial
                      ? StudyPalette.of(context, StudyTone.ochre).accent
                      : null,
                  size: 19,
                ),
        ),
      ],
    );
  }
}

class _SemesterDialog extends ConsumerStatefulWidget {
  const _SemesterDialog({
    required this.selectedId,
    this.requireCalendarDates = false,
  });
  final String? selectedId;
  final bool requireCalendarDates;

  @override
  ConsumerState<_SemesterDialog> createState() => _SemesterDialogState();
}

class _SemesterDialogState extends ConsumerState<_SemesterDialog> {
  bool _loading = false;
  String? _error;
  SyncOperation? _operation;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
  }

  Future<void> _refresh() async {
    if (!mounted || _loading) return;
    final owner = ref.read(authProvider).username;
    final epoch = ref.read(dataSessionEpochProvider);
    final operation = SyncOperation(
      isCurrent: () =>
          mounted &&
          ref.read(authProvider).username == owner &&
          ref.read(dataSessionEpochProvider) == epoch,
    );
    _operation = operation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(semesterRepositoryProvider)
          .refreshCatalog(ensureActive: operation.ensureActive)
          .timeout(const Duration(seconds: 20));
      if (mounted) setState(() => _error = result.warning);
    } catch (_) {
      if (mounted) setState(() => _error = '学期列表未能更新，可选择已保存的学期');
    } finally {
      operation.cancel();
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _operation?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final semesters = ref.watch(semesterCatalogProvider);
    final selected = widget.selectedId;
    final calendar = ref.watch(academicCalendarProvider);
    final official = ref.watch(serverCurrentSemesterIdProvider).valueOrNull;
    final teaching = ref.watch(currentTeachingSemesterIdProvider);
    return AlertDialog(
      title: Row(
        children: [
          const Expanded(child: Text('选择学期')),
          IconButton(
            tooltip: '更新学期列表',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: [
            SizedBox(
              height: 3,
              child: _loading ? const LinearProgressIndicator() : null,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Expanded(
              child: semesters.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Center(child: Text('无法读取学期列表')),
                data: (items) => items.isEmpty
                    ? const Center(child: Text('暂无学期信息'))
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final semester = items[index];
                          final datesAvailable =
                              !widget.requireCalendarDates ||
                              calendar.datesFor(semester) != null;
                          return ListTile(
                            enabled: datesAvailable,
                            selected: semester.id == selected,
                            title: Text(semesterLabel(semester.id)),
                            subtitle: !datesAvailable
                                ? const Text('学期起止日期待确认')
                                : semester.id == teaching
                                ? const Text('当前教学学期')
                                : semester.id == official
                                ? const Text('网络学堂当前学期')
                                : null,
                            trailing: semester.id == selected
                                ? const Icon(Icons.check)
                                : null,
                            onTap: datesAvailable
                                ? () => Navigator.pop(context, semester.id)
                                : null,
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
      ],
    );
  }
}
