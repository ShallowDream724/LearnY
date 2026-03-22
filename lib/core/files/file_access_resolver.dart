import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;

import '../design/file_type_utils.dart';

class FileAccessDescriptor {
  const FileAccessDescriptor({
    required this.displayName,
    required this.storedFileName,
    required this.extension,
    required this.mimeType,
  });

  final String displayName;
  final String storedFileName;
  final String extension;
  final String mimeType;
}

class FileAccessResolver {
  const FileAccessResolver();

  FileAccessDescriptor resolve({required String title, String? fileType}) {
    final displayName = _buildDisplayName(title: title, fileType: fileType);
    final storedFileName = _sanitizeFileName(displayName);
    final extension = p
        .extension(storedFileName)
        .replaceFirst('.', '')
        .toLowerCase();
    final mimeType =
        mime.lookupMimeType(storedFileName) ?? 'application/octet-stream';

    return FileAccessDescriptor(
      displayName: displayName,
      storedFileName: storedFileName,
      extension: extension,
      mimeType: mimeType,
    );
  }

  String _buildDisplayName({required String title, String? fileType}) {
    final rawName = title.trim();
    final safeBase = rawName.isEmpty ? 'file' : rawName;
    final normalizedExtension = FileTypeUtils.extractExt(
      safeBase,
      fileType ?? '',
    );
    final currentExtension = p
        .extension(safeBase)
        .replaceFirst('.', '')
        .toLowerCase();

    if (normalizedExtension.isEmpty ||
        currentExtension == normalizedExtension) {
      return safeBase;
    }
    return '$safeBase.$normalizedExtension';
  }

  String _sanitizeFileName(String input) {
    final sanitized = input
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    final withoutTrailingDots = sanitized.replaceAll(RegExp(r'[. ]+$'), '');
    return withoutTrailingDots.isEmpty ? 'file' : withoutTrailingDots;
  }
}

final fileAccessResolverProvider = Provider<FileAccessResolver>((ref) {
  return const FileAccessResolver();
});
