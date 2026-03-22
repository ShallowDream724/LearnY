import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../file_models.dart';
import '../file_preview_registry.dart';
import 'file_preview_models.dart';
import 'office_preview_parser.dart';

class FilePreviewPreparationService {
  const FilePreviewPreparationService({
    required FilePreviewRegistry registry,
    required OfficePreviewParser officeParser,
    this.maxTextCharacters = 100000,
  }) : _registry = registry,
       _officeParser = officeParser;

  final FilePreviewRegistry _registry;
  final OfficePreviewParser _officeParser;
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
          return _officeParser.parseDocx(
            descriptor: descriptor,
            localPath: localPath,
          );
        case FilePreviewCapability.spreadsheet:
          return _officeParser.parseXlsx(
            descriptor: descriptor,
            localPath: localPath,
          );
        case FilePreviewCapability.presentation:
          return UnsupportedPreparedFilePreview(
            descriptor: descriptor,
            message: '演示文稿暂不支持内置预览，请使用外部应用打开。',
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
        officeParser: ref.watch(officePreviewParserProvider),
      );
    });
