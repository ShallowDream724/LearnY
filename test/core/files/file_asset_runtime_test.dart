import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/files/file_asset_runtime.dart';
import 'package:learn_y/core/files/file_models.dart';
import 'package:learn_y/core/files/file_preview_registry.dart';
import 'package:learn_y/core/services/file_download_service.dart';

void main() {
  group('FileAssetRuntimeResolver', () {
    const resolver = FileAssetRuntimeResolver();

    test('prefers transient downloading state over persisted state', () {
      final runtime = resolver.resolveCourseFile(
        _courseFile(
          localDownloadState: 'downloaded',
          localFilePath: '/disk/a.pdf',
        ),
        const {
          'file-1': FileDownloadState(
            fileId: 'file-1',
            status: DownloadStatus.downloading,
            progress: 0.35,
          ),
        },
      );

      expect(runtime.status, DownloadStatus.downloading);
      expect(runtime.progress, 0.35);
      expect(runtime.localPath, isNull);
    });

    test('uses persisted downloaded state when file exists in cache model', () {
      final runtime = resolver.resolveDetailItem(
        const FileDetailItem(
          cacheKey: 'asset-1',
          sourceKind: 'courseFile',
          persistedFileId: 'file-1',
          courseId: 'course-1',
          courseName: 'Course',
          title: 'notes.pdf',
          description: '',
          rawSize: 0,
          size: '12 KB',
          uploadTime: '',
          fileType: 'pdf',
          downloadUrl: 'https://example.com/file',
          previewUrl: 'https://example.com/preview',
          markedImportant: false,
          isNew: false,
          supportsReadState: true,
          localDownloadState: 'downloaded',
          localFilePath: '/disk/notes.pdf',
        ),
        const {},
      );

      expect(runtime.isDownloaded, isTrue);
      expect(runtime.localPath, '/disk/notes.pdf');
    });

    test('treats cached attachment registry as downloaded source of truth', () {
      final runtime = resolver.resolveAttachment(
        assetKey: 'attachment-1',
        cachedAsset: const db.CachedAsset(
          assetKey: 'attachment-1',
          courseId: 'course-1',
          title: 'attachment.pdf',
          fileType: 'pdf',
          localPath: '/disk/attachment.pdf',
          fileSizeBytes: 42,
          updatedAt: '2026-03-21T12:00:00.000',
          sourceKind: 'notification',
        ),
        trackedStates: const {},
      );

      expect(runtime.isDownloaded, isTrue);
      expect(runtime.localPath, '/disk/attachment.pdf');
    });
  });

  group('FilePreviewRegistry', () {
    const registry = FilePreviewRegistry();

    test('maps supported extensions to inline preview capabilities', () {
      expect(
        registry.describe(fileName: 'slides.pdf').capability,
        FilePreviewCapability.pdf,
      );
      expect(
        registry.describe(fileName: 'photo.JPG').capability,
        FilePreviewCapability.image,
      );
      expect(
        registry.describe(fileName: 'notes.md').capability,
        FilePreviewCapability.text,
      );
    });

    test('falls back to no preview for unsupported formats', () {
      final descriptor = registry.describe(
        fileName: 'archive.zip',
        fileType: 'zip',
      );

      expect(descriptor.capability, FilePreviewCapability.none);
      expect(descriptor.canInlinePreview, isFalse);
    });
  });
}

db.CourseFile _courseFile({
  String localDownloadState = 'none',
  String? localFilePath,
}) {
  return db.CourseFile(
    id: 'file-1',
    courseId: 'course-1',
    fileId: 'remote-1',
    title: 'notes.pdf',
    description: '',
    rawSize: 1024,
    size: '1 KB',
    uploadTime: '2026-03-21T12:00:00.000',
    fileType: 'pdf',
    downloadUrl: 'https://example.com/file',
    previewUrl: 'https://example.com/preview',
    isNew: false,
    markedImportant: false,
    visitCount: 0,
    downloadCount: 0,
    localDownloadState: localDownloadState,
    localFilePath: localFilePath,
  );
}
