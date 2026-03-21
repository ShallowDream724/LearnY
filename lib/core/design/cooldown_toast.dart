/// Apple-style cooldown toast — a capsule pill that slides down from the
/// top of the screen with frosted glass background.
///
/// Usage:
///   CooldownToast.show(context, seconds: 23);
///
/// Design:
/// - Slides down from behind SafeArea with spring curve
/// - Frosted glass capsule (BackdropFilter blur)
/// - Checkmark icon + "已是最新 · Xs 后可刷新"
/// - Auto-dismisses after 2s with fade-out
/// - Only one toast at a time (previous dismissed)
library;

import 'package:flutter/material.dart';

import 'app_toast.dart';

class CooldownToast {
  /// Show a cooldown toast. [seconds] = remaining cooldown.
  static void show(BuildContext context, {required int seconds}) {
    AppToast.showSuccess(
      context,
      message: '已是最新 · ${seconds}s 后可刷新',
      duration: const Duration(milliseconds: 2500),
    );
  }
}
