import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_surfaces.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/file_type_utils.dart';
import '../../core/files/file_cache_actions.dart';
import '../../core/files/file_models.dart';
import '../../core/providers/preferences_providers.dart';
import '../../core/router/router.dart';
import '../../core/services/file_cache_service.dart';
import 'widgets/file_type_mark.dart';

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});
  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  static const _cacheLimitOptions = <int?>[200, 500, 1024, null];
  List<CachedAssetListItem>? _cachedFiles;
  final _deletingAssets = <String>{};
  int _totalSize = 0;
  bool _loading = true;
  bool _updatingLimit = false;
  bool _clearingAll = false;
  String? _loadError;
  bool get _isBusy =>
      _loading || _updatingLimit || _clearingAll || _deletingAssets.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _applySnapshot(FileCacheSnapshot snapshot) {
    setState(() {
      _cachedFiles = snapshot.files;
      _totalSize = snapshot.totalSizeBytes;
      _loading = false;
      _loadError = null;
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final snapshot = await ref.read(fileCacheActionsProvider).loadSnapshot();
      if (!mounted) return;
      _applySnapshot(snapshot);
      _showPolicyResult(snapshot, userInitiated: false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '无法读取本地文件';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedLimitMb = ref.watch(fileCacheLimitMbProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件管理'),
        actions: [
          IconButton(
            tooltip: '刷新本地文件',
            onPressed: _isBusy ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (_cachedFiles?.isNotEmpty == true)
            IconButton(
              tooltip: '清除全部缓存',
              onPressed: _isBusy ? null : _confirmClearAll,
              icon: _clearingAll
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: ReadingWidth(
        maxWidth: 960,
        child: _cachedFiles == null && _loading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : _cachedFiles == null && _loadError != null
            ? AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: _loadError!,
                action: FilledButton.tonalIcon(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              )
            : CustomScrollView(
                key: const PageStorageKey('managed-files'),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_loading)
                            const LinearProgressIndicator(minHeight: 2),
                          if (_loadError != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _loadError!,
                                    style: TextStyle(color: c.subtitle),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _loadData,
                                  child: const Text('重试'),
                                ),
                              ],
                            ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _formatSize(_totalSize),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.headlineSmall,
                                    ),
                                    Text(
                                      '${_cachedFiles?.length ?? 0} 个本地文件',
                                      style: TextStyle(color: c.subtitle),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Text(
                            '缓存容量上限',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final option in _cacheLimitOptions)
                                ChoiceChip(
                                  label: Text(_formatLimitLabel(option)),
                                  selected: option == selectedLimitMb,
                                  onSelected: _isBusy
                                      ? null
                                      : (_) => _updateCacheLimit(option),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _updatingLimit
                                ? '正在整理缓存...'
                                : selectedLimitMb == null
                                ? '已下载文件保留至手动清理。'
                                : '超过上限时，自动清理最久未访问的文件。',
                            style: TextStyle(color: c.subtitle),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_cachedFiles?.isNotEmpty != true)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: Icons.folder_open_rounded,
                        title: '暂无本地文件',
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          '已下载',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.builder(
                        itemCount: _cachedFiles!.length,
                        itemBuilder: (context, index) {
                          final file = _cachedFiles![index];
                          final type = FileTypeUtils.extractExt(
                            file.title,
                            file.fileType,
                          );
                          final busy =
                              _clearingAll ||
                              _deletingAssets.contains(file.assetKey);
                          return Padding(
                            key: ValueKey(file.assetKey),
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Material(
                              color: c.surface.withValues(alpha: 0.75),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.only(
                                  left: 14,
                                  right: 4,
                                ),
                                leading: FileTypeMark(
                                  extension: type,
                                  width: 38,
                                ),
                                title: Text(
                                  file.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  [
                                    if (file.courseName.isNotEmpty)
                                      file.courseName,
                                    _formatSize(file.diskSizeBytes),
                                  ].join(' · '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: file.canOpenDetail
                                    ? () => context.push(
                                        Routes.fileDetailFromData(
                                          file.routeData!,
                                        ),
                                      )
                                    : null,
                                trailing: IconButton(
                                  tooltip: '删除本地缓存',
                                  onPressed: _isBusy
                                      ? null
                                      : () => _confirmDeleteFile(file),
                                  icon: busy
                                      ? const SizedBox.square(
                                          dimension: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline_rounded,
                                        ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Future<void> _updateCacheLimit(int? limitMb) async {
    if (_updatingLimit || ref.read(fileCacheLimitMbProvider) == limitMb) return;
    setState(() => _updatingLimit = true);
    try {
      final snapshot = await ref
          .read(fileCacheActionsProvider)
          .updateLimit(limitMb);
      if (!mounted) return;
      _applySnapshot(snapshot);
      _showPolicyResult(
        snapshot,
        userInitiated: true,
        selectedLimitMb: limitMb,
      );
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '缓存策略更新失败');
    } finally {
      if (mounted) setState(() => _updatingLimit = false);
    }
  }

  void _showPolicyResult(
    FileCacheSnapshot snapshot, {
    required bool userInitiated,
    int? selectedLimitMb,
  }) {
    final result = snapshot.policyResult;
    if (result == null) return;
    final count = result.evictedAssetKeys.length;
    if (count > 0) {
      AppToast.showInfo(
        context,
        message: '已清理 $count 个旧文件，释放 ${_formatSize(result.evictedBytes)}',
      );
    } else if (userInitiated) {
      AppToast.showSuccess(
        context,
        message: '缓存上限已设为 ${_formatLimitLabel(selectedLimitMb)}',
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除所有缓存'),
        content: Text(
          '将删除 ${_cachedFiles?.length ?? 0} 个已下载文件（${_formatSize(_totalSize)}），释放存储空间。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _clearingAll = true);
    try {
      await ref.read(fileCacheActionsProvider).clearAll();
      await _loadData();
      if (mounted) AppToast.showSuccess(context, message: '缓存已清除');
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '缓存清除失败');
    } finally {
      if (mounted) setState(() => _clearingAll = false);
    }
  }

  Future<void> _confirmDeleteFile(CachedAssetListItem file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除本地缓存'),
        content: Text(
          '将删除「${file.title}」的本地缓存（${_formatSize(file.diskSizeBytes)}）。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deletingAssets.add(file.assetKey));
    try {
      await ref.read(fileCacheActionsProvider).clearAsset(file.assetKey);
      await _loadData();
      if (mounted) AppToast.showSuccess(context, message: '文件缓存已删除');
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '文件缓存删除失败');
    } finally {
      if (mounted) setState(() => _deletingAssets.remove(file.assetKey));
    }
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatLimitLabel(int? limitMb) => limitMb == null
      ? '无限制'
      : limitMb >= 1024
      ? '${limitMb ~/ 1024} GB'
      : '$limitMb MB';
}
