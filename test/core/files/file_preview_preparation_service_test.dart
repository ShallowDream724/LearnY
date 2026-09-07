import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_models.dart';
import 'package:learn_y/core/files/file_preview_registry.dart';
import 'package:learn_y/core/files/preview/archive_preview_service.dart';
import 'package:learn_y/core/files/preview/file_preview_models.dart';
import 'package:learn_y/core/files/preview/file_preview_preparation_service.dart';

void main() {
  group('FilePreviewPreparationService', () {
    const registry = FilePreviewRegistry();
    final archiveService = ArchivePreviewService(
      registry: registry,
      resolveArchiveRootDirectory: () async => Directory.systemTemp,
    );
    final service = FilePreviewPreparationService(
      registry: registry,
      archiveService: archiveService,
    );

    for (final (extension, capability) in const [
      ('doc', FilePreviewCapability.document),
      ('docx', FilePreviewCapability.document),
      ('docm', FilePreviewCapability.document),
      ('xls', FilePreviewCapability.spreadsheet),
      ('xlsx', FilePreviewCapability.spreadsheet),
      ('xlsm', FilePreviewCapability.spreadsheet),
      ('ppt', FilePreviewCapability.presentation),
      ('pptx', FilePreviewCapability.presentation),
      ('pptm', FilePreviewCapability.presentation),
    ]) {
      test(
        'keeps .$extension external-open only without reading the file',
        () async {
          final preview = await service.prepare(
            item: _item('sample.$extension'),
            localPath: 'nonexistent-office-file.$extension',
          );

          expect(preview, isA<UnsupportedPreparedFilePreview>());
          expect(preview.descriptor.capability, capability);
          expect(preview.descriptor.canInlinePreview, isFalse);
          expect(
            (preview as UnsupportedPreparedFilePreview).message,
            contains('外部应用'),
          );
        },
      );
    }
  });
}

FileDetailItem _item(String title) {
  return FileDetailItem(
    cacheKey: title,
    sourceKind: 'test',
    courseId: 'course',
    courseName: 'Course',
    title: title,
    description: '',
    rawSize: 0,
    size: '0 B',
    uploadTime: '',
    fileType: '',
    downloadUrl: '',
    previewUrl: '',
    markedImportant: false,
    isNew: false,
    supportsReadState: false,
  );
}
