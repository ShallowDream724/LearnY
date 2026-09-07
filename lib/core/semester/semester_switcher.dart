import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/providers.dart';
import '../providers/sync_provider.dart';
import '../router/router.dart';
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

class SemesterToolbar extends ConsumerWidget {
  const SemesterToolbar({
    super.key,
    this.inRail = false,
    this.iconOnly = false,
  });

  final bool inRail;
  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(currentSemesterIdProvider);
    final identity = selected == null
        ? null
        : SemesterIdentity.tryParse(selected);
    final sync = ref.watch(syncStateProvider);
    final busy = sync.status == SyncStatus.syncing;
    final message =
        sync.errorMessage ?? (sync.syncWarnings.isNotEmpty ? '部分内容未能更新' : null);

    Future<void> selectSemester() async {
      final id = await showSemesterPicker(context, selectedId: selected);
      if (id == null || id == selected || !context.mounted) return;
      if (GoRouterState.of(context).uri.path.startsWith('/courses/')) {
        context.go(Routes.courses);
      }
      unawaited(ref.read(syncStateProvider.notifier).selectSemester(id));
    }

    final selector = iconOnly
        ? IconButton(
            tooltip: semesterLabel(selected),
            onPressed: selectSemester,
            icon: const Icon(Icons.calendar_month_outlined, size: 20),
          )
        : TextButton.icon(
            onPressed: selectSemester,
            icon: const Icon(Icons.calendar_month_outlined, size: 17),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    inRail && identity != null
                        ? '${identity.startYear}-${identity.endYear}\n${identity.termLabel}学期'
                        : semesterLabel(selected),
                    maxLines: inRail ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const Icon(Icons.expand_more, size: 16),
              ],
            ),
          );
    final actions = <Widget>[
      if (message != null)
        IconButton(
          tooltip: message,
          icon: Icon(
            Icons.error_outline,
            size: 19,
            color: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('同步状态'),
              content: SingleChildScrollView(
                child: Text(
                  [
                    if (sync.errorMessage != null) sync.errorMessage!,
                    ...sync.syncWarnings,
                  ].join('\n'),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                ),
              ],
            ),
          ),
        ),
      IconButton(
        tooltip: busy ? '正在刷新' : '刷新当前学期',
        onPressed: busy
            ? null
            : () => ref.read(syncStateProvider.notifier).syncAll(force: true),
        icon: busy
            ? const SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, size: 19),
      ),
    ];
    if (inRail) {
      return SizedBox(
        width: iconOnly ? 64 : 184,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            selector,
            Wrap(alignment: WrapAlignment.center, children: actions),
          ],
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Expanded(
                child: Align(alignment: Alignment.centerLeft, child: selector),
              ),
              ...actions,
            ],
          ),
        ),
      ),
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
                                : semester.id == official
                                ? const Text('当前学期')
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
