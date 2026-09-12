import 'dart:math' as math;

import 'package:flutter/material.dart';

enum AppToastTone { success, info, warning, error }

/// Transient feedback uses the app's route-aware, accessible notification host.
abstract final class AppToast {
  /// Capture the list/route host before an awaited action can remove its row.
  static AppToastHost capture(BuildContext context) => AppToastHost._(
    ScaffoldMessenger.of(context),
    Theme.of(context),
    math.min(560, MediaQuery.sizeOf(context).width - 32),
  );

  static void show(
    BuildContext context, {
    required String message,
    AppToastTone tone = AppToastTone.info,
    Duration duration = const Duration(milliseconds: 2400),
    String? actionLabel,
    VoidCallback? onAction,
  }) => capture(context).show(
    message: message,
    tone: tone,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2400),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    tone: AppToastTone.success,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2400),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2600),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    tone: AppToastTone.warning,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 3000),
    String? actionLabel,
    VoidCallback? onAction,
  }) => show(
    context,
    message: message,
    tone: AppToastTone.error,
    duration: duration,
    actionLabel: actionLabel,
    onAction: onAction,
  );
}

class AppToastHost {
  const AppToastHost._(this._messenger, this._theme, this._width);
  final ScaffoldMessengerState _messenger;
  final ThemeData _theme;
  final double _width;

  void show({
    required String message,
    AppToastTone tone = AppToastTone.info,
    Duration duration = const Duration(milliseconds: 2400),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!_messenger.mounted) return;
    final currentWidth = MediaQuery.maybeSizeOf(_messenger.context)?.width;
    final icon = switch (tone) {
      AppToastTone.success => Icons.check_circle_outline,
      AppToastTone.info => Icons.info_outline,
      AppToastTone.warning => Icons.warning_amber_rounded,
      AppToastTone.error => Icons.error_outline,
    };
    final action = actionLabel != null && onAction != null
        ? SnackBarAction(label: actionLabel, onPressed: onAction)
        : null;
    _messenger.removeCurrentSnackBar();
    _messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        width: currentWidth == null
            ? _width
            : math.min(_width, currentWidth - 32),
        duration: action != null && duration < const Duration(seconds: 8)
            ? const Duration(seconds: 8)
            : duration,
        showCloseIcon: true,
        action: action,
        content: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: tone == AppToastTone.error
                  ? _theme.colorScheme.error
                  : _theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
