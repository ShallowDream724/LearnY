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

class SemesterToolbar extends ConsumerWidget {
  const SemesterToolbar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(currentSemesterIdProvider);
    final sync = ref.watch(syncStateProvider);
    final busy = sync.status == SyncStatus.syncing;
    final message =
        sync.errorMessage ?? (sync.syncWarnings.isNotEmpty ? '部分内容未能更新' : null);

    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          size: 18,
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                semesterLabel(selected),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.expand_more, size: 18),
                          ],
                        ),
                        onPressed: () async {
                          final id = await showDialog<String>(
                            context: context,
                            builder: (_) => const _SemesterDialog(),
                          );
                          if (id == null ||
                              id == selected ||
                              !context.mounted) {
                            return;
                          }
                          // Leave any semester-specific detail route before switching scope.
                          if (GoRouterState.of(
                            context,
                          ).uri.path.startsWith('/courses/')) {
                            context.go(Routes.courses);
                          }
                          unawaited(
                            ref
                                .read(syncStateProvider.notifier)
                                .selectSemester(id),
                          );
                        },
                      ),
                    ),
                  ),
                  if (message != null)
                    IconButton(
                      tooltip: message,
                      icon: Icon(
                        Icons.error_outline,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('同步状态'),
                          content: SingleChildScrollView(
                            child: Text(
                              [
                                if (sync.errorMessage != null)
                                  sync.errorMessage!,
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
                        : () => ref
                              .read(syncStateProvider.notifier)
                              .syncAll(force: true),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 21),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ),
      ),
    );
  }
}

class _SemesterDialog extends ConsumerStatefulWidget {
  const _SemesterDialog();

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
    final selected = ref.watch(currentSemesterIdProvider);
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
                          return ListTile(
                            selected: semester.id == selected,
                            title: Text(semesterLabel(semester.id)),
                            subtitle: semester.id == official
                                ? const Text('当前学期')
                                : null,
                            trailing: semester.id == selected
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.pop(context, semester.id),
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
