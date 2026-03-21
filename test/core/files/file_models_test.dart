import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/files/file_models.dart';

void main() {
  group('FileDetailRouteData', () {
    test('round-trips attachment routes through JSON', () {
      final routeData = FileDetailRouteData.attachment(
        attachment: const FileAttachment(
          id: 'attachment-1',
          name: 'notes.pdf',
          downloadUrl: 'https://example.com/download',
          previewUrl: 'https://example.com/preview',
          size: '12 KB',
          kind: FileAttachmentKind.notification,
        ),
        courseId: 'course-1',
        courseName: '土力学',
      );

      final restored = FileDetailRouteData.tryParseJsonString(
        routeData.toJsonString(),
      );

      expect(restored, isNotNull);
      expect(restored!.courseId, 'course-1');
      expect(restored.courseName, '土力学');
      expect(restored.fileId, isNull);
      expect(restored.attachment, isNotNull);
      expect(restored.attachment!.id, 'attachment-1');
      expect(restored.attachment!.kind, FileAttachmentKind.notification);
    });
  });

  group('FileDetailItem', () {
    test('builds attachment route metadata from unified detail items', () {
      const item = FileDetailItem(
        cacheKey: 'homeworkAttachment:course-1:attachment-2',
        sourceKind: 'homeworkAttachment',
        courseId: 'course-1',
        courseName: '结构力学',
        title: 'homework.docx',
        description: '',
        rawSize: 0,
        size: '24 KB',
        uploadTime: '',
        fileType: 'docx',
        downloadUrl: 'https://example.com/homework',
        previewUrl: 'https://example.com/homework-preview',
        markedImportant: false,
        isNew: false,
        supportsReadState: false,
      );

      final routeData = item.routeData;

      expect(routeData.courseId, 'course-1');
      expect(routeData.courseName, '结构力学');
      expect(routeData.attachment, isNotNull);
      expect(routeData.attachment!.id, 'attachment-2');
      expect(routeData.attachment!.kind, FileAttachmentKind.homeworkAttachment);
    });
  });

  group('CachedAssetListItem', () {
    test(
      'falls back to course-file routes when cache record has no route JSON',
      () {
        final item = CachedAssetListItem.fromCachedAsset(
          const db.CachedAsset(
            assetKey: 'file-1',
            courseId: 'course-1',
            title: 'slides.pdf',
            fileType: 'pdf',
            localPath: '/disk/slides.pdf',
            fileSizeBytes: 123,
            lastAccessedAt: null,
            updatedAt: '2026-03-21T12:00:00.000',
            persistedFileId: 'file-1',
            sourceKind: 'courseFile',
            routeDataJson: null,
          ),
          courseName: '高等数学',
        );

        expect(item.routeData, isNotNull);
        expect(item.routeData!.fileId, 'file-1');
        expect(item.routeData!.courseName, '高等数学');
      },
    );

    test('prefers persisted attachment route metadata when available', () {
      final routeData = FileDetailRouteData.attachment(
        attachment: const FileAttachment(
          id: 'attachment-3',
          name: 'feedback.zip',
          downloadUrl: 'https://example.com/feedback',
          previewUrl: 'https://example.com/feedback-preview',
          size: '1.2 MB',
          kind: FileAttachmentKind.homeworkGrade,
        ),
        courseId: 'course-1',
        courseName: '流体力学',
      );

      final item = CachedAssetListItem.fromCachedAsset(
        db.CachedAsset(
          assetKey: 'homeworkGrade:course-1:attachment-3',
          courseId: 'course-1',
          title: 'feedback.zip',
          fileType: 'zip',
          localPath: '/disk/feedback.zip',
          fileSizeBytes: 4096,
          lastAccessedAt: null,
          updatedAt: '2026-03-21T12:00:00.000',
          persistedFileId: null,
          sourceKind: 'homeworkGrade',
          routeDataJson: routeData.toJsonString(),
        ),
        courseName: '流体力学',
      );

      expect(item.routeData, isNotNull);
      expect(item.routeData!.attachment, isNotNull);
      expect(item.routeData!.attachment!.id, 'attachment-3');
      expect(
        item.routeData!.attachment!.kind,
        FileAttachmentKind.homeworkGrade,
      );
    });
  });
}
