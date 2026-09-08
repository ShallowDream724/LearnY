import 'package:flutter/material.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/typography.dart';

StudyTone fileTypeTone(String extension) => switch (extension.toLowerCase()) {
  'pdf' => StudyTone.rose,
  'ppt' || 'pptx' => StudyTone.ochre,
  'doc' || 'docx' || 'txt' || 'md' => StudyTone.ink,
  'xls' || 'xlsx' || 'csv' => StudyTone.jade,
  'zip' || 'rar' || '7z' => StudyTone.slate,
  _ => StudyTone.plum,
};

/// A type label shaped like a document, shared by the file list and info view.
class FileTypeMark extends StatelessWidget {
  const FileTypeMark({super.key, required this.extension, this.width = 44});
  final String extension;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = StudyPalette.of(context, fileTypeTone(extension));
    return Semantics(
      label: extension.isEmpty ? '文件' : '${extension.toUpperCase()} 文件',
      child: ExcludeSemantics(
        child: Container(
          width: width,
          height: width * 1.16,
          decoration: BoxDecoration(
            color: colors.fill,
            border: Border.all(color: colors.edge),
            borderRadius: BorderRadius.circular(width * 0.16),
          ),
          child: Stack(
            children: [
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: width * 0.27,
                  height: width * 0.27,
                  decoration: BoxDecoration(
                    color: colors.edge,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(width * 0.1),
                      topRight: Radius.circular(width * 0.14),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: width * 0.17,
                top: width * 0.22,
                child: Container(
                  width: width * 0.29,
                  height: 2,
                  color: colors.accent.withValues(alpha: 0.35),
                ),
              ),
              Positioned(
                left: 4,
                right: 4,
                bottom: width * 0.17,
                child: Text(
                  extension.isEmpty ? 'FILE' : extension.toUpperCase(),
                  textScaler: TextScaler.noScaling,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: colors.accent,
                    fontSize: width * 0.24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
