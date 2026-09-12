import 'package:flutter/material.dart';

import 'glass_surface.dart';

/// Navigation's shape/preset; all optical rendering is reusable in other panes.
class FrostedNavigationSurface extends StatelessWidget {
  const FrostedNavigationSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => GlassSurface(radius: 999, child: child);
}
