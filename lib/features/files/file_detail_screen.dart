/// File detail screen — preview + info panel for a course file or attachment.
///
/// Preview strategy (per architecture):
/// - PDF → flutter_pdfview inline
/// - Images → Image.file() inline
/// - Text/code → SelectableText inline
/// - Office/other → info panel + system open
///
/// Features:
/// - Auto-download on entry
/// - Download progress bar overlay
/// - AppBar: refresh / share / open-external / info-toggle
/// - Info panel: type, size, upload time, category, importance, description
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/file_type_utils.dart';
import '../../core/files/file_asset_actions.dart';
import '../../core/files/file_asset_runtime.dart';
import '../../core/files/file_models.dart';
import '../../core/files/file_preview_registry.dart';
import '../../core/services/file_download_service.dart';
import 'providers/file_bookmark_providers.dart';
import 'providers/file_queries.dart';

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class FileDetailScreen extends ConsumerStatefulWidget {
  final FileDetailRouteData routeData;

  const FileDetailScreen({super.key, required this.routeData});

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen> {
  bool _showInfo = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_startInitialDownload);
  }

  Future<void> _startInitialDownload() async {
    final file = await ref.read(
      fileDetailItemProvider(widget.routeData).future,
    );
    if (!mounted || file == null) return;

    await ref.read(fileAssetActionsProvider).ensureAvailable(file);
  }

  Future<void> _startDownload(FileDetailItem file) {
    return ref.read(fileAssetActionsProvider).download(file);
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
          ref.read(fileAssetActionsProvider).setReadState(file, isRead: true);
        }
      });
    }

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          widget.routeData.courseName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: file == null || fileState == null
            ? const []
            : _buildActions(file, fileState, isFavorite),
      ),
      body: fileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator.adaptive()),
        error: (error, _) => _ErrorView(message: '加载失败', onRetry: null),
        data: (file) {
          if (file == null) {
            return _ErrorView(message: '文件不存在', onRetry: null);
          }
          final resolvedState = runtimeResolver.resolveDetailItem(
            file,
            trackedDownloadStates,
          );

          return Stack(
            children: [
              _buildBody(file, resolvedState),
              if (resolvedState.status == DownloadStatus.downloading)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: resolvedState.progress > 0
                        ? resolvedState.progress
                        : null,
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation(c.infoAccent),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildActions(
    FileDetailItem file,
    FileAssetRuntime fs,
    bool isFavorite,
  ) {
    final isReady = fs.isDownloaded;
    return [
      if (file.supportsReadState && file.persistedFileId != null)
        IconButton(
          icon: Icon(
            file.isNew
                ? Icons.mark_email_unread_rounded
                : Icons.mark_email_read_outlined,
            size: 22,
          ),
          tooltip: file.isNew ? '标为已读' : '标为未读',
          onPressed: () async {
            await ref
                .read(fileAssetActionsProvider)
                .setReadState(file, isRead: file.isNew);

            if (!mounted) return;
            AppToast.showSuccess(
              context,
              message: file.isNew ? '已标为已读' : '已标为未读',
              duration: const Duration(milliseconds: 1800),
            );
          },
        ),
      IconButton(
        icon: Icon(
          isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: 22,
          color: isFavorite ? AppColors.warning : null,
        ),
        tooltip: isFavorite ? '取消收藏' : '收藏文件',
        onPressed: !isReady
            ? null
            : () async {
                await ref
                    .read(fileFavoriteActionsProvider)
                    .setFavorite(item: file, isFavorite: !isFavorite);
                if (!mounted) return;
                AppToast.showSuccess(
                  context,
                  message: isFavorite ? '已取消收藏' : '已加入收藏',
                  duration: const Duration(milliseconds: 1800),
                );
              },
      ),
      PopupMenuButton<_FileAction>(
        icon: const Icon(Icons.more_horiz_rounded, size: 22),
        onSelected: (action) async {
          switch (action) {
            case _FileAction.redownload:
              await _startDownload(file);
              break;
            case _FileAction.share:
              await _shareFile(fs);
              break;
            case _FileAction.openExternal:
              await _openExternal(file);
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
          if (isReady) {
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
          if (_canPreview(file) && isReady) {
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
      case DownloadStatus.none:
        return _DownloadingView(progress: fs.progress);
      case DownloadStatus.failed:
        return _ErrorView(
          message: fs.errorMessage ?? '下载失败',
          onRetry: () => _startDownload(file),
        );
      case DownloadStatus.downloaded:
        if (!_showInfo && _canPreview(file) && fs.localPath != null) {
          return _PreviewBody(
            preview: _previewOf(file),
            localPath: fs.localPath!,
          );
        }
        return _FileInfoPanel(
          file: file,
          courseName: widget.routeData.courseName,
          isDownloaded: true,
          onOpen: () => _openExternal(file),
          onShare: () => _shareFile(fs),
        );
    }
  }

  Future<void> _shareFile(FileAssetRuntime fs) async {
    if (fs.localPath == null) return;
    try {
      await Share.shareXFiles([XFile(fs.localPath!)]);
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
}

enum _FileAction { redownload, share, openExternal, toggleInfo }

// ---------------------------------------------------------------------------
//  Preview body — dispatches to appropriate preview widget
// ---------------------------------------------------------------------------

class _PreviewBody extends StatelessWidget {
  final FilePreviewDescriptor preview;
  final String localPath;

  const _PreviewBody({required this.preview, required this.localPath});

  @override
  Widget build(BuildContext context) {
    switch (preview.capability) {
      case FilePreviewCapability.pdf:
        return _PdfPreview(filePath: localPath);
      case FilePreviewCapability.image:
        return _ImagePreview(filePath: localPath);
      case FilePreviewCapability.text:
        return _TextPreview(filePath: localPath);
      case FilePreviewCapability.none:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
//  PDF Preview
// ---------------------------------------------------------------------------

class _PdfPreview extends StatefulWidget {
  final String filePath;
  const _PdfPreview({required this.filePath});

  @override
  State<_PdfPreview> createState() => _PdfPreviewState();
}

class _PdfPreviewState extends State<_PdfPreview> {
  int _totalPages = 0;
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        PDFView(
          filePath: widget.filePath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          fitPolicy: FitPolicy.BOTH,
          nightMode: context.isDark,
          onRender: (pages) {
            if (pages != null) setState(() => _totalPages = pages);
          },
          onPageChanged: (page, total) {
            if (page != null) setState(() => _currentPage = page);
          },
          onError: (error) {
            debugPrint('PDF render error: $error');
          },
        ),
        if (_totalPages > 0)
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
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentPage + 1} / $_totalPages',
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

// ---------------------------------------------------------------------------
//  Image Preview
// ---------------------------------------------------------------------------

class _ImagePreview extends StatelessWidget {
  final String filePath;
  const _ImagePreview({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.file(
          File(filePath),
          fit: BoxFit.contain,
          errorBuilder: (_, error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.broken_image_rounded,
                  size: 48,
                  color: Colors.grey,
                ),
                const SizedBox(height: 8),
                Text(
                  '图片加载失败',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Text Preview
// ---------------------------------------------------------------------------

class _TextPreview extends StatefulWidget {
  final String filePath;
  const _TextPreview({required this.filePath});

  @override
  State<_TextPreview> createState() => _TextPreviewState();
}

class _TextPreviewState extends State<_TextPreview> {
  String _content = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final file = File(widget.filePath);
      final content = await file.readAsString();
      if (mounted) {
        setState(() {
          // Limit to 100KB to avoid OOM on huge files
          _content = content.length > 100000
              ? '${content.substring(0, 100000)}\n\n... (文件过大，仅显示前100KB)'
              : content;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '无法读取文件内容';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null) {
      return Center(
        child: Text(_error!, style: TextStyle(color: Colors.grey[600])),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: const ['monospace'],
          fontSize: 13,
          height: 1.6,
          color: c.text,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Downloading view
// ---------------------------------------------------------------------------

class _DownloadingView extends StatelessWidget {
  final double progress;
  const _DownloadingView({required this.progress});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: CircularProgressIndicator.adaptive(
              value: progress > 0 ? progress : null,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 16),
          Text('正在下载...', style: TextStyle(color: c.text, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: c.subtitle,
              fontSize: 13,
              fontFamily: 'JetBrains Mono',
              fontFamilyFallback: const ['monospace'],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(color: Colors.grey, fontSize: 15),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
//  File Info Panel — shown for non-previewable files or info toggle
// ---------------------------------------------------------------------------

class _FileInfoPanel extends StatelessWidget {
  final FileDetailItem file;
  final String courseName;
  final bool isDownloaded;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;

  const _FileInfoPanel({
    required this.file,
    required this.courseName,
    required this.isDownloaded,
    this.onOpen,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ext = FileTypeUtils.extractExt(file.title, file.fileType);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File icon
                Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: FileTypeUtils.color(ext).withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          FileTypeUtils.icon(ext),
                          color: FileTypeUtils.color(ext),
                          size: 36,
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1, 1),
                      duration: 300.ms,
                    ),
                const SizedBox(height: 16),

                // Title
                Center(
                  child: Text(
                    file.title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    courseName,
                    style: TextStyle(fontSize: 13, color: c.subtitle),
                  ),
                ),
                const SizedBox(height: 24),

                // Metadata card
                Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: c.border, width: 0.5),
                      ),
                      child: Column(
                        children: [
                          _MetaRow(
                            icon: Icons.insert_drive_file_rounded,
                            label: '类型',
                            value: ext.toUpperCase(),
                            textColor: c.text,
                            sub: c.subtitle,
                          ),
                          Divider(height: 1, color: c.border),
                          _MetaRow(
                            icon: Icons.file_download_rounded,
                            label: '大小',
                            value: file.size.isNotEmpty
                                ? file.size
                                : '${file.rawSize} B',
                            textColor: c.text,
                            sub: c.subtitle,
                          ),
                          Divider(height: 1, color: c.border),
                          _MetaRow(
                            icon: Icons.access_time_rounded,
                            label: '上传时间',
                            value: _formatUploadTime(file.uploadTime),
                            textColor: c.text,
                            sub: c.subtitle,
                          ),
                          if (file.markedImportant) ...[
                            Divider(height: 1, color: c.border),
                            _MetaRow(
                              icon: Icons.star_rounded,
                              label: '标记',
                              value: '重要文件',
                              textColor: c.text,
                              sub: c.subtitle,
                              valueColor: AppColors.warning,
                            ),
                          ],
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 300.ms)
                    .slideY(begin: 0.1, end: 0, duration: 300.ms),

                // Description
                if (file.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '文件说明',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: c.subtitle,
                            letterSpacing: 0.5,
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
                  ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
                ],
              ],
            ),
          ),
        ),

        // Bottom action bar for non-previewable files
        if (isDownloaded)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: c.surface,
              border: Border(top: BorderSide(color: c.border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: onOpen,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('外部打开'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: onShare,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.ios_share_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('分享'),
                        ],
                      ),
                    ),
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

// ---------------------------------------------------------------------------
//  Metadata row
// ---------------------------------------------------------------------------

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color sub;
  final Color? valueColor;

  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.sub,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: sub),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 14, color: sub)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor ?? textColor,
            ),
          ),
        ],
      ),
    );
  }
}
