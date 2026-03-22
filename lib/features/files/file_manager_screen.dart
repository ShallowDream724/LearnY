// File manager screen — local storage management.
//
// Accessed from Profile > 文件管理.
// Shows: total cache size, per-course breakdown, individual file cleanup.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/file_type_utils.dart';
import '../../core/files/file_cache_actions.dart';
import '../../core/files/file_models.dart';
import '../../core/providers/preferences_providers.dart';
import '../../core/router/router.dart';
import '../../core/services/file_cache_service.dart';

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  static const List<int?> _cacheLimitOptions = [200, 500, 1024, null];

  List<CachedAssetListItem>? _cachedFiles;
  int _totalSize = 0;
  bool _loading = true;
  bool _updatingLimit = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final snapshot = await ref.read(fileCacheActionsProvider).loadSnapshot();
    if (mounted) {
      setState(() {
        _cachedFiles = snapshot.files;
        _totalSize = snapshot.totalSizeBytes;
        _loading = false;
      });

      _showPolicyResult(snapshot, userInitiated: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final selectedLimitMb = ref.watch(fileCacheLimitMbProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: const Text(
          '文件管理',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_cachedFiles != null && _cachedFiles!.isNotEmpty)
            TextButton(
              onPressed: _confirmClearAll,
              child: const Text(
                '清除全部',
                style: TextStyle(color: AppColors.error, fontSize: 14),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _buildContent(selectedLimitMb),
    );
  }

  Widget _buildContent(int? selectedLimitMb) {
    final c = context.colors;
    final infoColor = c.infoAccent;

    return CustomScrollView(
      slivers: [
        // Stats card
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: infoColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.storage_rounded,
                      color: infoColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '已缓存文件',
                        style: TextStyle(fontSize: 13, color: c.subtitle),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _formatSize(_totalSize),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${_cachedFiles?.length ?? 0} 个文件',
                            style: TextStyle(fontSize: 13, color: c.subtitle),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _buildCachePolicyCard(
              accentColor: infoColor,
              selectedLimitMb: selectedLimitMb,
            ).animate().fadeIn(delay: 60.ms, duration: 300.ms),
          ),
        ),

        // File list
        if (_cachedFiles == null || _cachedFiles!.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 48,
                    color: c.subtitle.withAlpha(100),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '没有缓存文件',
                    style: TextStyle(color: c.subtitle, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '下载的文件会显示在这里',
                    style: TextStyle(
                      color: c.subtitle.withAlpha(150),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final file = _cachedFiles![index];
                final ext = FileTypeUtils.extractExt(file.title, file.fileType);
                final color = FileTypeUtils.color(ext);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child:
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: file.canOpenDetail
                              ? () => context.push(
                                  Routes.fileDetailFromData(file.routeData!),
                                )
                              : null,
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
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: color.withAlpha(20),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: Icon(
                                    FileTypeUtils.icon(ext),
                                    color: color,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        file.title,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: c.text,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _metadataLabel(file),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: c.subtitle,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20,
                                  ),
                                  color: c.subtitle,
                                  onPressed: () => _confirmDeleteFile(file),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: index * 30),
                        duration: 200.ms,
                      ),
                );
              }, childCount: _cachedFiles!.length),
            ),
          ),
      ],
    );
  }

  Widget _buildCachePolicyCard({
    required Color accentColor,
    required int? selectedLimitMb,
  }) {
    final c = context.colors;
    final description = _updatingLimit
        ? '正在整理缓存...'
        : selectedLimitMb == null
        ? '当前不限制缓存容量，已下载内容会保留到你手动清理。'
        : '超过 ${_formatLimitLabel(selectedLimitMb)} 时，会自动清理最久未访问的旧文件。';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_delete_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动缓存清理',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '限制总缓存容量，保持文件系统轻量可控',
                      style: TextStyle(fontSize: 12, color: c.subtitle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          IgnorePointer(
            ignoring: _updatingLimit,
            child: Opacity(
              opacity: _updatingLimit ? 0.7 : 1,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _cacheLimitOptions)
                    _buildLimitChip(
                      value: option,
                      isSelected: option == selectedLimitMb,
                      accentColor: accentColor,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: 180.ms,
            child: Text(
              description,
              key: ValueKey(description),
              style: TextStyle(fontSize: 12, color: c.subtitle),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLimitChip({
    required int? value,
    required bool isSelected,
    required Color accentColor,
  }) {
    final c = context.colors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _updateCacheLimit(value),
        child: AnimatedContainer(
          duration: 160.ms,
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? accentColor.withAlpha(18) : c.bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? accentColor.withAlpha(120) : c.border,
              width: 0.8,
            ),
          ),
          child: Text(
            _formatLimitLabel(value),
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? accentColor : c.text,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateCacheLimit(int? limitMb) async {
    if (_updatingLimit || ref.read(fileCacheLimitMbProvider) == limitMb) {
      return;
    }

    setState(() => _updatingLimit = true);

    try {
      final snapshot = await ref
          .read(fileCacheActionsProvider)
          .updateLimit(limitMb);
      if (!mounted) return;

      setState(() {
        _cachedFiles = snapshot.files;
        _totalSize = snapshot.totalSizeBytes;
        _loading = false;
        _updatingLimit = false;
      });

      _showPolicyResult(
        snapshot,
        userInitiated: true,
        selectedLimitMb: limitMb,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _updatingLimit = false);
      AppToast.showError(context, message: '缓存策略更新失败');
    }
  }

  void _showPolicyResult(
    FileCacheSnapshot snapshot, {
    required bool userInitiated,
    int? selectedLimitMb,
  }) {
    final result = snapshot.policyResult;
    if (result == null) {
      return;
    }

    final evictedCount = result.evictedAssetKeys.length;
    if (evictedCount > 0) {
      final limitLabel = _formatLimitLabel(
        selectedLimitMb ?? _limitMbFromBytes(result.limitBytes),
      );
      final releasedText = result.evictedBytes > 0
          ? '，释放 ${_formatSize(result.evictedBytes)}'
          : '';
      AppToast.showInfo(
        context,
        message: '已按 $limitLabel 上限自动清理 $evictedCount 个旧文件$releasedText',
      );
      return;
    }

    if (!userInitiated) {
      return;
    }

    final message = selectedLimitMb == null
        ? '缓存上限已设为无限制'
        : '缓存上限已设为 ${_formatLimitLabel(selectedLimitMb)}';
    AppToast.showSuccess(context, message: message);
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除所有缓存'),
        content: Text(
          '将删除 ${_cachedFiles?.length ?? 0} 个已下载文件'
          '（${_formatSize(_totalSize)}），释放存储空间。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(fileCacheActionsProvider).clearAll();
              await _loadData();
              if (mounted) {
                AppToast.showSuccess(context, message: '缓存已清除');
              }
            },
            child: const Text('清除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(CachedAssetListItem file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除文件'),
        content: Text(
          '将删除「${file.title}」的本地缓存'
          '（${_formatSize(file.diskSizeBytes)}）',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(fileCacheActionsProvider)
                  .clearAsset(file.assetKey);
              await _loadData();
              if (mounted) {
                AppToast.showSuccess(context, message: '文件缓存已删除');
              }
            },
            child: const Text('删除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatLimitLabel(int? limitMb) {
    if (limitMb == null) {
      return '无限制';
    }
    if (limitMb >= 1024) {
      final gb = limitMb / 1024;
      return gb == gb.roundToDouble()
          ? '${gb.toStringAsFixed(0)} GB'
          : '${gb.toStringAsFixed(1)} GB';
    }
    return '$limitMb MB';
  }

  static int? _limitMbFromBytes(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return null;
    }
    return bytes ~/ (1024 * 1024);
  }

  static String _metadataLabel(CachedAssetListItem file) {
    final parts = <String>[
      if (file.courseName.isNotEmpty) file.courseName,
      _formatSize(file.diskSizeBytes),
    ];
    return parts.join(' · ');
  }
}
