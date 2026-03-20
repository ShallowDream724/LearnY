/// File manager screen — local storage management.
///
/// Accessed from Profile > 文件管理.
/// Shows: total cache size, per-course breakdown, individual file cleanup.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/services/file_cache_service.dart';
import 'file_detail_screen.dart' show fileIcon, fileColor;

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class FileManagerScreen extends ConsumerStatefulWidget {
  const FileManagerScreen({super.key});

  @override
  ConsumerState<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends ConsumerState<FileManagerScreen> {
  List<CachedFileInfo>? _cachedFiles;
  int _totalSize = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final service = ref.read(fileCacheServiceProvider);
    final files = await service.getCachedFiles();
    final size = await service.getTotalCacheSize();
    if (mounted) {
      setState(() {
        _cachedFiles = files;
        _totalSize = size;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

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
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final c = context.colors;
    final infoColor = context.isDark ? AppColors.info : const Color(0xFF007AFF);

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
                final ext = file.fileType.isNotEmpty
                    ? file.fileType.toLowerCase()
                    : '';
                final color = fileColor(ext);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child:
                      Container(
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
                                fileIcon(ext),
                                color: color,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                                    _formatSize(file.diskSizeBytes),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: c.subtitle,
                                    ),
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
              final service = ref.read(fileCacheServiceProvider);
              await service.clearAllCache();
              await _loadData();
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('缓存已清除')));
              }
            },
            child: const Text('清除', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFile(CachedFileInfo file) {
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
              final service = ref.read(fileCacheServiceProvider);
              await service.clearFile(file.fileId);
              await _loadData();
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
}
