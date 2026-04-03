library;

import 'dart:ui';

import 'package:flutter/material.dart';

import '../design/app_theme_colors.dart';
import '../design/typography.dart';
import 'shell_layout_metrics.dart';
import 'shell_nav_motion.dart';

class ShellNavDestinationData {
  const ShellNavDestinationData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class JellyBottomNavBar extends StatelessWidget {
  const JellyBottomNavBar({
    super.key,
    required this.destinations,
    required this.pageProgress,
    required this.onTap,
  });

  final List<ShellNavDestinationData> destinations;
  final double pageProgress;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final barHeight = shellBottomNavBarHeight(context);
    final clampedProgress = pageProgress.clamp(
      0.0,
      (destinations.length - 1).toDouble(),
    );

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: isDark
                ? c.surface.withAlpha(216)
                : Colors.white.withAlpha(218),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withAlpha(10)
                    : c.border.withAlpha(150),
                width: 0.6,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, bottomInset),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / destinations.length;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(
                      child: _TravelingSelectionLight(
                        itemWidth: itemWidth,
                        pageProgress: clampedProgress,
                        isDark: isDark,
                      ),
                    ),
                    Row(
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Expanded(
                            child: _NavItem(
                              destination: destinations[i],
                              selection: shellSelectionWeight(
                                clampedProgress,
                                i,
                              ),
                              localDelta: (clampedProgress - i).clamp(
                                -1.0,
                                1.0,
                              ),
                              onTap: () => onTap(i),
                            ),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TravelingSelectionLight extends StatelessWidget {
  const _TravelingSelectionLight({
    required this.itemWidth,
    required this.pageProgress,
    required this.isDark,
  });

  final double itemWidth;
  final double pageProgress;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final tension = shellTravelTension(pageProgress);
    final width = lerpDouble(itemWidth * 0.56, itemWidth * 0.82, tension)!;
    final height = lerpDouble(18, 24, tension)!;
    final top = lerpDouble(11, 9, tension)!;
    final center = itemWidth * (pageProgress + 0.5);
    final left = center - width / 2;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.18,
                colors: isDark
                    ? [
                        Colors.white.withAlpha(36 + (tension * 18).round()),
                        Colors.white.withAlpha(6),
                        Colors.transparent,
                      ]
                    : [
                        const Color(
                          0xFFE9F1FF,
                        ).withAlpha(170 + (tension * 20).round()),
                        const Color(0xFFDDEAFF).withAlpha(34),
                        Colors.transparent,
                      ],
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.white.withAlpha(10)
                      : const Color(0xFFAFCBFF).withAlpha(36),
                  blurRadius: 18 + (tension * 5),
                  spreadRadius: 1.5,
                ),
              ],
            ),
            child: SizedBox(width: width, height: height),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selection,
    required this.localDelta,
    required this.onTap,
  });

  final ShellNavDestinationData destination;
  final double selection;
  final double localDelta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    final iconColor = Color.lerp(
      c.tertiary.withAlpha(isDark ? 214 : 170),
      c.text,
      selection,
    )!;
    final labelColor = Color.lerp(
      c.tertiary.withAlpha(isDark ? 226 : 184),
      c.text,
      selection,
    )!;
    final scale = lerpDouble(1, 1.06, selection)!;
    final dy = lerpDouble(0, -1.2, selection)!;
    final glowOpacity = lerpDouble(0, isDark ? 0.12 : 0.18, selection)!;
    final contentDx = -localDelta * (1.6 + selection * 0.9);
    final iconTravelDx = -localDelta * 2.8;
    final labelTravelDx = -localDelta * 1.5;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: Opacity(
              opacity: glowOpacity,
              child: Container(
                width: 34,
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.05,
                    colors: isDark
                        ? [Colors.white.withAlpha(46), Colors.transparent]
                        : [const Color(0xFFEAF1FF), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(contentDx, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(0, dy),
                  child: Transform.scale(
                    scale: scale,
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.translate(
                            offset: Offset(iconTravelDx, 0),
                            child: Opacity(
                              opacity: 1 - selection,
                              child: Icon(
                                destination.icon,
                                size: 21,
                                color: iconColor,
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(iconTravelDx * 0.5, 0),
                            child: Opacity(
                              opacity: selection,
                              child: Icon(
                                destination.selectedIcon,
                                size: 21,
                                color: iconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Transform.translate(
                  offset: Offset(labelTravelDx, 0),
                  child: Text(
                    destination.label,
                    style: AppTypography.labelSmall.copyWith(
                      color: labelColor,
                      fontSize: 10.5,
                      fontWeight: selection > 0.56
                          ? FontWeight.w700
                          : FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
