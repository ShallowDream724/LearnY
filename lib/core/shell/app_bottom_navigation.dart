import 'package:flutter/material.dart';

import '../design/app_theme_colors.dart';
import '../design/app_surfaces.dart';

class ShellNavDestinationData {
  const ShellNavDestinationData({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onTap,
  });
  final List<ShellNavDestinationData> destinations;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: context.colors.border, width: .5)),
    ),
    child: NavigationBar(
      height: 64,
      animationDuration: AppMotion.duration(context, AppMotion.feedback),
      selectedIndex: selectedIndex,
      onDestinationSelected: onTap,
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          ),
      ],
    ),
  );
}
