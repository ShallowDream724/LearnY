import '../file_preview_registry.dart';

enum ArchiveNameDecodingMode { standard, compatibility }

sealed class PreparedFilePreview {
  const PreparedFilePreview({required this.descriptor});

  final FilePreviewDescriptor descriptor;
}

final class PdfPreparedFilePreview extends PreparedFilePreview {
  const PdfPreparedFilePreview({
    required super.descriptor,
    required this.filePath,
  });

  final String filePath;
}

final class ImagePreparedFilePreview extends PreparedFilePreview {
  const ImagePreparedFilePreview({
    required super.descriptor,
    required this.filePath,
  });

  final String filePath;
}

final class TextPreparedFilePreview extends PreparedFilePreview {
  const TextPreparedFilePreview({
    required super.descriptor,
    required this.content,
    required this.isTruncated,
  });

  final String content;
  final bool isTruncated;
}

final class ArchivePreparedFilePreview extends PreparedFilePreview {
  const ArchivePreparedFilePreview({
    required super.descriptor,
    required this.document,
    this.note,
  });

  final ArchivePreviewDocument document;
  final String? note;
}

final class UnsupportedPreparedFilePreview extends PreparedFilePreview {
  const UnsupportedPreparedFilePreview({
    required super.descriptor,
    required this.message,
  });

  final String message;
}

class ArchivePreviewDocument {
  const ArchivePreviewDocument({
    required this.entries,
    required this.fileCount,
    required this.directoryCount,
    required this.compressedSizeBytes,
    required this.uncompressedSizeBytes,
    required this.nameDecodingMode,
    required this.canCompatibilityOpen,
  });

  final List<ArchivePreviewEntry> entries;
  final int fileCount;
  final int directoryCount;
  final int compressedSizeBytes;
  final int uncompressedSizeBytes;
  final ArchiveNameDecodingMode nameDecodingMode;
  final bool canCompatibilityOpen;
}

class ArchivePreviewEntry {
  const ArchivePreviewEntry({
    required this.path,
    required this.displayName,
    required this.parentPath,
    required this.depth,
    required this.isDirectory,
    required this.uncompressedSizeBytes,
    required this.compressedSizeBytes,
    required this.previewDescriptor,
    required this.childCount,
    this.archiveFileIndex,
  });

  final String path;
  final String displayName;
  final String parentPath;
  final int depth;
  final bool isDirectory;
  final int uncompressedSizeBytes;
  final int compressedSizeBytes;
  final FilePreviewDescriptor? previewDescriptor;
  final int childCount;
  final int? archiveFileIndex;

  bool get isFile => !isDirectory;
  bool get canInlinePreview => previewDescriptor?.canInlinePreview ?? false;
}
