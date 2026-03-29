import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_toast.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/file_type_utils.dart';
import '../../../core/files/file_access_resolver.dart';
import '../../../core/files/file_models.dart';
import '../../../core/files/preview/archive_preview_service.dart';
import '../../../core/files/preview/file_preview_models.dart';
import '../../../core/files/preview/file_preview_preparation_service.dart';

class FilePreviewView extends ConsumerStatefulWidget {
  const FilePreviewView({
    super.key,
    required this.item,
    required this.localPath,
    required this.onOpenExternal,
  });

  final FileDetailItem item;
  final String localPath;
  final VoidCallback onOpenExternal;

  @override
  ConsumerState<FilePreviewView> createState() => _FilePreviewViewState();
}

class _FilePreviewViewState extends ConsumerState<FilePreviewView> {
  late Future<PreparedFilePreview> _previewFuture;

  @override
  void initState() {
    super.initState();
    _previewFuture = _preparePreview();
  }

  @override
  void didUpdateWidget(covariant FilePreviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPath != widget.localPath ||
        oldWidget.item.cacheKey != widget.item.cacheKey) {
      _previewFuture = _preparePreview();
    }
  }

  Future<PreparedFilePreview> _preparePreview() {
    return ref
        .read(filePreviewPreparationServiceProvider)
        .prepare(item: widget.item, localPath: widget.localPath);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreparedFilePreview>(
      future: _previewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _PreparingPreviewView();
        }

        final preview = snapshot.data;
        if (preview == null) {
          return _PreviewUnavailable(
            message: '预览准备失败',
            onOpenExternal: widget.onOpenExternal,
          );
        }

        return switch (preview) {
          PdfPreparedFilePreview() => _PdfPreview(
            filePath: preview.filePath,
            onOpenExternal: widget.onOpenExternal,
          ),
          ImagePreparedFilePreview() => _ImagePreview(
            filePath: preview.filePath,
          ),
          TextPreparedFilePreview() => _TextPreview(
            content: preview.content,
            isTruncated: preview.isTruncated,
          ),
          ArchivePreparedFilePreview() => _ArchivePreview(
            containerItem: widget.item,
            containerLocalPath: widget.localPath,
            preview: preview,
          ),
          UnsupportedPreparedFilePreview() => _PreviewUnavailable(
            message: preview.message,
            onOpenExternal: widget.onOpenExternal,
          ),
        };
      },
    );
  }
}

class _PreparingPreviewView extends StatelessWidget {
  const _PreparingPreviewView();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator.adaptive(strokeWidth: 3),
          ),
          const SizedBox(height: 14),
          Text('正在准备预览...', style: TextStyle(color: c.text, fontSize: 15)),
        ],
      ),
    );
  }
}

class _PreviewUnavailable extends StatelessWidget {
  const _PreviewUnavailable({
    required this.message,
    required this.onOpenExternal,
  });

  final String message;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, size: 52, color: c.subtitle),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.text, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onOpenExternal,
              child: const Text('外部打开'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivePreview extends ConsumerStatefulWidget {
  const _ArchivePreview({
    required this.containerItem,
    required this.containerLocalPath,
    required this.preview,
  });

  final FileDetailItem containerItem;
  final String containerLocalPath;
  final ArchivePreparedFilePreview preview;

  @override
  ConsumerState<_ArchivePreview> createState() => _ArchivePreviewState();
}

class _ArchivePreviewState extends ConsumerState<_ArchivePreview> {
  final TextEditingController _searchController = TextEditingController();
  late ArchivePreparedFilePreview _activePreview;
  String _searchQuery = '';
  String _currentFolder = '';
  bool _extractingAll = false;
  bool _clearingCache = false;
  bool _loadingCachedEntries = false;
  Set<String> _cachedEntries = const <String>{};

  List<ArchivePreviewEntry> get _entries => _activePreview.document.entries;

  @override
  void initState() {
    super.initState();
    _activePreview = widget.preview;
    unawaited(_loadCachedEntries());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ArchivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.containerItem.cacheKey != widget.containerItem.cacheKey) {
      _activePreview = widget.preview;
      _searchController.clear();
      _searchQuery = '';
      _currentFolder = '';
      _cachedEntries = const <String>{};
      unawaited(_loadCachedEntries());
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visibleEntries = _visibleEntries();
    final breadcrumbs = _breadcrumbs();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border(bottom: BorderSide(color: c.border, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ArchiveStatChip(
                      icon: Icons.folder_zip_rounded,
                      label: '${_activePreview.document.fileCount} 个文件',
                    ),
                    const SizedBox(width: 8),
                    _ArchiveStatChip(
                      icon: Icons.data_usage_rounded,
                      label: _formatByteCount(
                        _activePreview.document.uncompressedSizeBytes,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ArchiveStatChip(
                      icon: _loadingCachedEntries
                          ? Icons.hourglass_top_rounded
                          : Icons.download_done_rounded,
                      label: _loadingCachedEntries
                          ? '读取缓存中'
                          : '${_cachedEntries.length} 个已缓存',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.trim();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: '搜索压缩包内文件',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                        filled: true,
                        fillColor: c.bg,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.border, width: 0.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.border, width: 0.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: c.infoAccent, width: 1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _ArchiveActionButton(
                    icon: _extractingAll
                        ? Icons.hourglass_top_rounded
                        : Icons.inventory_2_outlined,
                    label: _extractingAll ? '解压中' : '解压全部',
                    onTap: _extractingAll ? null : _extractAll,
                  ),
                  const SizedBox(width: 8),
                  _ArchiveActionButton(
                    icon: _clearingCache
                        ? Icons.hourglass_top_rounded
                        : Icons.cleaning_services_outlined,
                    label: _clearingCache ? '清理中' : '清理解压缓存',
                    onTap: _clearingCache ? null : _clearExtractedCache,
                  ),
                  if (_activePreview.document.canCompatibilityOpen) ...[
                    const SizedBox(width: 8),
                    PopupMenuButton<_ArchiveOpenModeAction>(
                      tooltip: '压缩包兼容选项',
                      onSelected: (action) {
                        switch (action) {
                          case _ArchiveOpenModeAction.openCompatibility:
                            unawaited(
                              _switchDecodingMode(
                                ArchiveNameDecodingMode.compatibility,
                              ),
                            );
                            break;
                          case _ArchiveOpenModeAction.openStandard:
                            unawaited(
                              _switchDecodingMode(
                                ArchiveNameDecodingMode.standard,
                              ),
                            );
                            break;
                        }
                      },
                      itemBuilder: (context) {
                        return [
                          if (_activePreview.document.nameDecodingMode ==
                              ArchiveNameDecodingMode.standard)
                            PopupMenuItem<_ArchiveOpenModeAction>(
                              value: _ArchiveOpenModeAction.openCompatibility,
                              child: Text(
                                _archiveOpenModeLabel(
                                  _ArchiveOpenModeAction.openCompatibility,
                                ),
                              ),
                            ),
                          if (_activePreview.document.nameDecodingMode ==
                              ArchiveNameDecodingMode.compatibility)
                            PopupMenuItem<_ArchiveOpenModeAction>(
                              value: _ArchiveOpenModeAction.openStandard,
                              child: Text(
                                _archiveOpenModeLabel(
                                  _ArchiveOpenModeAction.openStandard,
                                ),
                              ),
                            ),
                        ];
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: c.bg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.border, width: 0.5),
                        ),
                        child: Icon(
                          Icons.more_horiz_rounded,
                          size: 18,
                          color: c.subtitle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemBuilder: (context, index) {
                    final segment = breadcrumbs[index];
                    final isCurrent = segment.path == _currentFolder;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _currentFolder = segment.path),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: isCurrent ? c.infoAccent.withAlpha(18) : c.bg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isCurrent ? c.infoAccent : c.border,
                            width: isCurrent ? 1 : 0.5,
                          ),
                        ),
                        child: Text(
                          segment.label,
                          style: TextStyle(
                            color: isCurrent ? c.text : c.subtitle,
                            fontWeight: isCurrent
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemCount: breadcrumbs.length,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visibleEntries.isEmpty
              ? Center(
                  child: Text(
                    _searchQuery.isNotEmpty ? '没有匹配的条目' : '当前目录为空',
                    style: TextStyle(color: c.subtitle, fontSize: 14),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  itemBuilder: (context, index) {
                    final entry = visibleEntries[index];
                    return _ArchiveEntryTile(
                      entry: entry,
                      searching: _searchQuery.isNotEmpty,
                      isCached: _cachedEntries.contains(entry.path),
                      onTap: () => _handleEntryTap(entry),
                      onMore: entry.isDirectory
                          ? null
                          : () => _showEntryActions(entry),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemCount: visibleEntries.length,
                ),
        ),
      ],
    );
  }

  List<_ArchiveBreadcrumb> _breadcrumbs() {
    final segments = _currentFolder.isEmpty
        ? const <String>[]
        : _currentFolder.split('/');
    final breadcrumbs = <_ArchiveBreadcrumb>[
      _ArchiveBreadcrumb(path: '', label: widget.containerItem.title),
    ];
    if (segments.isEmpty) {
      return breadcrumbs;
    }

    var current = '';
    for (final segment in segments) {
      current = current.isEmpty ? segment : '$current/$segment';
      breadcrumbs.add(_ArchiveBreadcrumb(path: current, label: segment));
    }
    return breadcrumbs;
  }

  List<ArchivePreviewEntry> _visibleEntries() {
    final query = _searchQuery.toLowerCase();
    if (query.isNotEmpty) {
      return _entries.where((entry) {
        final target = '${entry.path} ${entry.displayName}'.toLowerCase();
        return target.contains(query);
      }).toList();
    }

    return _entries
        .where((entry) => entry.parentPath == _currentFolder)
        .toList();
  }

  Future<void> _handleEntryTap(ArchivePreviewEntry entry) async {
    if (entry.isDirectory) {
      setState(() => _currentFolder = entry.path);
      return;
    }
    if (entry.canInlinePreview) {
      await _openPreviewEntry(entry);
      return;
    }
    await _openEntryExternally(entry);
  }

  Future<void> _openPreviewEntry(ArchivePreviewEntry entry) async {
    try {
      final localPath = await ref
          .read(archivePreviewServiceProvider)
          .materializeEntry(
            courseId: widget.containerItem.courseId,
            containerAssetKey: widget.containerItem.cacheKey,
            containerLocalPath: widget.containerLocalPath,
            entry: entry,
          );
      if (!mounted) {
        return;
      }
      _markEntryCached(entry.path);
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ArchiveEntryPreviewScreen(
            item: _entryItem(entry, localPath),
            localPath: localPath,
            entryPath: entry.path,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppToast.showError(context, message: '打开压缩包条目失败: $error');
    }
  }

  Future<void> _openEntryExternally(ArchivePreviewEntry entry) async {
    try {
      final localPath = await ref
          .read(archivePreviewServiceProvider)
          .materializeEntry(
            courseId: widget.containerItem.courseId,
            containerAssetKey: widget.containerItem.cacheKey,
            containerLocalPath: widget.containerLocalPath,
            entry: entry,
          );
      final descriptor = ref
          .read(fileAccessResolverProvider)
          .resolve(
            title: entry.displayName,
            fileType: entry.previewDescriptor?.extension,
          );
      final result = await OpenFilex.open(localPath, type: descriptor.mimeType);
      if (result.type != ResultType.done && mounted) {
        AppToast.showWarning(context, message: '无法打开 ${entry.displayName}');
      }
      _markEntryCached(entry.path);
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, message: '打开失败: $error');
      }
    }
  }

  Future<void> _shareEntry(ArchivePreviewEntry entry) async {
    try {
      final localPath = await ref
          .read(archivePreviewServiceProvider)
          .materializeEntry(
            courseId: widget.containerItem.courseId,
            containerAssetKey: widget.containerItem.cacheKey,
            containerLocalPath: widget.containerLocalPath,
            entry: entry,
          );
      final descriptor = ref
          .read(fileAccessResolverProvider)
          .resolve(
            title: entry.displayName,
            fileType: entry.previewDescriptor?.extension,
          );
      await Share.shareXFiles(
        [
          XFile(
            localPath,
            name: descriptor.displayName,
            mimeType: descriptor.mimeType,
          ),
        ],
        fileNameOverrides: [descriptor.displayName],
      );
      _markEntryCached(entry.path);
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, message: '分享失败: $error');
      }
    }
  }

  Future<void> _switchDecodingMode(ArchiveNameDecodingMode mode) async {
    if (_activePreview.document.nameDecodingMode == mode) {
      return;
    }

    try {
      final nextPreview = await ref
          .read(archivePreviewServiceProvider)
          .inspect(
            descriptor: _activePreview.descriptor,
            localPath: widget.containerLocalPath,
            nameDecodingMode: mode,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _activePreview = nextPreview;
        _currentFolder = '';
        _cachedEntries = const <String>{};
        _searchQuery = '';
        _searchController.clear();
      });
      await _loadCachedEntries();
      if (!mounted) {
        return;
      }
      AppToast.showSuccess(
        context,
        message: mode == ArchiveNameDecodingMode.compatibility
            ? '已按兼容编码重新读取文件名'
            : '已按标准编码重新读取文件名',
      );
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, message: '重新载入压缩包失败: $error');
      }
    }
  }

  Future<void> _showEntryActions(ArchivePreviewEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final c = context.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  style: TextStyle(
                    color: c.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.path,
                  style: TextStyle(color: c.subtitle, fontSize: 12),
                ),
                const SizedBox(height: 14),
                if (entry.canInlinePreview)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.visibility_rounded),
                    title: const Text('内置预览'),
                    onTap: () {
                      Navigator.of(context).pop();
                      unawaited(_openPreviewEntry(entry));
                    },
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('外部打开'),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(_openEntryExternally(entry));
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.ios_share_rounded),
                  title: const Text('分享条目'),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(_shareEntry(entry));
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _extractAll() async {
    setState(() => _extractingAll = true);
    try {
      final result = await ref
          .read(archivePreviewServiceProvider)
          .extractAll(
            courseId: widget.containerItem.courseId,
            containerAssetKey: widget.containerItem.cacheKey,
            containerLocalPath: widget.containerLocalPath,
            nameDecodingMode: _activePreview.document.nameDecodingMode,
          );
      if (!mounted) {
        return;
      }
      AppToast.showSuccess(
        context,
        message:
            '已缓存 ${result.fileCount} 个条目，约 ${_formatByteCount(result.totalBytes)}',
      );
      await _loadCachedEntries();
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, message: '解压失败: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _extractingAll = false);
      }
    }
  }

  Future<void> _clearExtractedCache() async {
    setState(() => _clearingCache = true);
    try {
      await ref
          .read(archivePreviewServiceProvider)
          .clearExtractedContent(
            courseId: widget.containerItem.courseId,
            containerAssetKey: widget.containerItem.cacheKey,
          );
      if (!mounted) {
        return;
      }
      setState(() => _cachedEntries = const <String>{});
      AppToast.showSuccess(context, message: '已清理解压缓存');
    } catch (error) {
      if (mounted) {
        AppToast.showError(context, message: '清理失败: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _clearingCache = false);
      }
    }
  }

  FileDetailItem _entryItem(ArchivePreviewEntry entry, String localPath) {
    return FileDetailItem(
      cacheKey: '${widget.containerItem.cacheKey}::${entry.path}',
      sourceKind: 'archiveEntry',
      courseId: widget.containerItem.courseId,
      courseName: widget.containerItem.courseName,
      title: entry.displayName,
      description: '来自压缩包 ${widget.containerItem.title}\n${entry.path}',
      rawSize: entry.uncompressedSizeBytes,
      size: _formatByteCount(entry.uncompressedSizeBytes),
      uploadTime: widget.containerItem.uploadTime,
      fileType: entry.previewDescriptor?.extension ?? '',
      downloadUrl: '',
      previewUrl: '',
      markedImportant: false,
      isNew: false,
      supportsReadState: false,
      localDownloadState: 'downloaded',
      localFilePath: localPath,
    );
  }

  Future<void> _loadCachedEntries() async {
    if (!mounted) {
      return;
    }
    setState(() => _loadingCachedEntries = true);
    try {
      final entries = await ref
          .read(archivePreviewServiceProvider)
          .listMaterializedEntries(
            courseId: widget.containerItem.courseId,
            containerAssetKey: widget.containerItem.cacheKey,
          );
      if (!mounted) {
        return;
      }
      setState(() => _cachedEntries = entries);
    } finally {
      if (mounted) {
        setState(() => _loadingCachedEntries = false);
      }
    }
  }

  void _markEntryCached(String path) {
    if (_cachedEntries.contains(path) || !mounted) {
      return;
    }
    setState(() => _cachedEntries = {..._cachedEntries, path});
  }
}

class _ArchiveEntryPreviewScreen extends ConsumerWidget {
  const _ArchiveEntryPreviewScreen({
    required this.item,
    required this.localPath,
    required this.entryPath,
  });

  final FileDetailItem item;
  final String localPath;
  final String entryPath;

  Future<void> _openExternal(BuildContext context, WidgetRef ref) async {
    final descriptor = ref
        .read(fileAccessResolverProvider)
        .resolve(title: item.title, fileType: item.fileType);
    final result = await OpenFilex.open(localPath, type: descriptor.mimeType);
    if (result.type != ResultType.done && context.mounted) {
      AppToast.showWarning(context, message: '无法打开 ${item.title}');
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final descriptor = ref
        .read(fileAccessResolverProvider)
        .resolve(title: item.title, fileType: item.fileType);
    await Share.shareXFiles(
      [
        XFile(
          localPath,
          name: descriptor.displayName,
          mimeType: descriptor.mimeType,
        ),
      ],
      fileNameOverrides: [descriptor.displayName],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              entryPath,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: c.subtitle, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded),
            tooltip: '分享',
            onPressed: () => _share(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            tooltip: '外部打开',
            onPressed: () => _openExternal(context, ref),
          ),
        ],
      ),
      body: FilePreviewView(
        item: item,
        localPath: localPath,
        onOpenExternal: () => _openExternal(context, ref),
      ),
    );
  }
}

class _ArchiveEntryTile extends StatelessWidget {
  const _ArchiveEntryTile({
    required this.entry,
    required this.searching,
    required this.isCached,
    required this.onTap,
    this.onMore,
  });

  final ArchivePreviewEntry entry;
  final bool searching;
  final bool isCached;
  final VoidCallback onTap;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final extension = entry.previewDescriptor?.extension ?? '';
    final iconColor = entry.isDirectory
        ? c.infoAccent
        : FileTypeUtils.color(extension);
    final icon = entry.isDirectory
        ? Icons.folder_outlined
        : FileTypeUtils.icon(extension);
    final subtitle = searching
        ? entry.path
        : entry.isDirectory
        ? '${entry.childCount} 项'
        : _formatByteCount(entry.uncompressedSizeBytes);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.subtitle, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (entry.isFile && entry.canInlinePreview)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.infoAccent.withAlpha(14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '预览',
                    style: TextStyle(
                      color: c.infoAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else if (entry.isFile && isCached)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.success.withAlpha(14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已缓存',
                    style: TextStyle(
                      color: c.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (entry.isFile && entry.canInlinePreview && isCached)
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.success.withAlpha(14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '已缓存',
                    style: TextStyle(
                      color: c.success,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                )
              else
                Icon(
                  entry.isDirectory
                      ? Icons.chevron_right_rounded
                      : Icons.open_in_new_rounded,
                  color: c.subtitle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _ArchiveOpenModeAction { openCompatibility, openStandard }

String _archiveOpenModeLabel(_ArchiveOpenModeAction action) {
  return switch (action) {
    _ArchiveOpenModeAction.openCompatibility => '按兼容编码读取文件名',
    _ArchiveOpenModeAction.openStandard => '按标准编码读取文件名',
  };
}

class _ArchiveStatChip extends StatelessWidget {
  const _ArchiveStatChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.border, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.subtitle),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArchiveActionButton extends StatelessWidget {
  const _ArchiveActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: c.subtitle),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: c.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchiveBreadcrumb {
  const _ArchiveBreadcrumb({required this.path, required this.label});

  final String path;
  final String label;
}

class _PdfPreview extends StatefulWidget {
  const _PdfPreview({required this.filePath, required this.onOpenExternal});

  final String filePath;
  final VoidCallback onOpenExternal;

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  late final PdfViewerController _controller;
  int _pageCount = 0;
  int _currentPage = 1;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  Future<void> _handlePdfLink(PdfLink link) async {
    final url = link.url;
    if (url != null) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      return;
    }
    final dest = link.dest;
    if (dest != null) {
      await _controller.goToPage(
        pageNumber: dest.pageNumber,
        anchor: PdfPageAnchor.top,
      );
    }
  }

  Future<void> _fitCurrentPage({required bool fitWidth}) async {
    if (!_controller.isReady) {
      return;
    }
    final page = _controller.pageNumber ?? _currentPage;
    final matrix = fitWidth
        ? _controller.calcMatrixFitWidthForPage(pageNumber: page)
        : _controller.calcMatrixForPage(
            pageNumber: page,
            anchor: PdfPageAnchor.all,
          );
    await _controller.goTo(matrix);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_errorMessage != null) {
      return _PreviewUnavailable(
        message: _errorMessage!,
        onOpenExternal: widget.onOpenExternal,
      );
    }

    return Stack(
      children: [
        PdfViewer.file(
          widget.filePath,
          controller: _controller,
          params: PdfViewerParams(
            backgroundColor: c.bg,
            margin: 12,
            maxScale: 6,
            scrollPhysics: const BouncingScrollPhysics(),
            scrollPhysicsScale: const BouncingScrollPhysics(),
            pageDropShadow: BoxShadow(
              color: Colors.black.withAlpha(context.isDark ? 44 : 18),
              blurRadius: 18,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            onViewerReady: (document, controller) {
              if (!mounted) {
                return;
              }
              setState(() {
                _pageCount = document.pages.length;
                _currentPage = controller.pageNumber ?? 1;
              });
            },
            onPageChanged: (pageNumber) {
              if (!mounted || pageNumber == null) {
                return;
              }
              setState(() => _currentPage = pageNumber);
            },
            onDocumentLoadFinished: (documentRef, succeeded) {
              if (succeeded || !mounted) {
                return;
              }
              final listenable = documentRef.resolveListenable();
              final error = listenable.error;
              setState(() {
                _errorMessage = error == null ? 'PDF 预览失败' : 'PDF 预览失败：$error';
              });
            },
            linkHandlerParams: PdfLinkHandlerParams(
              onLinkTap: (link) {
                unawaited(_handlePdfLink(link));
              },
            ),
            loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
              return const _PreparingPreviewView();
            },
            errorBannerBuilder: (context, error, stackTrace, documentRef) {
              return _PreviewUnavailable(
                message: 'PDF 预览失败：$error',
                onOpenExternal: widget.onOpenExternal,
              );
            },
          ),
        ),
        if (_pageCount > 0)
          Positioned(
            top: 16,
            right: 12,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final canUseControls = _controller.isReady;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(150),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _PdfControlButton(
                          icon: Icons.remove_rounded,
                          tooltip: '缩小',
                          onTap: canUseControls
                              ? () => _controller.zoomDown()
                              : null,
                        ),
                        _PdfTextChip(
                          label: '适页',
                          onTap: canUseControls
                              ? () => _fitCurrentPage(fitWidth: false)
                              : null,
                        ),
                        _PdfTextChip(
                          label: '适宽',
                          onTap: canUseControls
                              ? () => _fitCurrentPage(fitWidth: true)
                              : null,
                        ),
                        _PdfControlButton(
                          icon: Icons.add_rounded,
                          tooltip: '放大',
                          onTap: canUseControls
                              ? () => _controller.zoomUp()
                              : null,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        if (_pageCount > 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_currentPage / $_pageCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: ['monospace'],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PdfControlButton extends StatelessWidget {
  const _PdfControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 18),
    );
  }
}

class _PdfTextChip extends StatelessWidget {
  const _PdfTextChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(24),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.filePath});

  final String filePath;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.6,
      maxScale: 5,
      child: Center(
        child: Image.file(
          File(filePath),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.broken_image_rounded,
            size: 56,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}

class _TextPreview extends StatelessWidget {
  const _TextPreview({required this.content, required this.isTruncated});

  final String content;
  final bool isTruncated;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        if (isTruncated)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: c.surface,
            child: Text(
              '文件较大，当前仅展示前 100KB。',
              style: TextStyle(color: c.subtitle, fontSize: 12),
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              content,
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                fontFamilyFallback: const ['monospace'],
                fontSize: 13,
                height: 1.65,
                color: c.text,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String _formatByteCount(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final digits = value >= 100 || unitIndex == 0
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(digits).replaceFirst(RegExp(r'\.?0+$'), '')} ${units[unitIndex]}';
}
