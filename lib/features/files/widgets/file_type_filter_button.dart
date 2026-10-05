import 'package:flutter/material.dart';
import '../../../core/design/file_type_utils.dart';
import '../../../core/design/study_menu_anchor.dart';

class FileTypeFilterButton extends StatefulWidget {
  const FileTypeFilterButton({
    super.key,
    required this.currentFilter,
    required this.typeCounts,
    required this.onChanged,
  });
  final String? currentFilter;
  final Map<String, int> typeCounts;
  final ValueChanged<String?> onChanged;

  @override
  State<FileTypeFilterButton> createState() => _FileTypeFilterButtonState();
}

class _FileTypeFilterButtonState extends State<FileTypeFilterButton> {
  final _focusNode = FocusNode(debugLabel: 'file-type-filter');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final types = widget.typeCounts.keys.toList()..sort();
    return StudyMenuAnchor(
      childFocusNode: _focusNode,
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.layers_outlined),
          trailingIcon: widget.currentFilter == null
              ? const Icon(Icons.check_rounded)
              : null,
          onPressed: () => widget.onChanged(null),
          child: const Text('全部类型'),
        ),
        for (final type in types)
          MenuItemButton(
            leadingIcon: Icon(
              FileTypeUtils.icon(type),
              color: FileTypeUtils.color(type),
            ),
            trailingIcon: widget.currentFilter == type
                ? const Icon(Icons.check_rounded)
                : null,
            onPressed: () => widget.onChanged(type),
            child: Text('${type.toUpperCase()} (${widget.typeCounts[type]})'),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        focusNode: _focusNode,
        onPressed: widget.typeCounts.isEmpty && widget.currentFilter == null
            ? null
            : () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
        icon: const Icon(Icons.filter_list_rounded, size: 18),
        label: Text(widget.currentFilter?.toUpperCase() ?? '全部类型'),
      ),
    );
  }
}
