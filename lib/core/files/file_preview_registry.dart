import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/file_type_utils.dart';
import 'file_models.dart';

enum FilePreviewCapability {
  pdf,
  image,
  text,
  document,
  spreadsheet,
  presentation,
  none,
}

class FilePreviewDescriptor {
  const FilePreviewDescriptor({
    required this.capability,
    required this.extension,
  });

  final FilePreviewCapability capability;
  final String extension;

  bool get canInlinePreview => switch (capability) {
    FilePreviewCapability.pdf ||
    FilePreviewCapability.image ||
    FilePreviewCapability.text ||
    FilePreviewCapability.document ||
    FilePreviewCapability.spreadsheet => true,
    FilePreviewCapability.presentation || FilePreviewCapability.none => false,
  };
}

class FilePreviewRegistry {
  const FilePreviewRegistry();

  FilePreviewDescriptor describeItem(FileDetailItem item) {
    return describe(fileName: item.title, fileType: item.fileType);
  }

  FilePreviewDescriptor describe({required String fileName, String? fileType}) {
    final extension = FileTypeUtils.extractExt(fileName, fileType ?? '');
    return FilePreviewDescriptor(
      capability: _capabilityForExtension(extension),
      extension: extension,
    );
  }

  FilePreviewCapability _capabilityForExtension(String extension) {
    switch (extension) {
      case 'pdf':
        return FilePreviewCapability.pdf;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return FilePreviewCapability.image;
      case 'txt':
      case 'md':
      case 'csv':
      case 'json':
      case 'xml':
      case 'log':
      case 'py':
      case 'java':
      case 'c':
      case 'cpp':
      case 'h':
      case 'js':
      case 'html':
      case 'css':
      case 'dart':
        return FilePreviewCapability.text;
      case 'docx':
        return FilePreviewCapability.document;
      case 'xlsx':
        return FilePreviewCapability.spreadsheet;
      case 'pptx':
        return FilePreviewCapability.presentation;
      default:
        return FilePreviewCapability.none;
    }
  }
}

final filePreviewRegistryProvider = Provider<FilePreviewRegistry>((ref) {
  return const FilePreviewRegistry();
});
