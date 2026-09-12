import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../design/app_theme_colors.dart';
import '../design/app_surfaces.dart';
import '../design/frosted_navigation_surface.dart';
import 'shell_layout_metrics.dart';
import 'shell_navigation_progress.dart';

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

class AppBottomNavigation extends StatefulWidget {
  const AppBottomNavigation({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.progress,
    required this.onTap,
  });
  final List<ShellNavDestinationData> destinations;
  final int selectedIndex;
  final ShellNavigationProgress progress;
  final ValueChanged<int> onTap;

  @override
  State<AppBottomNavigation> createState() => _AppBottomNavigationState();
}

class _AppBottomNavigationState extends State<AppBottomNavigation>
    with SingleTickerProviderStateMixin {
  late final _position = AnimationController.unbounded(
    vsync: this,
    value: widget.progress.value,
  );

  @override
  void initState() {
    super.initState();
    widget.progress.addListener(_followProgress);
  }

  @override
  void didUpdateWidget(AppBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      oldWidget.progress.removeListener(_followProgress);
      widget.progress.addListener(_followProgress);
      _followProgress();
    }
  }

  void _followProgress() {
    if (widget.progress.animate && !MediaQuery.disableAnimationsOf(context)) {
      _position.animateTo(
        widget.progress.value,
        duration: const Duration(milliseconds: 230),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _position.value = widget.progress.value;
    }
  }

  @override
  void dispose() {
    widget.progress.removeListener(_followProgress);
    _position.dispose();
    super.dispose();
  }

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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SelectionLens(
                            position: _position,
                            count: widget.destinations.length,
                            dark: dark,
                            highContrast: MediaQuery.highContrastOf(context),
                          ),
                        ),
                      ),
                    ),
                    NavigationBarTheme(
                      data: NavigationBarTheme.of(context).copyWith(
                        iconTheme: WidgetStatePropertyAll(
                          IconThemeData(color: foreground, size: 28),
                        ),
                      ),
                      child: NavigationBar(
                        height: kShellBottomNavBaseHeight,
                        backgroundColor: Colors.transparent,
                        surfaceTintColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        elevation: 0,
                        indicatorColor: Colors.transparent,
                        indicatorShape: const StadiumBorder(),
                        labelBehavior:
                            NavigationDestinationLabelBehavior.alwaysHide,
                        animationDuration: AppMotion.duration(
                          context,
                          AppMotion.feedback,
                        ),
                        selectedIndex: widget.selectedIndex,
                        onDestinationSelected: widget.onTap,
                        destinations: [
                          for (final destination in widget.destinations)
                            NavigationDestination(
                              icon: Icon(destination.icon),
                              selectedIcon: Icon(destination.icon),
                              label: destination.label,
                            ),
                        ],
                      ),
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

class _SelectionLens extends CustomPainter {
  _SelectionLens({
    required this.position,
    required this.count,
    required this.dark,
    required this.highContrast,
  }) : super(repaint: position);

  final Animation<double> position;
  final int count;
  final bool dark;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / count;
    final rect = Rect.fromCenter(
      center: Offset(slot * (position.value + .5), size.height / 2),
      width: math.min(64, slot - 8),
      height: size.height - 16,
    );
    final shape = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [
                  Colors.white.withAlpha(highContrast ? 85 : 38),
                  Colors.white.withAlpha(18),
                ]
              : [
                  Colors.white.withAlpha(highContrast ? 230 : 145),
                  const Color(0x163C3B3A),
                ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape.deflate(.4),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = dark ? const Color(0x48FFFFFF) : const Color(0xA8FFFFFF),
    );
    if (highContrast) {
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = dark ? Colors.white : Colors.black54,
      );
    }
  }

  @override
  bool shouldRepaint(_SelectionLens oldDelegate) =>
      position != oldDelegate.position ||
      count != oldDelegate.count ||
      dark != oldDelegate.dark ||
      highContrast != oldDelegate.highContrast;
}
