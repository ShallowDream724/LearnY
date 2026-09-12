import 'package:flutter/material.dart';

import '../design/app_theme_colors.dart';
import '../design/app_surfaces.dart';
import '../design/frosted_navigation_surface.dart';
import '../design/typography.dart';
import 'shell_layout_metrics.dart';

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
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final foreground = dark ? const Color(0xFFF0F2F8) : const Color(0xFF20242C);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          kShellBottomNavTopGap,
          20,
          kShellBottomNavBottomGap,
        ),
        child: Align(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: FrostedNavigationSurface(
              child: NavigationBarTheme(
                data: NavigationBarTheme.of(context).copyWith(
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => AppTypography.labelSmall.copyWith(
                      color: foreground,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  iconTheme: WidgetStatePropertyAll(
                    IconThemeData(color: foreground, size: 24),
                  ),
                ),
                child: NavigationBar(
                  height: kShellBottomNavBaseHeight,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  indicatorColor: dark
                      ? Colors.white.withAlpha(28)
                      : Colors.black.withAlpha(16),
                  indicatorShape: const StadiumBorder(),
                  animationDuration: AppMotion.duration(
                    context,
                    AppMotion.feedback,
                  ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
