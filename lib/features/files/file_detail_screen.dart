/// File detail screen — preview + info panel for a course file.
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
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/design/colors.dart';
import '../../core/providers/providers.dart';
import '../../core/providers/sync_provider.dart';
import '../../core/database/database.dart' as db;
import '../../core/services/file_download_service.dart';

// ---------------------------------------------------------------------------
//  File type classification
// ---------------------------------------------------------------------------

enum _PreviewType { pdf, image, text, none }

_PreviewType _classifyFile(db.CourseFile file) {
  final ext = _extractExtension(file.title, file.fileType);
  switch (ext) {
    case 'pdf':
      return _PreviewType.pdf;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'bmp':
    case 'webp':
      return _PreviewType.image;
    case 'txt':
    case 'md':
    case 'csv':
    case 'json':
    case 'xml':
    case 'log':
    case 'py':
    case 'java':
    case 'c':
    case 'cpp':
    case 'h':
    case 'js':
    case 'html':
    case 'css':
    case 'dart':
      return _PreviewType.text;
    default:
      return _PreviewType.none;
  }
}

String _extractExtension(String title, String fileType) {
  // Prefer file type from API
  if (fileType.isNotEmpty) return fileType.toLowerCase();
  // Fallback: extract from filename
  final dot = title.lastIndexOf('.');
  if (dot != -1 && dot < title.length - 1) {
    return title.substring(dot + 1).toLowerCase();
  }
  return '';
}

// ---------------------------------------------------------------------------
//  Screen
// ---------------------------------------------------------------------------

class FileDetailScreen extends ConsumerStatefulWidget {
  final String fileId;
  final String courseId;
  final String courseName;

  const FileDetailScreen({
    super.key,
    required this.fileId,
    required this.courseId,
    required this.courseName,
  });

  @override
  ConsumerState<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends ConsumerState<FileDetailScreen> {
  db.CourseFile? _file;
  bool _showInfo = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFileAndDownload();
  }

  Future<void> _loadFileAndDownload() async {
    final database = ref.read(databaseProvider);
    final file = await database.getFileById(widget.fileId);
    if (!mounted) return;
    if (file == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _file = file;
      _loading = false;
    });
    _startDownload(file);
  }

  void _startDownload(db.CourseFile file) {
    final notifier = ref.read(fileDownloadProvider.notifier);
    notifier.downloadFile(
      fileId: file.id,
      courseId: widget.courseId,
      downloadUrl: file.downloadUrl,
      fileName: file.title,
    );
  }

  _PreviewType get _previewType =>
      _file != null ? _classifyFile(_file!) : _PreviewType.none;

  bool get _canPreview => _previewType != _PreviewType.none;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final downloadStates = ref.watch(fileDownloadProvider);
    final fileState = _file != null
        ? (downloadStates[_file!.id] ??
            FileDownloadState(fileId: _file!.id, status: DownloadStatus.none))
        : null;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(
          widget.courseName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: _buildActions(fileState),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _file == null
              ? _ErrorView(
                  message: '文件不存在',
                  onRetry: null,
                )
              : Stack(
                  children: [
                    _buildBody(fileState!, isDark),
                    if (fileState.status == DownloadStatus.downloading)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: fileState.progress > 0
                              ? fileState.progress
                              : null,
                          minHeight: 3,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(
                            isDark
                                ? AppColors.info
                                : const Color(0xFF007AFF),
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  List<Widget> _buildActions(FileDownloadState? fs) {
    if (fs == null) return [];
    final isReady = fs.status == DownloadStatus.downloaded;
    return [
      // Mark read / unread toggle
      if (_file != null)
        IconButton(
          icon: Icon(
            _file!.isNew
                ? Icons.mark_email_unread_rounded
                : Icons.mark_email_read_outlined,
            size: 22,
          ),
          tooltip: _file!.isNew ? '标为已读' : '标为未读',
          onPressed: () async {
            final database = ref.read(databaseProvider);
            if (_file!.isNew) {
              await database.markFileRead(_file!.id);
            } else {
              await database.markFileUnread(_file!.id);
            }
            ref.invalidate(homeDataProvider);
            final updated = await database.getFileById(widget.fileId);
            if (mounted && updated != null) {
              setState(() => _file = updated);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(updated.isNew ? '已标为未读' : '已标为已读'),
                  duration: const Duration(seconds: 1),
                ),
              );
            }
          },
        ),
      IconButton(
        icon: const Icon(Icons.refresh_rounded, size: 22),
        tooltip: '重新下载',
        onPressed: _file != null ? () => _startDownload(_file!) : null,
      ),
      IconButton(
        icon: const Icon(Icons.ios_share_rounded, size: 22),
        tooltip: '分享',
        onPressed: isReady ? () => _shareFile(fs) : null,
      ),
      IconButton(
        icon: const Icon(Icons.open_in_new_rounded, size: 22),
        tooltip: '外部打开',
        onPressed: isReady ? () => _openExternal(fs) : null,
      ),
      if (_canPreview && isReady)
        IconButton(
          icon: Icon(
            _showInfo ? Icons.preview_rounded : Icons.info_outline_rounded,
            size: 22,
          ),
          tooltip: _showInfo ? '预览' : '文件信息',
          onPressed: () => setState(() => _showInfo = !_showInfo),
        ),
    ];
  }

  Widget _buildBody(FileDownloadState fs, bool isDark) {
    switch (fs.status) {
      case DownloadStatus.downloading:
      case DownloadStatus.none:
        return _DownloadingView(progress: fs.progress);
      case DownloadStatus.failed:
        return _ErrorView(
          message: fs.errorMessage ?? '下载失败',
          onRetry: _file != null ? () => _startDownload(_file!) : null,
        );
      case DownloadStatus.downloaded:
        if (!_showInfo && _canPreview && fs.localPath != null) {
          return _PreviewBody(
            file: _file!,
            previewType: _previewType,
            localPath: fs.localPath!,
          );
        }
        return _FileInfoPanel(
          file: _file!,
          courseName: widget.courseName,
          isDownloaded: true,
          onOpen: () => _openExternal(fs),
          onShare: () => _shareFile(fs),
        );
    }
  }

  Future<void> _shareFile(FileDownloadState fs) async {
    if (fs.localPath == null) return;
    try {
      await Share.shareXFiles([XFile(fs.localPath!)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  Future<void> _openExternal(FileDownloadState fs) async {
    if (fs.localPath == null) return;
    final result = await OpenFilex.open(fs.localPath!);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法打开文件')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
//  Preview body — dispatches to appropriate preview widget
// ---------------------------------------------------------------------------

class _PreviewBody extends StatelessWidget {
  final db.CourseFile file;
  final _PreviewType previewType;
  final String localPath;

  const _PreviewBody({
    required this.file,
    required this.previewType,
    required this.localPath,
  });

  @override
  Widget build(BuildContext context) {
    switch (previewType) {
      case _PreviewType.pdf:
        return _PdfPreview(filePath: localPath);
      case _PreviewType.image:
        return _ImagePreview(filePath: localPath);
      case _PreviewType.text:
        return _TextPreview(filePath: localPath);
      case _PreviewType.none:
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      children: [
        PDFView(
          filePath: widget.filePath,
          enableSwipe: true,
          swipeHorizontal: false,
          autoSpacing: true,
          pageFling: true,
          fitPolicy: FitPolicy.BOTH,
          nightMode: isDark,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          errorBuilder: (_, error, __) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image_rounded,
                    size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text('图片加载失败',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

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
          color: textColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final sub =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

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
          Text('正在下载...', style: TextStyle(color: textColor, fontSize: 15)),
          const SizedBox(height: 4),
          Text(
            '${(progress * 100).toInt()}%',
            style: TextStyle(
              color: sub,
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
          const Icon(Icons.error_outline_rounded,
              size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 15)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
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
  final db.CourseFile file;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final sub =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final ext = _extractExtension(file.title, file.fileType);

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
                      color: fileColor(ext).withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      fileIcon(ext),
                      color: fileColor(ext),
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
                      color: textColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(courseName,
                      style: TextStyle(fontSize: 13, color: sub)),
                ),
                const SizedBox(height: 24),

                // Metadata card
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border, width: 0.5),
                  ),
                  child: Column(
                    children: [
                      _MetaRow(
                        icon: Icons.insert_drive_file_rounded,
                        label: '类型',
                        value: ext.toUpperCase(),
                        textColor: textColor,
                        sub: sub,
                      ),
                      Divider(height: 1, color: border),
                      _MetaRow(
                        icon: Icons.file_download_rounded,
                        label: '大小',
                        value: file.size.isNotEmpty
                            ? file.size
                            : '${file.rawSize} B',
                        textColor: textColor,
                        sub: sub,
                      ),
                      Divider(height: 1, color: border),
                      _MetaRow(
                        icon: Icons.access_time_rounded,
                        label: '上传时间',
                        value: _formatUploadTime(file.uploadTime),
                        textColor: textColor,
                        sub: sub,
                      ),
                      if (file.markedImportant) ...[
                        Divider(height: 1, color: border),
                        _MetaRow(
                          icon: Icons.star_rounded,
                          label: '标记',
                          value: '重要文件',
                          textColor: textColor,
                          sub: sub,
                          valueColor: AppColors.warning,
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 300.ms,
                    ),

                // Description
                if (file.description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '文件说明',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sub,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          file.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: surface,
              border: Border(top: BorderSide(color: border, width: 0.5)),
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

// ---------------------------------------------------------------------------
//  File type helpers — exported for reuse in other screens
// ---------------------------------------------------------------------------

IconData fileIcon(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'doc':
    case 'docx':
      return Icons.description_rounded;
    case 'ppt':
    case 'pptx':
      return Icons.slideshow_rounded;
    case 'xls':
    case 'xlsx':
      return Icons.table_chart_rounded;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip_rounded;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'bmp':
    case 'webp':
      return Icons.image_rounded;
    case 'mp4':
    case 'avi':
    case 'mov':
      return Icons.videocam_rounded;
    case 'txt':
    case 'md':
    case 'csv':
    case 'log':
      return Icons.text_snippet_rounded;
    case 'py':
    case 'java':
    case 'c':
    case 'cpp':
    case 'js':
    case 'dart':
    case 'html':
    case 'css':
      return Icons.code_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Color fileColor(String type) {
  switch (type.toLowerCase()) {
    case 'pdf':
      return const Color(0xFFE53935);
    case 'doc':
    case 'docx':
      return const Color(0xFF1976D2);
    case 'ppt':
    case 'pptx':
      return const Color(0xFFE65100);
    case 'xls':
    case 'xlsx':
      return const Color(0xFF2E7D32);
    case 'zip':
    case 'rar':
    case '7z':
      return const Color(0xFF757575);
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'bmp':
    case 'webp':
      return const Color(0xFF7B1FA2);
    case 'mp4':
    case 'avi':
    case 'mov':
      return const Color(0xFFD81B60);
    case 'txt':
    case 'md':
    case 'csv':
    case 'log':
      return const Color(0xFF546E7A);
    case 'py':
    case 'java':
    case 'c':
    case 'cpp':
    case 'js':
    case 'dart':
    case 'html':
    case 'css':
      return const Color(0xFF00897B);
    default:
      return const Color(0xFF546E7A);
  }
}
