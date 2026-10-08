import 'package:flutter/widgets.dart';

/// Predictive back reaches every nested Navigator. A retained branch must not
/// pop its current route while another branch or a root detail covers it.
class ShellBranchBackScope extends InheritedWidget {
  const ShellBranchBackScope({
    super.key,
    required this.enabled,
    required super.child,
  });

  final bool enabled;

  static bool enabledOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ShellBranchBackScope>()
          ?.enabled ??
      true;

  @override
  bool updateShouldNotify(ShellBranchBackScope oldWidget) =>
      enabled != oldWidget.enabled;
}

/// Wrap branch detail routes inside their own Navigator's route, so PopScope
/// controls that route rather than the shell's parent route.
class ShellBranchRoute extends StatelessWidget {
  const ShellBranchRoute({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      PopScope(canPop: ShellBranchBackScope.enabledOf(context), child: child);
}
