import 'package:flutter/widgets.dart';

const double kShellBottomNavBaseHeight = 54.0;
const double kShellBottomNavContentPeekGap = 8.0;

double shellBottomNavBarHeight(BuildContext context) {
  return kShellBottomNavBaseHeight + MediaQuery.paddingOf(context).bottom;
}

double shellContentBottomInset(
  BuildContext context, {
  double extraSpacing = 0,
}) {
  return MediaQuery.paddingOf(context).bottom +
      kShellBottomNavContentPeekGap +
      extraSpacing;
}
