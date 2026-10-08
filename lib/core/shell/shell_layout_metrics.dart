import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import '../design/responsive.dart';

const double kShellBottomNavBaseHeight = 64.0;
const double kShellBottomNavTopGap = 8.0;
const double kShellBottomNavBottomGap = 12.0;
const double kShellBottomNavContentPeekGap = 8.0;

double shellBottomNavBarHeight(BuildContext context) {
  if (shouldShowRail(context) || MediaQuery.viewInsetsOf(context).bottom > 0) {
    return 0;
  }
  return kShellBottomNavBaseHeight +
      kShellBottomNavTopGap +
      kShellBottomNavBottomGap +
      MediaQuery.viewPaddingOf(context).bottom;
}

double shellContentBottomInset(
  BuildContext context, {
  double extraSpacing = 0,
}) {
  // Nested Scaffolds may consume the padding injected by extendBody. Keep the
  // shell's actual obstruction as a floor instead of relying on that padding.
  return math.max(
        MediaQuery.paddingOf(context).bottom,
        shellBottomNavBarHeight(context),
      ) +
      kShellBottomNavContentPeekGap +
      extraSpacing;
}
