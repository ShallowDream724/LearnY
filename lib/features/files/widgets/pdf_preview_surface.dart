import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_toast.dart';
import '../../../core/design/typography.dart';
import 'file_preview_feedback.dart';

class PdfPreviewSurface extends StatefulWidget {
  const PdfPreviewSurface({
    super.key,
    required this.filePath,
    required this.onOpenExternal,
  });

  final String filePath;
  final VoidCallback onOpenExternal;

  @override
  State<PdfPreviewSurface> createState() => _PdfPreviewSurfaceState();
}

class _PdfPreviewSurfaceState extends State<PdfPreviewSurface> {
  static const _chromeHideDelay = Duration(seconds: 3);

  late final PdfViewerController _controller;
  Timer? _chromeTimer;

  int _pageCount = 0;
  int _currentPage = 1;
  String? _errorMessage;
  bool _chromeVisible = true;
  bool _hasSelectedText = false;
  bool _isDraggingSelectionHandle = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfViewerController();
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    super.dispose();
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
    _showChrome();
  }

  void _showChrome() {
    _chromeTimer?.cancel();
    if (!_hasSelectedText && mounted && !_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
    if (_hasSelectedText || _isDraggingSelectionHandle) {
      return;
    }
    _chromeTimer = Timer(_chromeHideDelay, () {
      if (!mounted || _hasSelectedText || _isDraggingSelectionHandle) {
        return;
      }
      setState(() => _chromeVisible = false);
    });
  }

  void _hideChromeImmediately() {
    _chromeTimer?.cancel();
    if (!mounted || !_chromeVisible) {
      return;
    }
    setState(() => _chromeVisible = false);
  }

  void _handleSelectionChanged(PdfTextSelection selection) {
    final hasSelectedText = selection.hasSelectedText;
    if (!mounted || _hasSelectedText == hasSelectedText) {
      return;
    }
    setState(() {
      _hasSelectedText = hasSelectedText;
      if (hasSelectedText) {
        _chromeVisible = false;
      }
    });
    if (hasSelectedText) {
      _chromeTimer?.cancel();
    } else {
      _showChrome();
    }
  }

  void _handleSelectionPanStart(PdfTextSelectionAnchor _) {
    _chromeTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _isDraggingSelectionHandle = true;
      _chromeVisible = false;
    });
  }

  void _handleSelectionPanEnd(PdfTextSelectionAnchor _) {
    if (!mounted) {
      return;
    }
    setState(() => _isDraggingSelectionHandle = false);
  }

  bool _handleGeneralTap(
    BuildContext context,
    PdfViewerController controller,
    PdfViewerGeneralTapHandlerDetails details,
  ) {
    switch (details.type) {
      case PdfViewerGeneralTapType.tap:
        if (_hasSelectedText) {
          return false;
        }
        if (_chromeVisible) {
          _hideChromeImmediately();
        } else {
          _showChrome();
        }
        return false;
      case PdfViewerGeneralTapType.doubleTap:
      case PdfViewerGeneralTapType.longPress:
      case PdfViewerGeneralTapType.secondaryTap:
        _chromeTimer?.cancel();
        return false;
    }
  }

  Widget? _buildContextMenu(
    BuildContext context,
    PdfViewerContextMenuBuilderParams params,
  ) {
    final actions = <_PdfSelectionAction>[
      if (params.isTextSelectionEnabled &&
          params.textSelectionDelegate.isCopyAllowed &&
          params.textSelectionDelegate.hasSelectedText)
        _PdfSelectionAction(
          icon: Icons.content_copy_rounded,
          label: '复制',
          onTap: () async {
            final copied = await params.textSelectionDelegate
                .copyTextSelection();
            params.dismissContextMenu();
            if (!mounted) {
              return;
            }
            if (!copied) {
              AppToast.showWarning(this.context, message: '当前文本无法复制');
              return;
            }
            await params.textSelectionDelegate.clearTextSelection();
          },
        ),
      if (params.isTextSelectionEnabled &&
          !params.textSelectionDelegate.isSelectingAllText)
        _PdfSelectionAction(
          icon: Icons.select_all_rounded,
          label: '全选',
          onTap: () async {
            params.dismissContextMenu();
            await params.textSelectionDelegate.selectAllText();
          },
        ),
      _PdfSelectionAction(
        icon: Icons.close_rounded,
        label: '收起',
        onTap: () async {
          params.dismissContextMenu();
          await params.textSelectionDelegate.clearTextSelection();
        },
      ),
    ];

    if (actions.isEmpty) {
      return null;
    }

    return _PdfSelectionToolbar(actions: actions);
  }

  Widget _buildSelectionHandle(
    BuildContext context,
    PdfTextSelectionAnchor anchor,
    PdfViewerTextSelectionAnchorHandleState state,
  ) {
    final c = context.colors;
    final gripAlignment = _handleGripAlignment(anchor);
    final gripSize = switch (state) {
      PdfViewerTextSelectionAnchorHandleState.dragging => 14.0,
      PdfViewerTextSelectionAnchorHandleState.hover => 13.0,
      PdfViewerTextSelectionAnchorHandleState.normal => 12.0,
    };
    final accent = c.infoAccent;
    final fill = switch (state) {
      PdfViewerTextSelectionAnchorHandleState.dragging => accent,
      PdfViewerTextSelectionAnchorHandleState.hover => accent.withAlpha(240),
      PdfViewerTextSelectionAnchorHandleState.normal => accent.withAlpha(228),
    };

    return SizedBox(
      width: 28,
      height: 28,
      child: Align(
        alignment: gripAlignment,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          width: gripSize,
          height: gripSize,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withAlpha(230), width: 1.6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(
                  state == PdfViewerTextSelectionAnchorHandleState.dragging
                      ? 28
                      : 18,
                ),
                blurRadius:
                    state == PdfViewerTextSelectionAnchorHandleState.dragging
                    ? 10
                    : 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Alignment _handleGripAlignment(PdfTextSelectionAnchor anchor) {
    return switch (anchor.direction) {
      PdfTextDirection.ltr || PdfTextDirection.unknown =>
        anchor.type == PdfTextSelectionAnchorType.a
            ? Alignment.topLeft
            : Alignment.bottomRight,
      PdfTextDirection.rtl || PdfTextDirection.vrtl =>
        anchor.type == PdfTextSelectionAnchorType.a
            ? Alignment.bottomLeft
            : Alignment.topRight,
    };
  }

  Widget _buildMagnifierDecoration(
    BuildContext context,
    PdfTextSelectionAnchor textAnchor,
    PdfViewerSelectionMagnifierParams params,
    Widget child,
    Size childSize,
    Offset pointerPosition,
    Offset magnifierPosition,
  ) {
    final scale = 68 / math.min(childSize.width, childSize.height);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(210), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(32),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          width: childSize.width * scale,
          height: childSize.height * scale,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    if (_errorMessage != null) {
      return PreviewUnavailable(
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
              color: Colors.black.withAlpha(context.isDark ? 40 : 16),
              blurRadius: 18,
              spreadRadius: 1.5,
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
              _showChrome();
            },
            onPageChanged: (pageNumber) {
              if (!mounted || pageNumber == null) {
                return;
              }
              setState(() => _currentPage = pageNumber);
              if (!_hasSelectedText) {
                _showChrome();
              }
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
            onGeneralTap: _handleGeneralTap,
            linkHandlerParams: PdfLinkHandlerParams(
              onLinkTap: (link) {
                unawaited(_handlePdfLink(link));
              },
            ),
            textSelectionParams: PdfTextSelectionParams(
              enabled: true,
              enableSelectionHandles: true,
              showContextMenuAutomatically: true,
              buildSelectionHandle: _buildSelectionHandle,
              onTextSelectionChange: _handleSelectionChanged,
              onSelectionHandlePanStart: _handleSelectionPanStart,
              onSelectionHandlePanEnd: _handleSelectionPanEnd,
              magnifier: PdfViewerSelectionMagnifierParams(
                animationDuration: const Duration(milliseconds: 80),
                builder: _buildMagnifierDecoration,
              ),
            ),
            buildContextMenu: _buildContextMenu,
            loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
              return const PreparingPreviewView();
            },
            errorBannerBuilder: (context, error, stackTrace, documentRef) {
              return PreviewUnavailable(
                message: 'PDF 预览失败：$error',
                onOpenExternal: widget.onOpenExternal,
              );
            },
          ),
        ),
        if (_pageCount > 0)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: IgnorePointer(
              ignoring: !_chromeVisible || _hasSelectedText,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                offset: _chromeVisible && !_hasSelectedText
                    ? Offset.zero
                    : const Offset(0, -0.14),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: _chromeVisible && !_hasSelectedText ? 1 : 0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        final canUseControls = _controller.isReady;
                        return _PdfChromeBar(
                          canUseControls: canUseControls,
                          onZoomOut: canUseControls
                              ? () => _controller.zoomDown()
                              : null,
                          onFitPage: canUseControls
                              ? () => _fitCurrentPage(fitWidth: false)
                              : null,
                          onFitWidth: canUseControls
                              ? () => _fitCurrentPage(fitWidth: true)
                              : null,
                          onZoomIn: canUseControls
                              ? () => _controller.zoomUp()
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_pageCount > 0)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: true,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  opacity: _hasSelectedText ? 0 : (_chromeVisible ? 1 : 0.58),
                  child: _PdfPageChip(
                    label: '$_currentPage / $_pageCount',
                    compact: !_chromeVisible,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PdfChromeBar extends StatelessWidget {
  const _PdfChromeBar({
    required this.canUseControls,
    required this.onZoomOut,
    required this.onFitPage,
    required this.onFitWidth,
    required this.onZoomIn,
  });

  final bool canUseControls;
  final VoidCallback? onZoomOut;
  final VoidCallback? onFitPage;
  final VoidCallback? onFitWidth;
  final VoidCallback? onZoomIn;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(148),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(18), width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PdfControlButton(
              icon: Icons.remove_rounded,
              tooltip: '缩小',
              onTap: onZoomOut,
            ),
            _PdfTextChip(
              label: '适页',
              onTap: onFitPage,
              enabled: canUseControls,
            ),
            _PdfTextChip(
              label: '适宽',
              onTap: onFitWidth,
              enabled: canUseControls,
            ),
            _PdfControlButton(
              icon: Icons.add_rounded,
              tooltip: '放大',
              onTap: onZoomIn,
            ),
          ],
        ),
      ),
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
      icon: Icon(
        icon,
        color: Colors.white.withAlpha(onTap == null ? 90 : 255),
        size: 18,
      ),
    );
  }
}

class _PdfTextChip extends StatelessWidget {
  const _PdfTextChip({
    required this.label,
    required this.onTap,
    required this.enabled,
  });

  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(enabled ? 24 : 10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(enabled ? 255 : 120),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _PdfPageChip extends StatelessWidget {
  const _PdfPageChip({required this.label, required this.compact});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(compact ? 126 : 148),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(18), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withAlpha(compact ? 228 : 255),
          fontSize: compact ? 11 : 12,
          fontFamily: 'JetBrains Mono',
          fontFamilyFallback: const ['monospace'],
        ),
      ),
    );
  }
}

class _PdfSelectionToolbar extends StatelessWidget {
  const _PdfSelectionToolbar({required this.actions});

  final List<_PdfSelectionAction> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(214),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(20), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                _PdfSelectionToolbarButton(action: actions[i]),
                if (i != actions.length - 1)
                  Container(
                    width: 1,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: Colors.white.withAlpha(18),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PdfSelectionToolbarButton extends StatelessWidget {
  const _PdfSelectionToolbarButton({required this.action});

  final _PdfSelectionAction action;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => unawaited(action.onTap()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              action.label,
              style: AppTypography.labelMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfSelectionAction {
  const _PdfSelectionAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onTap;
}
