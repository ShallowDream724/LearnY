import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_models.dart';
import 'package:learn_y/core/files/file_preview_registry.dart';
import 'package:learn_y/core/files/preview/archive_preview_service.dart';
import 'package:learn_y/core/files/preview/file_preview_models.dart';
import 'package:learn_y/core/files/preview/file_preview_preparation_service.dart';

void main() {
  group('FilePreviewPreparationService', () {
    const registry = FilePreviewRegistry();
    const archiveService = ArchivePreviewService(registry: registry);
    const service = FilePreviewPreparationService(
      registry: registry,
      archiveService: archiveService,
    );

    test('treats Word files as external-open only', () async {
      final preview = await service.prepare(
        item: _item('sample.docx'),
        localPath: 'unused',
      );

      expect(preview, isA<UnsupportedPreparedFilePreview>());
      expect(
        (preview as UnsupportedPreparedFilePreview).message,
        'Word 文档暂不支持内置预览，请使用外部应用打开。',
      );
    });

    test('treats spreadsheet files as external-open only', () async {
      final preview = await service.prepare(
        item: _item('grades.xlsx'),
        localPath: 'unused',
      );

      expect(preview, isA<UnsupportedPreparedFilePreview>());
      expect(
        (preview as UnsupportedPreparedFilePreview).message,
        '表格文档暂不支持内置预览，请使用外部应用打开。',
      );
    });

    test('treats presentation files as external-open only', () async {
      final preview = await service.prepare(
        item: _item('deck.pptx'),
        localPath: 'unused',
      );

      expect(preview, isA<UnsupportedPreparedFilePreview>());
      expect(
        (preview as UnsupportedPreparedFilePreview).message,
        '演示文稿暂不支持内置预览，请使用外部应用打开。',
      );
    });
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
