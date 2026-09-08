/// Responsive breakpoints and layout utilities.
///
/// - compact: < 600dp (phone)
/// - medium: 600–840dp (small tablet / foldable)
/// - expanded: > 840dp (large tablet / desktop)
library;

import 'package:flutter/material.dart';

enum LayoutType { compact, medium, expanded }

bool usesDesktopControls(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// Get the current layout type based on screen width.
LayoutType layoutTypeOf(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= 840) return LayoutType.expanded;
  if (width >= 600) return LayoutType.medium;
  return LayoutType.compact;
}

/// Whether the current layout should show a side navigation rail.
bool shouldShowRail(BuildContext context) =>
    layoutTypeOf(context) != LayoutType.compact;
