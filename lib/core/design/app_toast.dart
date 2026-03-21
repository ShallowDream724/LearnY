library;

import 'dart:ui';

import 'package:flutter/material.dart';

enum AppToastTone { success, info, warning, error }

class AppToast {
  static OverlayEntry? _current;

  static void show(
    BuildContext context, {
    required String message,
    AppToastTone tone = AppToastTone.info,
    Duration duration = const Duration(milliseconds: 2400),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    _current?.remove();
    _current = null;

    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (_) => _AppToastWidget(
        message: message,
        tone: tone,
        duration: duration,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismiss: () {
          entry.remove();
          if (_current == entry) {
            _current = null;
          }
        },
      ),
    );

    _current = entry;
    overlay.insert(entry);
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2400),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      tone: AppToastTone.success,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2400),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      tone: AppToastTone.info,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2600),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      tone: AppToastTone.warning,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 3000),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      tone: AppToastTone.error,
      duration: duration,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class _AppToastWidget extends StatefulWidget {
  const _AppToastWidget({
    required this.message,
    required this.tone,
    required this.duration,
    required this.onDismiss,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppToastTone tone;
  final Duration duration;
  final VoidCallback onDismiss;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    final totalMs = widget.duration.inMilliseconds.clamp(1600, 6000);
    final enterWeight = 260 / totalMs;
    final exitWeight = 520 / totalMs;
    final holdWeight = 1 - enterWeight - exitWeight;

    _controller = AnimationController(vsync: this, duration: widget.duration);
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: -1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: enterWeight,
      ),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: holdWeight),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: -1.0,
        ).chain(CurveTween(curve: Curves.easeInCubic)),
        weight: exitWeight,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: enterWeight,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: holdWeight),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: exitWeight,
      ),
    ]).animate(_controller);

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final accentColor = _accentColor(widget.tone);
    final icon = _icon(widget.tone);
    final textColor = isDark
        ? Colors.white.withAlpha(220)
        : Colors.black.withAlpha(200);

    return IgnorePointer(
      ignoring: false,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: topPadding + 4),
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value * 60),
                child: Opacity(
                  opacity: _opacityAnimation.value.clamp(0.0, 1.0),
                  child: child,
                ),
              ),
            ),
          );
        },
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 24,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xCC2C2C2E)
                        : const Color(0xCCF2F2F7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(20)
                          : Colors.black.withAlpha(10),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 40 : 15),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null &&
                          widget.onAction != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            widget.onAction!.call();
                            widget.onDismiss();
                          },
                          child: Text(
                            widget.actionLabel!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _accentColor(AppToastTone tone) {
    switch (tone) {
      case AppToastTone.success:
        return const Color(0xFF34C759);
      case AppToastTone.info:
        return const Color(0xFF007AFF);
      case AppToastTone.warning:
        return const Color(0xFFFF9500);
      case AppToastTone.error:
        return const Color(0xFFFF3B30);
    }
  }

  IconData _icon(AppToastTone tone) {
    switch (tone) {
      case AppToastTone.success:
        return Icons.check_circle_rounded;
      case AppToastTone.info:
        return Icons.info_rounded;
      case AppToastTone.warning:
        return Icons.warning_amber_rounded;
      case AppToastTone.error:
        return Icons.error_rounded;
    }
  }
}
