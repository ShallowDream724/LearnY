import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_theme_colors.dart';

class AppearanceMenu extends StatefulWidget {
  const AppearanceMenu({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<AppearanceMenu> createState() => _AppearanceMenuState();
}

class _AppearanceMenuState extends State<AppearanceMenu> {
  static const _labels = {'system': '跟随系统', 'light': '浅色', 'dark': '深色'};
  final _focusNode = FocusNode(debugLabel: 'appearance-menu');
  bool _pointerActivation = false;
  bool _openedWithPointer = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _restoreFocus() {
    // Keyboard users return to the opener; pointer users keep no focus fill.
    if (_openedWithPointer) _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Focus(
      canRequestFocus: false,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent) _pointerActivation = false;
        return KeyEventResult.ignored;
      },
      child: Listener(
        onPointerDown: (_) => _pointerActivation = true,
        child: MenuAnchor(
          childFocusNode: _focusNode,
          consumeOutsideTap: true,
          onOpen: () => _openedWithPointer = _pointerActivation,
          onClose: _restoreFocus,
          menuChildren: [
            for (final option in _labels.entries)
              MenuItemButton(
                onPressed: () => widget.onChanged(option.key),
                trailingIcon: widget.value == option.key
                    ? const Icon(Icons.check_rounded, size: 18)
                    : const SizedBox(width: 18),
                child: Text(option.value),
              ),
          ],
          builder: (context, controller, child) => Tooltip(
            message: '选择外观',
            child: TextButton(
              key: const ValueKey('appearance-menu-button'),
              focusNode: _focusNode,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              style: TextButton.styleFrom(
                backgroundColor: c.surfaceHigh,
                foregroundColor: c.text,
                overlayColor: c.text,
                side: BorderSide(color: c.border, width: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                minimumSize: const Size(112, 40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_labels[widget.value] ?? _labels['system']!),
                  const SizedBox(width: 8),
                  Icon(Icons.unfold_more_rounded, size: 16, color: c.subtitle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
