import 'package:flutter/material.dart';

import '../../../core/design/file_type_icon.dart';

/// The shared file-type icon used by file lists and the detail info view.
class FileTypeMark extends StatelessWidget {
  const FileTypeMark({super.key, required this.extension, this.width = 44});
  final String extension;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 1.16,
      child: Center(
        child: FileTypeIcon(extension: extension, size: width * 0.76),
      ),
    );
  }
}
