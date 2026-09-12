import 'package:flutter/widgets.dart';

/// The pager owns navigation; this signal only describes its visible position.
/// Drag samples are immediate. Explicit branch jumps may animate the indicator.
class ShellNavigationProgress extends ValueNotifier<double> {
  ShellNavigationProgress(super.value);

  bool _animate = false;
  bool get animate => _animate;

  void follow(double page) {
    final wasAnimating = _animate;
    _animate = false;
    if (value == page && wasAnimating) {
      notifyListeners();
    } else {
      value = page;
    }
  }

  void select(int page) {
    _animate = true;
    value = page.toDouble();
  }
}

class ShellNavigationProgressScope extends InheritedWidget {
  const ShellNavigationProgressScope({
    super.key,
    required this.progress,
    required super.child,
  });

  final ShellNavigationProgress progress;

  static ShellNavigationProgress of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ShellNavigationProgressScope>()!
      .progress;

  @override
  bool updateShouldNotify(ShellNavigationProgressScope oldWidget) =>
      progress != oldWidget.progress;
}
