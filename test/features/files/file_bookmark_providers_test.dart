import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/files/providers/file_bookmark_providers.dart';

void main() {
  test('an undownloaded course file remains visible in favorites', () {
    final entries = buildFavoriteFileEntries(
      const [
        db.FileBookmark(
          assetKey: 'file-1',
          courseName: 'Software Engineering',
          createdAt: '2026-04-12T10:00:00.000',
        ),
      ],
      const [],
      const [
        db.CourseFile(
          id: 'file-1',
          courseId: 'course-1',
          fileId: 'remote-1',
          title: 'notes.pdf',
          description: '',
          rawSize: 0,
          size: '12 KB',
          uploadTime: '2026-04-12 10:00:00',
          fileType: 'pdf',
          downloadUrl: 'https://example.com/notes.pdf',
          previewUrl: 'https://example.com/notes.pdf/preview',
          isNew: false,
          markedImportant: false,
          visitCount: 0,
          downloadCount: 0,
          localDownloadState: 'none',
        ),
      ],
    );

    expect(entries, hasLength(1));
    expect(entries.single.item.cacheKey, 'file-1');
    expect(entries.single.item.courseName, 'Software Engineering');
    expect(entries.single.item.localDownloadState, 'none');
  });
}
