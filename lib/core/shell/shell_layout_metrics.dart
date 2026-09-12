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
  return MediaQuery.paddingOf(context).bottom +
      kShellBottomNavContentPeekGap +
      extraSpacing;
}
