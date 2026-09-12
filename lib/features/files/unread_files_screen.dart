import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart' as db;
import '../../core/design/app_surfaces.dart';
import '../../core/design/app_materials.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/cooldown_toast.dart';
import '../../core/design/file_type_utils.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/swipe_to_read.dart';
import '../../core/design/animated_data_list.dart';
import '../../core/design/read_action_feedback.dart';
import '../../core/files/file_models.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_models.dart';
import '../../core/router/router.dart';
import '../../core/sync/sync_actions.dart';
import '../courses/providers/course_workbench_repository.dart';
import 'providers/file_queries.dart';
import 'widgets/file_card.dart';
import 'widgets/file_search_field.dart';
import 'widgets/file_type_filter_button.dart';

enum _SortMode { byTime, byCourse }

class UnreadFilesScreen extends ConsumerStatefulWidget {
  const UnreadFilesScreen({super.key});
  @override
  ConsumerState<UnreadFilesScreen> createState() => _UnreadFilesScreenState();
}

class _UnreadFilesScreenState extends ConsumerState<UnreadFilesScreen> {
  final _searchController = TextEditingController();
  final _collapsedCourses = <String>{};
  _SortMode _sort = _SortMode.byTime;
  String _query = '';
  String? _typeFilter;
  bool _refreshing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final state =
          (await ref.read(syncActionsProvider).refreshFilesOnly()).state;
      if (mounted && state.status == SyncStatus.cooldown) {
        CooldownToast.show(context, seconds: state.cooldownSeconds);
      }
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '文件刷新失败');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _typeFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final files = ref.watch(unreadFilesProvider);
    final courseNames = ref.watch(fileCourseNameMapProvider).valueOrNull ?? {};
    final coursePreferences =
        ref.watch(courseDisplayPrefsProvider).valueOrNull ??
        const <db.CourseDisplayPref>[];
    final coursePreferencesById = {
      for (final preference in coursePreferences)
        preference.courseId: preference,
    };
    final allFiles = files.valueOrNull ?? const <db.CourseFile>[];
    final actions = ref.read(learningDataActionsProvider);
    final typeCounts = <String, int>{};
    for (final file in allFiles) {
      final type = FileTypeUtils.extractExt(file.title, file.fileType);
      if (type.isNotEmpty) {
        typeCounts.update(type, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('未读文件'),
        actions: [
          IconButton(
            tooltip: '刷新文件',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ReadingWidth(
        maxWidth: 960,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: FileSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (allFiles.isNotEmpty || _typeFilter != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<_SortMode>(
                      segments: const [
                        ButtonSegment(
                          value: _SortMode.byTime,
                          label: Text('时间'),
                        ),
                        ButtonSegment(
                          value: _SortMode.byCourse,
                          label: Text('课程'),
                        ),
                      ],
                      selected: {_sort},
                      showSelectedIcon: false,
                      onSelectionChanged: (values) =>
                          setState(() => _sort = values.single),
                    ),
                    FileTypeFilterButton(
                      currentFilter: _typeFilter,
                      typeCounts: typeCounts,
                      onChanged: (value) => setState(() => _typeFilter = value),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: files.when(
                loading: () => const ListSkeleton(),
                error: (_, _) => AppEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: '未读文件加载失败',
                  action: FilledButton.tonalIcon(
                    onPressed: () => ref.invalidate(unreadFilesProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('重试'),
                  ),
                ),
                data: (entries) {
                  final query = _query.trim().toLowerCase();
                  final filtered = entries.where((file) {
                    final matchesQuery =
                        query.isEmpty ||
                        file.title.toLowerCase().contains(query) ||
                        file.description.toLowerCase().contains(query) ||
                        (courseNames[file.courseId] ?? '')
                            .toLowerCase()
                            .contains(query);
                    return matchesQuery &&
                        (_typeFilter == null ||
                            FileTypeUtils.extractExt(
                                  file.title,
                                  file.fileType,
                                ) ==
                                _typeFilter);
                  }).toList();
                  final hasFilter = query.isNotEmpty || _typeFilter != null;
                  final rows = <Object>[];
                  if (_sort == _SortMode.byTime) {
                    rows.addAll(filtered);
                  } else {
                    final groups = <String, List<db.CourseFile>>{};
                    for (final file in filtered) {
                      groups.putIfAbsent(file.courseId, () => []).add(file);
                    }
                    final ids = groups.keys.toList()
                      ..sort(
                        (a, b) => (courseNames[a] ?? '').compareTo(
                          courseNames[b] ?? '',
                        ),
                      );
                    for (final id in ids) {
                      rows.add((id, groups[id]!.length));
                      if (!_collapsedCourses.contains(id)) {
                        rows.addAll(groups[id]!);
                      }
                    }
                  }
                  return ReadActionFeedback(
                    key: ValueKey((_sort, _typeFilter, query)),
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: AnimatedDataList<Object>(
                        key: PageStorageKey(
                          'unread-${_sort.name}-${_typeFilter ?? 'all'}-${_query.trim()}',
                        ),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        items: rows,
                        itemId: (row) => row is db.CourseFile
                            ? 'file-${row.id}'
                            : 'course-${(row as (String, int)).$1}',
                        emptyBuilder: (context) => AppEmptyState(
                          icon: hasFilter
                              ? Icons.search_off_rounded
                              : Icons.drafts_outlined,
                          title: hasFilter ? '没有符合条件的未读文件' : '暂无未读文件',
                          action: hasFilter
                              ? TextButton(
                                  onPressed: _clearFilters,
                                  child: const Text('清除筛选'),
                                )
                              : null,
                        ),
                        itemBuilder: (context, row) {
                          if (row is (String, int)) {
                            final (id, count) = row;
                            final collapsed = _collapsedCourses.contains(id);
                            final courseName = courseNames[id] ?? '';
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                courseName.isEmpty ? '未知课程' : courseName,
                              ),
                              leading: CourseSeal(
                                courseId: id,
                                size: 24,
                                iconKey: coursePreferencesById[id]?.iconKey,
                                courseName: courseName,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('$count'),
                                  const SizedBox(width: 8),
                                  Icon(
                                    collapsed
                                        ? Icons.expand_more_rounded
                                        : Icons.expand_less_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                              onTap: () => setState(() {
                                if (collapsed) {
                                  _collapsedCourses.remove(id);
                                } else {
                                  _collapsedCourses.add(id);
                                }
                              }),
                            );
                          }
                          final file = row as db.CourseFile;
                          return Padding(
                            key: ValueKey(file.id),
                            padding: const EdgeInsets.only(bottom: 3),
                            child: SwipeToRead(
                              actionId: 'file-${file.id}',
                              removesOnRead: true,
                              onUndo: () => actions.markFileUnread(file.id),
                              onSwipe: () => actions.markFileRead(file.id),
                              child: FileCard(
                                item: FileDetailItem.fromCourseFile(
                                  file,
                                  courseName: courseNames[file.courseId] ?? '',
                                ),
                                hideCourseName: _sort == _SortMode.byCourse,
                                onTap: () => context.push(
                                  Routes.fileDetail(
                                    fileId: file.id,
                                    courseId: file.courseId,
                                    courseName:
                                        courseNames[file.courseId] ?? '',
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
