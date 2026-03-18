/// Responsive breakpoints and layout utilities.
///
/// - compact: < 600dp (phone)
/// - medium: 600–840dp (small tablet / foldable)
/// - expanded: > 840dp (large tablet / desktop)
library;

import 'package:flutter/widgets.dart';

enum LayoutType { compact, medium, expanded }

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

/// Number of grid columns for course cards.
int courseGridColumns(BuildContext context) {
  return switch (layoutTypeOf(context)) {
    LayoutType.compact => 2,
    LayoutType.medium => 3,
    LayoutType.expanded => 4,
  };
}

/// Content max width for readability on very wide screens.
double contentMaxWidth(BuildContext context) {
  return switch (layoutTypeOf(context)) {
    LayoutType.compact => double.infinity,
    LayoutType.medium => 720,
    LayoutType.expanded => 960,
  };
}

/// Wrapper that centers and constrains content width on wide screens.
class ResponsiveContent extends StatelessWidget {
  final Widget child;

  const ResponsiveContent({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final maxWidth = contentMaxWidth(context);
    if (maxWidth == double.infinity) return child;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
