/// Explains a refresh cooldown without making a new freshness claim.
library;

import 'package:flutter/material.dart';

import 'app_toast.dart';

class CooldownToast {
  /// Show a cooldown toast. [seconds] = remaining cooldown.
  static void show(BuildContext context, {required int seconds}) {
    AppToast.showInfo(
      context,
      message: '刚刚已刷新，$seconds 秒后可再试',
      duration: const Duration(milliseconds: 2500),
    );
  }
}
