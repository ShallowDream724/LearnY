import 'package:flutter/widgets.dart';

/// Coordinates the pager and dock without owning routes or branch contents.
/// The pager owns/disposes its controller; the dock may stop an in-flight page
/// gesture and settle even to the already-selected route on release/cancel.
class ShellNavigationProgress extends ValueNotifier<double> {
  ShellNavigationProgress(super.value);
  PageController? _pager;
  bool _selecting = false;
  bool get selecting => _selecting;

  void attach(PageController pager) => _pager = pager;
  void detach(PageController pager) {
    if (identical(_pager, pager)) _pager = null;
  }

  void holdPage() {
    final pager = _pager;
    if (pager != null && pager.hasClients) {
      pager.jumpTo(pager.position.pixels);
    }
  }

  void settlePage(int page) {
    final pager = _pager;
    _selecting = true;
    try {
      if (pager != null && pager.hasClients) pager.jumpToPage(page);
    } finally {
      _selecting = false;
    }
    select(page);
  }

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
