import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_models.dart';
import 'package:learn_y/features/files/providers/file_queries.dart';

void main() {
  group('buildFilesPresentation', () {
    test('keeps downloaded attachments in the downloaded filter', () {
      final presentation = buildFilesPresentation(
        entries: [
          FileFeedEntry(
            item: _item(
              title: 'lecture.pdf',
              uploadTime: '2026-03-20T08:00:00.000',
              localDownloadState: 'none',
              isNew: true,
            ),
            isFavorite: false,
          ),
          FileFeedEntry(
            item: _item(
              title: 'slides.pdf',
              uploadTime: '2026-03-19T08:00:00.000',
              localDownloadState: 'downloaded',
            ),
            isFavorite: true,
          ),
          FileFeedEntry(
            item: _item(
              cacheKey: 'notification:course-1:attachment-1',
              sourceKind: 'notification',
              title: '通知附件.pdf',
              uploadTime: '2026-03-21T08:00:00.000',
              localDownloadState: 'downloaded',
              supportsReadState: false,
            ),
            isFavorite: false,
          ),
        ],
        filter: FileFeedFilter.downloaded,
      );

      expect(
        presentation.filteredEntries.map((entry) => entry.title).toList(),
        ['通知附件.pdf', 'slides.pdf'],
      );
    });

    test('searches by title and groups by time on the provider side', () {
      final now = DateTime(2026, 3, 21, 12);
      final presentation = buildFilesPresentation(
        entries: [
          FileFeedEntry(
            item: _item(
              title: '本周课件.pdf',
              uploadTime: '2026-03-19T08:00:00.000',
            ),
            isFavorite: false,
          ),
          FileFeedEntry(
            item: _item(
              title: '今天通知附件.zip',
              uploadTime: '2026-03-21T09:00:00.000',
              sourceKind: 'notification',
              localDownloadState: 'downloaded',
              supportsReadState: false,
            ),
            isFavorite: false,
          ),
          FileFeedEntry(
            item: _item(
              title: '更早文件.docx',
              uploadTime: '2026-03-01T08:00:00.000',
            ),
            isFavorite: false,
          ),
        ],
        filter: FileFeedFilter.all,
        searchQuery: '附件',
        now: now,
      );

      expect(
        presentation.filteredEntries.map((entry) => entry.title).toList(),
        ['今天通知附件.zip'],
      );
      expect(presentation.sections.map((section) => section.group).toList(), [
        FileFeedTimeGroup.today,
      ]);
    });
  });
}

FileDetailItem _item({
  String cacheKey = 'file-1',
  String sourceKind = 'courseFile',
  String title = 'file.pdf',
  String uploadTime = '2026-03-20T08:00:00.000',
  String localDownloadState = 'none',
  bool isNew = false,
  bool markedImportant = false,
  bool supportsReadState = true,
}) {
  return FileDetailItem(
    cacheKey: cacheKey,
    sourceKind: sourceKind,
    persistedFileId: sourceKind == 'courseFile' ? cacheKey : null,
    courseId: 'course-1',
    courseName: '土力学',
    title: title,
    description: '',
    rawSize: 1024,
    size: '1 KB',
    uploadTime: uploadTime,
    fileType: 'pdf',
    downloadUrl: 'https://example.com/download',
    previewUrl: 'https://example.com/preview',
    markedImportant: markedImportant,
    isNew: isNew,
    supportsReadState: supportsReadState,
    localDownloadState: localDownloadState,
    localFilePath: localDownloadState == 'downloaded' ? '/disk/$title' : null,
  );
}
