import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

abstract final class AppOrientation {
  static const List<DeviceOrientation> _phoneOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ];

  static const List<DeviceOrientation> _previewOrientations = [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static Future<void> restoreDefault() {
    return SystemChrome.setPreferredOrientations(
      defaultOrientationsForCurrentWindow(),
    );
  }

  static Future<void> enablePreview() {
    return SystemChrome.setPreferredOrientations(_previewOrientations);
  }

  static List<DeviceOrientation> defaultOrientationsForCurrentWindow() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return _phoneOrientations;
    }

    final view = views.first;
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    final logicalHeight = view.physicalSize.height / view.devicePixelRatio;
    final shortestSide = math.min(logicalWidth, logicalHeight);
    if (shortestSide >= 600) {
      return _previewOrientations;
    }
    return _phoneOrientations;
  }
}

class PreviewOrientationScope extends StatefulWidget {
  const PreviewOrientationScope({super.key, required this.child});

  final Widget child;

  @override
  State<PreviewOrientationScope> createState() =>
      _PreviewOrientationScopeState();
}

class _PreviewOrientationScopeState extends State<PreviewOrientationScope> {
  @override
  void initState() {
    super.initState();
    unawaited(AppOrientation.enablePreview());
  }

  @override
  void dispose() {
    unawaited(AppOrientation.restoreDefault());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
