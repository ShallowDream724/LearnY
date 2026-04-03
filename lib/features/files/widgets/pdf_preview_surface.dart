import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart'
    show CupertinoTheme, CupertinoThemeData, cupertinoTextSelectionControls;
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_toast.dart';
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
  static const _selectionHandleHitBoxSize = 44.0;
  static const _leftSelectionHandleVerticalBias = 0.48;
  static const _scrollThumbWidth = 6.0;
  static const _scrollThumbHeight = 52.0;

  late final PdfViewerController _controller;
  late final TextEditingController _pageInputController;
  late final FocusNode _pageInputFocusNode;
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
    _pageInputController = TextEditingController(text: '1');
    _pageInputFocusNode = FocusNode()
      ..addListener(() {
        if (!mounted) {
          return;
        }
        if (_pageInputFocusNode.hasFocus) {
          _chromeTimer?.cancel();
          if (!_chromeVisible) {
            setState(() => _chromeVisible = true);
          } else {
            setState(() {});
          }
          return;
        }
        setState(() {});
        if (!_hasSelectedText && !_isDraggingSelectionHandle) {
          _showChrome();
        }
      });
  }

  @override
  void dispose() {
    _chromeTimer?.cancel();
    _pageInputController.dispose();
    _pageInputFocusNode.dispose();
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
    if (_hasSelectedText ||
        _isDraggingSelectionHandle ||
        _pageInputFocusNode.hasFocus) {
      return;
    }
    _chromeTimer = Timer(_chromeHideDelay, () {
      if (!mounted ||
          _hasSelectedText ||
          _isDraggingSelectionHandle ||
          _pageInputFocusNode.hasFocus) {
        return;
      }
      setState(() => _chromeVisible = false);
    });
  }

  void _hideChromeImmediately() {
    _chromeTimer?.cancel();
    if (!mounted || !_chromeVisible || _pageInputFocusNode.hasFocus) {
      return;
    }
    setState(() => _chromeVisible = false);
  }

  void _syncPageInput({bool preserveSelection = false}) {
    final nextText = _currentPage.toString();
    if (_pageInputController.text == nextText) {
      return;
    }
    final selection = preserveSelection
        ? _pageInputController.selection
        : TextSelection.collapsed(offset: nextText.length);
    _pageInputController.value = TextEditingValue(
      text: nextText,
      selection: selection,
      composing: TextRange.empty,
    );
  }

  Future<void> _submitPageJump() async {
    final raw = _pageInputController.text.trim();
    final target = int.tryParse(raw);
    if (target == null || target < 1 || target > _pageCount) {
      AppToast.showWarning(context, message: '请输入 1 - $_pageCount 的页码');
      _syncPageInput();
      return;
    }

    await _controller.goToPage(pageNumber: target, anchor: PdfPageAnchor.top);
    if (!mounted) {
      return;
    }
    _pageInputFocusNode.unfocus();
    _syncPageInput();
    _showChrome();
  }

  Widget _buildViewerScrollThumb() {
    return PdfViewerScrollThumb(
      controller: _controller,
      orientation: ScrollbarOrientation.right,
      margin: 10,
      thumbSize: const Size(_scrollThumbWidth, _scrollThumbHeight),
      thumbBuilder: (context, thumbSize, pageNumber, controller) {
        return IgnorePointer(
          ignoring: _hasSelectedText,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: _hasSelectedText ? 0 : (_chromeVisible ? 0.96 : 0.68),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF1F2430).withAlpha(
                  context.isDark ? 176 : 148,
                ),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withAlpha(context.isDark ? 28 : 42),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SizedBox(width: thumbSize.width, height: thumbSize.height),
            ),
          ),
        );
      },
    );
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
    final items = <ContextMenuButtonItem>[
      if (params.isTextSelectionEnabled &&
          params.textSelectionDelegate.isCopyAllowed &&
          params.textSelectionDelegate.hasSelectedText)
        ContextMenuButtonItem(
          type: ContextMenuButtonType.copy,
          onPressed: () async {
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
        ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll,
          onPressed: () async {
            params.dismissContextMenu();
            await params.textSelectionDelegate.selectAllText();
          },
        ),
      ContextMenuButtonItem(
        label: '收起',
        onPressed: () async {
          params.dismissContextMenu();
          await params.textSelectionDelegate.clearTextSelection();
        },
      ),
    ];

    if (items.isEmpty) {
      return null;
    }

    return Align(
      alignment: Alignment.topLeft,
      child: AdaptiveTextSelectionToolbar.buttonItems(
        anchors: TextSelectionToolbarAnchors(
          primaryAnchor: params.anchorA,
          secondaryAnchor: params.anchorB,
        ),
        buttonItems: items,
      ),
    );
  }

  Widget _buildSelectionHandle(
    BuildContext context,
    PdfTextSelectionAnchor anchor,
    PdfViewerTextSelectionAnchorHandleState _,
  ) {
    final c = context.colors;
    final geometry = _selectionHandleGeometry(anchor);

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: context.isDark ? Brightness.dark : Brightness.light,
        selectionHandleColor: c.infoAccent,
      ),
      child: SizedBox(
        width: geometry.containerSize.width,
        height: geometry.containerSize.height,
        child: Stack(
          children: [
            Positioned(
              left: geometry.childOffset.dx,
              top: geometry.childOffset.dy,
              child: cupertinoTextSelectionControls.buildHandle(
                context,
                geometry.handleType,
                geometry.lineExtent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Offset _selectionHandleOffset(
    BuildContext context,
    PdfTextSelectionAnchor anchor,
    PdfViewerTextSelectionAnchorHandleState _,
  ) {
    return _selectionHandleGeometry(anchor).anchorOffset;
  }

  TextSelectionHandleType _selectionHandleType(PdfTextSelectionAnchor anchor) {
    return switch (anchor.direction) {
      PdfTextDirection.ltr || PdfTextDirection.unknown =>
        anchor.type == PdfTextSelectionAnchorType.a
            ? TextSelectionHandleType.left
            : TextSelectionHandleType.right,
      PdfTextDirection.rtl || PdfTextDirection.vrtl =>
        anchor.type == PdfTextSelectionAnchorType.a
            ? TextSelectionHandleType.right
            : TextSelectionHandleType.left,
    };
  }

  double _selectionHandleLineExtent(PdfTextSelectionAnchor anchor) {
    final rect = anchor.rect;
    final extent = switch (anchor.direction) {
      PdfTextDirection.vrtl => rect.width,
      PdfTextDirection.ltr ||
      PdfTextDirection.rtl ||
      PdfTextDirection.unknown => rect.height,
    };
    return extent.clamp(18.0, 42.0);
  }

  _SelectionHandleGeometry _selectionHandleGeometry(
    PdfTextSelectionAnchor anchor,
  ) {
    final handleType = _selectionHandleType(anchor);
    final lineExtent = _selectionHandleLineExtent(anchor);
    final handleSize = cupertinoTextSelectionControls.getHandleSize(
      lineExtent,
    );
    final handleAnchor = cupertinoTextSelectionControls.getHandleAnchor(
      handleType,
      lineExtent,
    );
    final containerSize = Size(
      math.max(handleSize.width, _selectionHandleHitBoxSize),
      math.max(handleSize.height, _selectionHandleHitBoxSize),
    );
    final childOffset = Offset(
      math.max((containerSize.width - handleSize.width) / 2, 0),
      math.max((containerSize.height - handleSize.height) / 2, 0),
    );
    final anchorInContainer = childOffset + handleAnchor;
    final verticalBias = handleType == TextSelectionHandleType.left
        ? lineExtent * _leftSelectionHandleVerticalBias
        : 0.0;

    return _SelectionHandleGeometry(
      handleType: handleType,
      lineExtent: lineExtent,
      containerSize: containerSize,
      childOffset: childOffset,
      anchorOffset: switch (handleType) {
        TextSelectionHandleType.left => Offset(
          containerSize.width - anchorInContainer.dx,
          containerSize.height - anchorInContainer.dy + verticalBias,
        ),
        TextSelectionHandleType.right ||
        TextSelectionHandleType.collapsed => -anchorInContainer,
      },
    );
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
              _syncPageInput();
              _showChrome();
            },
            onPageChanged: (pageNumber) {
              if (!mounted || pageNumber == null) {
                return;
              }
              setState(() => _currentPage = pageNumber);
              if (!_pageInputFocusNode.hasFocus) {
                _syncPageInput();
              }
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
            viewerOverlayBuilder: (context, size, handleLinkTap) => [
              _buildViewerScrollThumb(),
            ],
            textSelectionParams: PdfTextSelectionParams(
              enabled: true,
              enableSelectionHandles: true,
              showContextMenuAutomatically: true,
              buildSelectionHandle: _buildSelectionHandle,
              calcSelectionHandleOffset: _selectionHandleOffset,
              onTextSelectionChange: _handleSelectionChanged,
              onSelectionHandlePanStart: _handleSelectionPanStart,
              onSelectionHandlePanEnd: _handleSelectionPanEnd,
              magnifier: PdfViewerSelectionMagnifierParams(
                enabled: true,
                magnifierSizeThreshold: 120,
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
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                opacity: _hasSelectedText ? 0 : (_chromeVisible ? 1 : 0.72),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _chromeVisible || _pageInputFocusNode.hasFocus
                      ? _PdfPageJumpBar(
                          key: const ValueKey('page-jump-bar'),
                          controller: _pageInputController,
                          focusNode: _pageInputFocusNode,
                          pageCount: _pageCount,
                          onSubmitted: (_) => _submitPageJump(),
                          onGo: _submitPageJump,
                        )
                      : _PdfPageChip(
                          key: const ValueKey('page-chip'),
                          label: '$_currentPage / $_pageCount',
                          compact: true,
                          onTap: () {
                            _showChrome();
                            _pageInputFocusNode.requestFocus();
                            _pageInputController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _pageInputController.text.length,
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectionHandleGeometry {
  const _SelectionHandleGeometry({
    required this.handleType,
    required this.lineExtent,
    required this.containerSize,
    required this.childOffset,
    required this.anchorOffset,
  });

  final TextSelectionHandleType handleType;
  final double lineExtent;
  final Size containerSize;
  final Offset childOffset;
  final Offset anchorOffset;
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
  const _PdfPageChip({
    super.key,
    required this.label,
    required this.compact,
    this.onTap,
  });

  final String label;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
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
        ),
      ),
    );
  }
}

class _PdfPageJumpBar extends StatelessWidget {
  const _PdfPageJumpBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.pageCount,
    required this.onSubmitted,
    required this.onGo,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int pageCount;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onGo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(148),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha(18), width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 6, 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 56,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.go,
                onSubmitted: onSubmitted,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: ['monospace'],
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '页码',
                  hintStyle: TextStyle(
                    color: Colors.white.withAlpha(115),
                    fontSize: 11,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: Colors.white.withAlpha(36),
                      width: 0.8,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '/ $pageCount',
                style: TextStyle(
                  color: Colors.white.withAlpha(232),
                  fontSize: 12,
                  fontFamily: 'JetBrains Mono',
                  fontFamilyFallback: const ['monospace'],
                ),
              ),
            ),
            SizedBox(
              height: 32,
              child: FilledButton(
                onPressed: onGo,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(26),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ).copyWith(elevation: const WidgetStatePropertyAll(0)),
                child: const Text(
                  '跳转',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
