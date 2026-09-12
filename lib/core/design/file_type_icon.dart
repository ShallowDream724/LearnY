import 'package:flutter/material.dart';

import 'file_type_utils.dart';

/// One semantic glyph and color mapping for file identities across the app.
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({
    super.key,
    this.title = '',
    this.fileType = '',
    this.extension,
    this.size = 24,
  });

  final String title;
  final String fileType;
  final String? extension;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ext = (extension ?? FileTypeUtils.extractExt(title, fileType))
        .toLowerCase();
    return Semantics(
      label: ext.isEmpty ? '文件' : '${ext.toUpperCase()} 文件',
      child: ExcludeSemantics(
        child: Icon(
          FileTypeUtils.icon(ext),
          color: FileTypeUtils.color(ext),
          size: size,
        ),
      ),
    );
  }
}
