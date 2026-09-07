import 'package:flutter/material.dart';

import 'app_theme_colors.dart';

abstract final class AppMotion {
  static const feedback = Duration(milliseconds: 120);
  static const transition = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  static Duration duration(
    BuildContext context, [
    Duration value = transition,
  ]) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}

/// Constrains reading length while letting the surrounding page remain full size.
class ReadingWidth extends StatelessWidget {
  const ReadingWidth({super.key, required this.child, this.maxWidth = 880});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: context.colors.subtitle),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    ),
  );
}

/// Supplies the allocated pane width without changing window-level MediaQuery.
class ContentLayout extends StatelessWidget {
  const ContentLayout({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        _ContentWidth(width: constraints.maxWidth, child: child),
  );
}

class _ContentWidth extends InheritedWidget {
  const _ContentWidth({required this.width, required super.child});
  final double width;

  @override
  bool updateShouldNotify(_ContentWidth oldWidget) => width != oldWidget.width;
}

double pageGutterForWidth(double width, {double maxWidth = 1120}) =>
    width > maxWidth + 48
    ? (width - maxWidth) / 2
    : width >= 600
    ? 24
    : 16;

/// Root detail routes use the window; shell routes use their allocated pane.
double pageGutter(BuildContext context, {double maxWidth = 1120}) {
  final width =
      context.dependOnInheritedWidgetOfExactType<_ContentWidth>()?.width ??
      MediaQuery.sizeOf(context).width;
  return pageGutterForWidth(width, maxWidth: maxWidth);
}
