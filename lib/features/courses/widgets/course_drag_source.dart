import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Both input paths use Flutter's drag lifecycle, with stable recognizers.
class CourseDragSource extends StatelessWidget {
  const CourseDragSource({
    super.key,
    required this.courseId,
    required this.enabled,
    required this.child,
    required this.feedback,
    required this.placeholder,
    required this.anchorStrategy,
    required this.onStarted,
    required this.onFinished,
  });

  final String courseId;
  final bool enabled;
  final Widget child;
  final Widget feedback;
  final Widget placeholder;
  final DragAnchorStrategy anchorStrategy;
  final VoidCallback onStarted;
  final VoidCallback onFinished;

  @override
  Widget build(BuildContext context) {
    Widget source({required bool touch, required Widget child}) =>
        _PointerDragSource(
          touch: touch,
          data: courseId,
          maxSimultaneousDrags: enabled ? 1 : 0,
          dragAnchorStrategy: anchorStrategy,
          feedback: RepaintBoundary(child: feedback),
          childWhenDragging: placeholder,
          onDragStarted: onStarted,
          onDragEnd: (_) => onFinished(),
          child: child,
        );
    return source(touch: false, child: source(touch: true, child: child));
  }
}

class _PointerDragSource extends Draggable<String> {
  const _PointerDragSource({
    required this.touch,
    required super.data,
    required super.maxSimultaneousDrags,
    required super.dragAnchorStrategy,
    required super.feedback,
    required super.childWhenDragging,
    required super.onDragStarted,
    required super.onDragEnd,
    required super.child,
  });

  final bool touch;

  @override
  MultiDragGestureRecognizer createRecognizer(
    GestureMultiDragStartCallback onStart,
  ) {
    final recognizer = touch
        ? DelayedMultiDragGestureRecognizer(
            supportedDevices: const {
              PointerDeviceKind.touch,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
              PointerDeviceKind.unknown,
            },
          )
        : ImmediateMultiDragGestureRecognizer(
            supportedDevices: const {
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
          );
    return recognizer..onStart = onStart;
  }
}
