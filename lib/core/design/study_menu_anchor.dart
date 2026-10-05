import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// An anchored menu consumes system back before its page can be popped.
/// The same close path handles back, Escape, outside taps and item selection.
class StudyMenuAnchor extends StatefulWidget {
  const StudyMenuAnchor({
    super.key,
    required this.menuChildren,
    required this.builder,
    this.childFocusNode,
    this.onOpen,
    this.onClose,
  });
  final List<Widget> menuChildren;
  final MenuAnchorChildBuilder builder;
  final FocusNode? childFocusNode;
  final VoidCallback? onOpen;
  final VoidCallback? onClose;

  @override
  State<StudyMenuAnchor> createState() => _StudyMenuAnchorState();
}

class _StudyMenuAnchorState extends State<StudyMenuAnchor> {
  final _controller = MenuController();
  bool _open = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: (_, event) {
      if (_open &&
          event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.escape) {
        _controller.close();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    child: PopScope<Object?>(
      canPop: !_open,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _controller.isOpen) _controller.close();
      },
      child: MenuAnchor(
        controller: _controller,
        useRootOverlay: true,
        consumeOutsideTap: true,
        childFocusNode: widget.childFocusNode,
        onOpen: () {
          setState(() => _open = true);
          widget.onOpen?.call();
        },
        onClose: () {
          if (mounted) setState(() => _open = false);
          widget.onClose?.call();
        },
        menuChildren: widget.menuChildren,
        builder: widget.builder,
      ),
    ),
  );
}
