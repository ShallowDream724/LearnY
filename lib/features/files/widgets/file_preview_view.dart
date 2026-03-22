import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/files/file_models.dart';
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
          HtmlPreparedFilePreview() => _HtmlDocumentPreview(preview: preview),
          PresentationPreparedFilePreview() => _PresentationPreview(
            document: preview.document,
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

class _HtmlDocumentPreview extends StatefulWidget {
  const _HtmlDocumentPreview({required this.preview});

  final HtmlPreparedFilePreview preview;

  @override
  State<_HtmlDocumentPreview> createState() => _HtmlDocumentPreviewState();
}

class _HtmlDocumentPreviewState extends State<_HtmlDocumentPreview> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.transparent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    unawaited(_loadHtml());
  }

  @override
  void didUpdateWidget(covariant _HtmlDocumentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.preview.htmlBody != widget.preview.htmlBody ||
        oldWidget.preview.kind != widget.preview.kind) {
      unawaited(_loadHtml());
    }
  }

  Future<void> _loadHtml() {
    return _controller.loadHtmlString(_wrapHtml(context, widget.preview));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final paperColor =
        widget.preview.kind == HtmlPreparedFilePreviewKind.document
        ? (context.isDark ? c.surface : Colors.white)
        : c.surface;

    return Column(
      children: [
        if (widget.preview.note != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: c.surface,
            child: Text(
              widget.preview.note!,
              style: TextStyle(color: c.subtitle, fontSize: 12),
            ),
          ),
        Expanded(
          child: ColoredBox(
            color: paperColor,
            child: WebViewWidget(controller: _controller),
          ),
        ),
      ],
    );
  }

  String _wrapHtml(BuildContext context, HtmlPreparedFilePreview preview) {
    final c = context.colors;
    final isSpreadsheet =
        preview.kind == HtmlPreparedFilePreviewKind.spreadsheet;
    final paperColor = isSpreadsheet
        ? c.surface
        : (context.isDark ? c.surface : Colors.white);

    return '''
<!DOCTYPE html>
<html lang="zh-CN">
  <head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=5" />
    <style>
      :root {
        color-scheme: ${context.isDark ? 'dark' : 'light'};
        --bg: ${_cssColor(paperColor)};
        --text: ${_cssColor(c.text)};
        --subtle: ${_cssColor(c.subtitle)};
        --border: ${_cssColor(c.border)};
        --surface: ${_cssColor(c.surface)};
        --accent: ${_cssColor(c.infoAccent)};
      }
      * {
        box-sizing: border-box;
      }
      body {
        margin: 0;
        padding: ${isSpreadsheet ? '14px' : '20px'};
        background: var(--bg);
        color: var(--text);
        font-family: "SF Pro Text", "PingFang SC", "Noto Sans SC", sans-serif;
        line-height: 1.7;
        word-break: break-word;
      }
      h1, h2, h3 {
        margin: 0 0 0.8em;
        line-height: 1.25;
      }
      h1 {
        font-size: 1.45rem;
      }
      h2 {
        font-size: 1.22rem;
        color: var(--text);
      }
      h3 {
        font-size: 1.05rem;
        color: var(--text);
      }
      p {
        margin: 0 0 1em;
        font-size: 0.98rem;
      }
      .doc-list-item {
        padding-left: 1.15em;
        position: relative;
      }
      .doc-list-item::before {
        content: "•";
        position: absolute;
        left: 0;
        color: var(--accent);
      }
      .sheet + .sheet {
        margin-top: 20px;
      }
      .table-wrap {
        overflow: auto;
        border: 1px solid var(--border);
        border-radius: 16px;
        background: var(--surface);
      }
      table {
        width: 100%;
        min-width: max-content;
        border-collapse: collapse;
      }
      th,
      td {
        padding: 10px 12px;
        border-right: 1px solid var(--border);
        border-bottom: 1px solid var(--border);
        vertical-align: top;
        font-size: 0.92rem;
        text-align: left;
        white-space: pre-wrap;
      }
      th {
        position: sticky;
        top: 0;
        background: var(--surface);
        color: var(--subtle);
        font-weight: 600;
        z-index: 1;
      }
      .row-index,
      .corner {
        left: 0;
        z-index: 2;
      }
      tr:last-child td,
      tr:last-child th {
        border-bottom: none;
      }
      tr td:last-child,
      tr th:last-child {
        border-right: none;
      }
    </style>
  </head>
  <body>
    ${preview.htmlBody}
  </body>
</html>
''';
  }

  String _cssColor(Color color) {
    return '#${_channel(color.r).toRadixString(16).padLeft(2, '0')}${_channel(color.g).toRadixString(16).padLeft(2, '0')}${_channel(color.b).toRadixString(16).padLeft(2, '0')}';
  }

  int _channel(double value) => (value * 255.0).round().clamp(0, 255);
}

class _PresentationPreview extends StatefulWidget {
  const _PresentationPreview({required this.document});

  final PresentationPreviewDocument document;

  @override
  State<_PresentationPreview> createState() => _PresentationPreviewState();
}

class _PresentationPreviewState extends State<_PresentationPreview> {
  late final PageController _pageController;
  var _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final slides = widget.document.slides;

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: slides.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
            child: _PresentationSlideViewport(
              document: widget.document,
              slide: slides[index],
            ),
          ),
        ),
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(145),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              slides[_currentIndex].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (slides.length > 1)
          Positioned(
            bottom: 14,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(145),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${slides.length}',
                  style: TextStyle(
                    color: c.bg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'JetBrains Mono',
                    fontFamilyFallback: const ['monospace'],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PresentationSlideViewport extends StatelessWidget {
  const _PresentationSlideViewport({
    required this.document,
    required this.slide,
  });

  final PresentationPreviewDocument document;
  final PresentationPreviewSlide slide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final aspectRatio = document.slideWidth / document.slideHeight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final maxHeight = constraints.maxHeight;
        var width = maxWidth;
        var height = width / aspectRatio;
        if (height > maxHeight) {
          height = maxHeight;
          width = height * aspectRatio;
        }

        return Center(
          child: Align(
            alignment: Alignment.topCenter,
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              boundaryMargin: const EdgeInsets.all(40),
              clipBehavior: Clip.none,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color:
                      _argbToColor(slide.backgroundColorArgb) ?? Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: c.border, width: 0.7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(context.isDark ? 34 : 12),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: _PresentationSlideCanvas(
                    document: document,
                    slide: slide,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PresentationSlideCanvas extends StatelessWidget {
  const _PresentationSlideCanvas({required this.document, required this.slide});

  final PresentationPreviewDocument document;
  final PresentationPreviewSlide slide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = constraints.maxWidth / document.slideWidth;
        final scaleY = constraints.maxHeight / document.slideHeight;
        return Stack(
          children: [
            for (final element in slide.elements)
              _PresentationElementView(
                element: element,
                slide: slide,
                document: document,
                scaleX: scaleX,
                scaleY: scaleY,
              ),
          ],
        );
      },
    );
  }
}

class _PresentationElementView extends StatelessWidget {
  const _PresentationElementView({
    required this.element,
    required this.slide,
    required this.document,
    required this.scaleX,
    required this.scaleY,
  });

  final PresentationPreviewElement element;
  final PresentationPreviewSlide slide;
  final PresentationPreviewDocument document;
  final double scaleX;
  final double scaleY;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: element.x * scaleX,
      top: element.y * scaleY,
      width: element.width * scaleX,
      height: element.height * scaleY,
      child: switch (element) {
        PresentationTextElement() => _PresentationTextBox(
          element: element as PresentationTextElement,
          slide: slide,
          scaleY: scaleY,
        ),
        PresentationImageElement() => _PresentationImageBox(
          element: element as PresentationImageElement,
        ),
        PresentationTableElement() => _PresentationTableBox(
          element: element as PresentationTableElement,
          slide: slide,
          scaleY: scaleY,
        ),
      },
    );
  }
}

class _PresentationTextBox extends StatelessWidget {
  const _PresentationTextBox({
    required this.element,
    required this.slide,
    required this.scaleY,
  });

  final PresentationTextElement element;
  final PresentationPreviewSlide slide;
  final double scaleY;

  @override
  Widget build(BuildContext context) {
    final defaultTextColor =
        _argbToColor(slide.defaultTextColorArgb) ?? context.colors.text;
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = math.max(
          2.0,
          math.min(
            8.0,
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.08,
          ),
        );
        final availableWidth = math.max(
          1.0,
          constraints.maxWidth - padding * 2,
        );
        final availableHeight = math.max(
          1.0,
          constraints.maxHeight - padding * 2,
        );
        final content = _PresentationParagraphColumn(
          paragraphs: element.paragraphs,
          role: element.role,
          scaleY: scaleY,
          defaultTextColor: defaultTextColor,
        );

        return Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: _argbToColor(element.fillColorArgb),
            border: element.borderColorArgb == null
                ? null
                : Border.all(
                    color: _argbToColor(element.borderColorArgb)!,
                    width: math.max(0.6, scaleY),
                  ),
          ),
          child: ClipRect(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: FittedBox(
                alignment: Alignment.topLeft,
                fit: BoxFit.scaleDown,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: availableWidth,
                    maxHeight: availableHeight,
                  ),
                  child: content,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PresentationParagraphColumn extends StatelessWidget {
  const _PresentationParagraphColumn({
    required this.paragraphs,
    required this.role,
    required this.scaleY,
    required this.defaultTextColor,
  });

  final List<PresentationTextParagraph> paragraphs;
  final PresentationTextRole role;
  final double scaleY;
  final Color defaultTextColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final paragraph in paragraphs)
          Padding(
            padding: EdgeInsets.only(
              bottom: math.max(1.0, 3.0 * scaleY * 12700),
              left: paragraph.bullet
                  ? paragraph.level *
                        math.max(
                          4.0,
                          ((_effectiveFontSize(paragraph) * 0.7).clamp(
                            4.0,
                            14.0,
                          )),
                        )
                  : 0,
            ),
            child: paragraph.bullet
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: math.max(
                            1.0,
                            _effectiveFontSize(paragraph) * 0.45,
                          ),
                          right: math.max(
                            4.0,
                            _effectiveFontSize(paragraph) * 0.55,
                          ),
                        ),
                        child: Container(
                          width: math.max(
                            3.0,
                            _effectiveFontSize(paragraph) * 0.34,
                          ),
                          height: math.max(
                            3.0,
                            _effectiveFontSize(paragraph) * 0.34,
                          ),
                          decoration: BoxDecoration(
                            color:
                                _argbToColor(paragraph.colorArgb) ??
                                defaultTextColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Flexible(
                        child: _PresentationParagraphText(
                          paragraph: paragraph,
                          role: role,
                          scaleY: scaleY,
                          defaultColor: defaultTextColor,
                        ),
                      ),
                    ],
                  )
                : _PresentationParagraphText(
                    paragraph: paragraph,
                    role: role,
                    scaleY: scaleY,
                    defaultColor: defaultTextColor,
                  ),
          ),
      ],
    );
  }

  double _effectiveFontSize(PresentationTextParagraph paragraph) {
    final base = (paragraph.fontSizePt ?? 16) * 12700 * scaleY;
    return switch (role) {
      PresentationTextRole.title => math.max(10.0, base * 1.04),
      PresentationTextRole.subtitle => math.max(9.5, base * 1.0),
      PresentationTextRole.caption => math.max(8.0, base * 0.92),
      PresentationTextRole.body => math.max(8.8, base),
    };
  }
}

class _PresentationParagraphText extends StatelessWidget {
  const _PresentationParagraphText({
    required this.paragraph,
    required this.role,
    required this.scaleY,
    required this.defaultColor,
  });

  final PresentationTextParagraph paragraph;
  final PresentationTextRole role;
  final double scaleY;
  final Color defaultColor;

  @override
  Widget build(BuildContext context) {
    final fontSize = (paragraph.fontSizePt ?? 16) * 12700 * scaleY;
    final adjustedFontSize = switch (role) {
      PresentationTextRole.title => math.max(10.0, fontSize * 1.04),
      PresentationTextRole.subtitle => math.max(9.5, fontSize),
      PresentationTextRole.caption => math.max(8.0, fontSize * 0.92),
      PresentationTextRole.body => math.max(8.8, fontSize),
    };

    return Text(
      paragraph.text,
      maxLines: null,
      textAlign: switch (paragraph.align) {
        PresentationTextAlign.center => TextAlign.center,
        PresentationTextAlign.end => TextAlign.end,
        PresentationTextAlign.justify => TextAlign.justify,
        PresentationTextAlign.start => TextAlign.start,
      },
      style: TextStyle(
        color: _argbToColor(paragraph.colorArgb) ?? defaultColor,
        fontSize: adjustedFontSize,
        fontWeight: paragraph.bold ? FontWeight.w700 : FontWeight.w500,
        height: role == PresentationTextRole.title ? 1.14 : 1.35,
      ),
    );
  }
}

class _PresentationImageBox extends StatelessWidget {
  const _PresentationImageBox({required this.element});

  final PresentationImageElement element;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: element.borderColorArgb == null
            ? null
            : Border.all(
                color: _argbToColor(element.borderColorArgb)!,
                width: 0.8,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.memory(
          element.bytes,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => Container(
            color: context.colors.surface,
            alignment: Alignment.center,
            child: Icon(
              Icons.broken_image_outlined,
              color: context.colors.subtitle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PresentationTableBox extends StatelessWidget {
  const _PresentationTableBox({
    required this.element,
    required this.slide,
    required this.scaleY,
  });

  final PresentationTableElement element;
  final PresentationPreviewSlide slide;
  final double scaleY;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        _argbToColor(element.borderColorArgb) ?? context.colors.border;
    final defaultTextColor =
        _argbToColor(slide.defaultTextColorArgb) ?? context.colors.text;
    final fontSize = math.max(8.5, 14 * 12700 * scaleY);

    return Container(
      decoration: BoxDecoration(
        color: _argbToColor(element.fillColorArgb) ?? Colors.white,
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        children: [
          for (final row in element.rows)
            Expanded(
              child: Row(
                children: [
                  for (final cell in row.cells)
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: math.max(4.0, 6.0 * scaleY),
                          vertical: math.max(3.0, 5.0 * scaleY),
                        ),
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(color: borderColor, width: 0.6),
                            bottom: BorderSide(color: borderColor, width: 0.6),
                          ),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          cell,
                          style: TextStyle(
                            color: defaultTextColor,
                            fontSize: fontSize,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Color? _argbToColor(int? value) => value == null ? null : Color(value);
