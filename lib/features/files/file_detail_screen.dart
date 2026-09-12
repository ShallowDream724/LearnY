// File detail screen — preview + info panel for a course file or attachment.
//
// The page contract stays stable: auto-download on entry, the same action bar,
// and an optional info panel. The preview implementation is now delegated to the
// preview subsystem so richer formats can be added without growing this screen.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/app_orientation.dart';
import '../../core/design/app_toast.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/app_materials.dart';
import '../../core/design/colors.dart';
import '../../core/design/file_type_utils.dart';
import '../../core/files/file_access_resolver.dart';
import '../../core/files/file_asset_actions.dart';
import '../../core/files/file_asset_runtime.dart';
import '../../core/files/file_models.dart';
import '../../core/files/file_preview_registry.dart';
import '../../core/services/file_download_service.dart';
import '../../core/services/file_manager_reveal_service.dart';
import 'providers/file_bookmark_providers.dart';
import 'providers/file_queries.dart';
import 'widgets/file_preview_view.dart';
import 'widgets/file_type_mark.dart';

class FileDetailScreen extends ConsumerStatefulWidget {
  const FileDetailScreen({super.key, required this.routeData});

  final FileDetailRouteData routeData;

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen> {
  bool _showInfo = false;
  bool _updatingRead = false;
  bool _updatingFavorite = false;
  String? _downloadRequestError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_startInitialDownload);
  }

  Future<void> _startInitialDownload() async {
    try {
      final file = await ref.read(
        fileDetailItemProvider(widget.routeData).future,
      );
      if (!mounted || file == null) return;
      await ref.read(fileAssetActionsProvider).ensureAvailable(file);
    } catch (_) {
      if (mounted) setState(() => _downloadRequestError = '文件下载无法启动');
    }
  }

  Future<void> _startDownload(FileDetailItem file) async {
    setState(() => _downloadRequestError = null);
    try {
      await ref.read(fileAssetActionsProvider).download(file);
    } catch (_) {
      if (mounted) setState(() => _downloadRequestError = '文件下载无法启动');
    }
  }

  Future<void> _changeReadState(
    FileDetailItem file, {
    bool? isRead,
    bool announce = true,
  }) async {
    if (_updatingRead) return;
    setState(() => _updatingRead = true);
    final target = isRead ?? file.isNew;
    try {
      await ref
          .read(fileAssetActionsProvider)
          .setReadState(file, isRead: target);
      if (mounted && announce) {
        AppToast.showSuccess(context, message: target ? '已标为已读' : '已标为未读');
      }
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '文件已读状态更新失败');
    } finally {
      if (mounted) setState(() => _updatingRead = false);
    }
  }

  Future<void> _changeFavorite(FileDetailItem file, bool isFavorite) async {
    if (_updatingFavorite) return;
    setState(() => _updatingFavorite = true);
    try {
      await ref
          .read(fileFavoriteActionsProvider)
          .setFavorite(item: file, isFavorite: !isFavorite);
      if (mounted) {
        AppToast.showSuccess(context, message: isFavorite ? '已取消收藏' : '已加入收藏');
      }
    } catch (_) {
      if (mounted) AppToast.showError(context, message: '收藏状态更新失败');
    } finally {
      if (mounted) setState(() => _updatingFavorite = false);
    }
  }

  FilePreviewDescriptor _previewOf(FileDetailItem file) {
    return ref.read(filePreviewRegistryProvider).describeItem(file);
  }

  bool _canPreview(FileDetailItem file) => _previewOf(file).canInlinePreview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fileAsync = ref.watch(fileDetailItemProvider(widget.routeData));
    final trackedDownloadStates = ref.watch(fileDownloadProvider);
    final file = fileAsync.valueOrNull;
    final runtimeResolver = ref.read(fileAssetRuntimeResolverProvider);
    final fileState = file == null
        ? null
        : runtimeResolver.resolveDetailItem(file, trackedDownloadStates);
    final isFavorite = file == null
        ? false
        : (ref.watch(fileBookmarkStateProvider(file.cacheKey)).valueOrNull ??
              false);

    if (file != null &&
        file.supportsReadState &&
        file.persistedFileId != null) {
      ref.listen<Map<String, FileDownloadState>>(fileDownloadProvider, (
        previous,
        next,
      ) {
        final previousStatus = previous?[file.cacheKey]?.status;
        final currentStatus = next[file.cacheKey]?.status;
        if (previousStatus != DownloadStatus.downloaded &&
            currentStatus == DownloadStatus.downloaded &&
            file.isNew) {
          _changeReadState(file, isRead: true, announce: false);
        }
      });
    }

    return PreviewOrientationScope(
      child: Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          toolbarHeight:
              (MediaQuery.textScalerOf(context).scale(16) * 1.4 +
                      MediaQuery.textScalerOf(context).scale(12) * 1.4 +
                      16)
                  .clamp(68.0, double.infinity),
          title: Tooltip(
            message: file?.title ?? '文件',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  file?.title ?? '文件',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (widget.routeData.courseName.isNotEmpty)
                  Text(
                    widget.routeData.courseName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: c.subtitle),
                  ),
              ],
            ),
          ),
          actions: file == null || fileState == null
              ? const []
              : _buildActions(file, fileState, isFavorite),
        ),
        body: fileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator.adaptive()),
          error: (error, _) => _ErrorView(
            message: '文件加载失败',
            onRetry: () =>
                ref.invalidate(fileDetailItemProvider(widget.routeData)),
          ),
          data: (file) {
            if (file == null) {
              return _ErrorView(message: '文件不存在', onRetry: null);
            }
            final resolvedState = runtimeResolver.resolveDetailItem(
              file,
              trackedDownloadStates,
            );

            return _buildBody(file, resolvedState);
          },
        ),
      ),
    );
  }

  List<Widget> _buildActions(
    FileDetailItem file,
    FileAssetRuntime fs,
    bool isFavorite,
  ) {
    final isReady = fs.isDownloaded;
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final showingInfo = _showInfo || !_canPreview(file);
    return [
      if (wide) ...[
        IconButton(
          tooltip: '外部打开',
          icon: const Icon(Icons.open_in_new_rounded),
          onPressed: isReady ? () => _openExternal(file) : null,
        ),
        if (supportsRevealInFileManager)
          IconButton(
            tooltip: '在文件夹中打开',
            icon: const Icon(Icons.folder_open_rounded),
            onPressed: isReady ? () => _openContainingFolder(file) : null,
          ),
        IconButton(
          tooltip: '分享',
          icon: const Icon(Icons.ios_share_rounded),
          onPressed: isReady ? () => _shareFile(file, fs) : null,
        ),
        if (_canPreview(file))
          IconButton(
            tooltip: _showInfo ? '返回预览' : '文件信息',
            isSelected: _showInfo,
            icon: const Icon(Icons.info_outline_rounded),
            selectedIcon: const Icon(Icons.info_rounded),
            onPressed: isReady
                ? () => setState(() => _showInfo = !_showInfo)
                : null,
          ),
      ],
      if (file.supportsReadState && file.persistedFileId != null)
        IconButton(
          icon: Icon(
            file.isNew
                ? Icons.mark_email_unread_rounded
                : Icons.mark_email_read_outlined,
            size: 22,
          ),
          tooltip: file.isNew ? '标为已读' : '标为未读',
          onPressed: _updatingRead ? null : () => _changeReadState(file),
        ),
      IconButton(
        icon: Icon(
          isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: 22,
          color: isFavorite ? AppColors.warning : null,
        ),
        tooltip: isFavorite ? '取消收藏' : '收藏文件',
        onPressed: !isReady || _updatingFavorite
            ? null
            : () => _changeFavorite(file, isFavorite),
      ),
      PopupMenuButton<_FileAction>(
        tooltip: '更多文件操作',
        icon: const Icon(Icons.more_horiz_rounded, size: 22),
        onSelected: (action) async {
          switch (action) {
            case _FileAction.redownload:
              await _startDownload(file);
              break;
            case _FileAction.share:
              await _shareFile(file, fs);
              break;
            case _FileAction.openExternal:
              await _openExternal(file);
              break;
            case _FileAction.openContainingFolder:
              await _openContainingFolder(file);
              break;
            case _FileAction.toggleInfo:
              setState(() => _showInfo = !_showInfo);
              break;
          }
        },
        itemBuilder: (context) {
          final items = <PopupMenuEntry<_FileAction>>[
            const PopupMenuItem<_FileAction>(
              value: _FileAction.redownload,
              child: Text('重新下载'),
            ),
          ];
          if (isReady && !wide && !showingInfo) {
            items.add(
              const PopupMenuItem<_FileAction>(
                value: _FileAction.share,
                child: Text('分享'),
              ),
            );
            items.add(
              const PopupMenuItem<_FileAction>(
                value: _FileAction.openExternal,
                child: Text('外部打开'),
              ),
            );
          }
          if (isReady && !wide && supportsRevealInFileManager) {
            items.add(
              const PopupMenuItem<_FileAction>(
                value: _FileAction.openContainingFolder,
                child: Text('在文件夹中打开'),
              ),
            );
          }
          if (!wide && _canPreview(file) && isReady) {
            items.add(
              PopupMenuItem<_FileAction>(
                value: _FileAction.toggleInfo,
                child: Text(_showInfo ? '返回预览' : '查看信息'),
              ),
            );
          }
          return items;
        },
      ),
    ];
  }

  Widget _buildBody(FileDetailItem file, FileAssetRuntime fs) {
    switch (fs.status) {
      case DownloadStatus.downloading:
        // A path (or 100% transfer progress) does not mean publication has
        // finished. Mount a fresh reader only after the downloaded transition,
        // including replacement downloads at the same path.
        return _DownloadingView(progress: fs.progress);
      case DownloadStatus.none:
        if (_downloadRequestError != null) {
          return _ErrorView(
            message: _downloadRequestError!,
            onRetry: () => _startDownload(file),
          );
        }
        return _DownloadingView(progress: fs.progress);
      case DownloadStatus.failed:
        return _ErrorView(
          message: fs.errorMessage ?? '下载失败',
          onRetry: () => _startDownload(file),
        );
      case DownloadStatus.downloaded:
        if (!_showInfo && _canPreview(file) && fs.localPath != null) {
          return FilePreviewView(
            item: file,
            localPath: fs.localPath!,
            onOpenExternal: () => _openExternal(file),
          );
        }
        return _FileInfoPanel(
          file: file,
          courseName: widget.routeData.courseName,
          isDownloaded: MediaQuery.sizeOf(context).width < 840,
          onOpen: () => _openExternal(file),
          onShare: () => _shareFile(file, fs),
        );
    }
  }

  Future<void> _shareFile(FileDetailItem file, FileAssetRuntime fs) async {
    if (fs.localPath == null) {
      return;
    }

    final accessDescriptor = ref
        .read(fileAccessResolverProvider)
        .resolve(title: file.title, fileType: file.fileType);
    try {
      await Share.shareXFiles(
        [
          XFile(
            fs.localPath!,
            mimeType: accessDescriptor.mimeType,
            name: accessDescriptor.displayName,
          ),
        ],
        fileNameOverrides: [accessDescriptor.displayName],
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, message: '分享失败: $e');
      }
    }
  }

  Future<void> _openExternal(FileDetailItem file) async {
    final opened = await ref.read(fileAssetActionsProvider).open(file);
    if (!opened && mounted) {
      AppToast.showWarning(context, message: '无法打开文件');
    }
  }

  Future<void> _openContainingFolder(FileDetailItem file) async {
    final opened = await ref
        .read(fileAssetActionsProvider)
        .openContainingFolder(file);
    if (!opened && mounted) {
      AppToast.showWarning(context, message: '无法打开所在文件夹');
    }
  }
}

enum _FileAction {
  redownload,
  share,
  openExternal,
  openContainingFolder,
  toggleInfo,
}

class _DownloadingView extends StatelessWidget {
  const _DownloadingView({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator.adaptive(
              value: progress > 0 ? progress : null,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text('正在下载...', style: TextStyle(color: c.text, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            progress > 0 ? '${(progress * 100).toInt()}%' : '等待文件响应',
            style: TextStyle(
              color: c.subtitle,
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.error_outline_rounded,
      title: message,
      action: onRetry == null
          ? null
          : FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('重试'),
            ),
    );
  }
}

class _FileInfoPanel extends StatelessWidget {
  const _FileInfoPanel({
    required this.file,
    required this.courseName,
    required this.isDownloaded,
    this.onOpen,
    this.onShare,
  });

  final FileDetailItem file;
  final String courseName;
  final bool isDownloaded;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ext = FileTypeUtils.extractExt(file.title, file.fileType);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              pageGutter(context, maxWidth: 720),
              24,
              pageGutter(context, maxWidth: 720),
              32,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FileTypeMark(extension: ext, width: 58),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            file.title,
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w500,
                              color: c.text,
                              height: 1.4,
                            ),
                          ),
                          if (courseName.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              courseName,
                              style: TextStyle(
                                fontSize: 13,
                                color: StudyPalette.of(
                                  context,
                                  StudyPalette.course(file.courseId),
                                ).accent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                StudySurface(
                  radius: 16,
                  child: Column(
                    children: [
                      _MetaRow(
                        label: '类型',
                        value: ext.toUpperCase(),
                        textColor: c.text,
                        sub: c.subtitle,
                      ),
                      Divider(height: 1, color: c.border),
                      _MetaRow(
                        label: '大小',
                        value: file.size.isNotEmpty
                            ? file.size
                            : '${file.rawSize} B',
                        textColor: c.text,
                        sub: c.subtitle,
                      ),
                      Divider(height: 1, color: c.border),
                      _MetaRow(
                        label: '上传时间',
                        value: _formatUploadTime(file.uploadTime),
                        textColor: c.text,
                        sub: c.subtitle,
                      ),
                      if (file.markedImportant) ...[
                        Divider(height: 1, color: c.border),
                        _MetaRow(
                          label: '标记',
                          value: '重要文件',
                          textColor: c.text,
                          sub: c.subtitle,
                          valueColor: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                ),
                if (file.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '文件说明',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.subtitle,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          file.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: c.text,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (isDownloaded)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: pageGutter(context, maxWidth: 720),
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: const Text('外部打开'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: onShare,
                    icon: const Icon(Icons.ios_share_rounded, size: 18),
                    label: const Text('分享'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatUploadTime(String raw) {
    if (raw.isEmpty) {
      return '未知';
    }
    try {
      final dt = DateTime.parse(raw);
      return '${dt.year}年${dt.month}月${dt.day}日 '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    required this.textColor,
    required this.sub,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: TextStyle(fontSize: 14, color: sub)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
