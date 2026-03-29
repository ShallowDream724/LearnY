import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../file_models.dart';
import '../file_preview_registry.dart';
import 'archive_preview_service.dart';
import 'file_preview_models.dart';

class FilePreviewPreparationService {
  const FilePreviewPreparationService({
    required FilePreviewRegistry registry,
    required ArchivePreviewService archiveService,
    this.maxTextCharacters = 100000,
  }) : _registry = registry,
       _archiveService = archiveService;

  final FilePreviewRegistry _registry;
  final ArchivePreviewService _archiveService;
  final int maxTextCharacters;

  Future<PreparedFilePreview> prepare({
    required FileDetailItem item,
    required String localPath,
  }) async {
    final descriptor = _registry.describeItem(item);

    try {
      switch (descriptor.capability) {
        case FilePreviewCapability.pdf:
          return PdfPreparedFilePreview(
            descriptor: descriptor,
            filePath: localPath,
          );
        case FilePreviewCapability.image:
          return ImagePreparedFilePreview(
            descriptor: descriptor,
            filePath: localPath,
          );
        case FilePreviewCapability.text:
          return _prepareTextPreview(
            descriptor: descriptor,
            localPath: localPath,
          );
        case FilePreviewCapability.document:
          return UnsupportedPreparedFilePreview(
            descriptor: descriptor,
            message: 'Word 文档暂不支持内置预览，请使用外部应用打开。',
          );
        case FilePreviewCapability.spreadsheet:
          return UnsupportedPreparedFilePreview(
            descriptor: descriptor,
            message: '表格文档暂不支持内置预览，请使用外部应用打开。',
          );
        case FilePreviewCapability.presentation:
          return UnsupportedPreparedFilePreview(
            descriptor: descriptor,
            message: '演示文稿暂不支持内置预览，请使用外部应用打开。',
          );
        case FilePreviewCapability.archive:
          return _archiveService.inspect(
            descriptor: descriptor,
            localPath: localPath,
          );
        case FilePreviewCapability.none:
          return UnsupportedPreparedFilePreview(
            descriptor: descriptor,
            message: '当前文件暂不支持内置预览。',
          );
      }
    } catch (_) {
      return UnsupportedPreparedFilePreview(
        descriptor: descriptor,
        message: '文件已下载，但内置预览准备失败。',
      );
    }
  }

  Future<TextPreparedFilePreview> _prepareTextPreview({
    required FilePreviewDescriptor descriptor,
    required String localPath,
  }) async {
    final file = File(localPath);
    final content = await file.readAsString();
    final isTruncated = content.length > maxTextCharacters;
    final visibleContent = isTruncated
        ? '${content.substring(0, maxTextCharacters)}\n\n... (文件过大，仅显示前100KB)'
        : content;

    return TextPreparedFilePreview(
      descriptor: descriptor,
      content: visibleContent,
      isTruncated: isTruncated,
    );
  }
}

final filePreviewPreparationServiceProvider =
    Provider<FilePreviewPreparationService>((ref) {
      return FilePreviewPreparationService(
        registry: ref.watch(filePreviewRegistryProvider),
        archiveService: ref.watch(archivePreviewServiceProvider),
      );
    });
