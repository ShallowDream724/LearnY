import 'package:flutter/material.dart';
import '../../../core/design/file_type_utils.dart';

class FileTypeFilterButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final types = typeCounts.keys.toList()..sort();
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.layers_outlined),
          trailingIcon: currentFilter == null
              ? const Icon(Icons.check_rounded)
              : null,
          onPressed: () => onChanged(null),
          child: const Text('全部类型'),
        ),
        for (final type in types)
          MenuItemButton(
            leadingIcon: Icon(
              FileTypeUtils.icon(type),
              color: FileTypeUtils.color(type),
            ),
            trailingIcon: currentFilter == type
                ? const Icon(Icons.check_rounded)
                : null,
            onPressed: () => onChanged(type),
            child: Text('${type.toUpperCase()} (${typeCounts[type]})'),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        onPressed: typeCounts.isEmpty && currentFilter == null
            ? null
            : () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
        icon: const Icon(Icons.filter_list_rounded, size: 18),
        label: Text(currentFilter?.toUpperCase() ?? '全部类型'),
      ),
    );
  }
}
