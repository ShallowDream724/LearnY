import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/files/file_models.dart';
import 'package:learn_y/features/search/providers/search_models.dart';
import 'package:learn_y/features/search/providers/search_result_factory.dart';

void main() {
  test('assigns distinct attachment identities for legacy payloads', () {
    const legacyAttachmentJson =
        '{"id":"shared-attachment","name":"PCR-资料.pdf","downloadUrl":"https://example.com/download","previewUrl":"https://example.com/preview","size":"32 KB"}';

    const notification = db.Notification(
      id: 'notification-1',
      courseId: 'course-1',
      title: '实验通知',
      content: '',
      publisher: '教师',
      publishTime: '0',
      hasRead: false,
      hasReadLocal: false,
      markedImportant: false,
      isFavorite: false,
      attachmentJson: legacyAttachmentJson,
    );

    const homework = db.Homework(
      id: 'homework-1',
      courseId: 'course-1',
      baseId: 'base-1',
      title: 'PCR 作业',
      deadline: '0',
      submitted: true,
      graded: false,
      isLateSubmission: false,
      isFavorite: false,
      submittedAttachmentJson: legacyAttachmentJson,
    );

    final notificationDoc = buildNotificationAttachmentSearchDocument(
      notification,
      courseName: '分子生物学',
      bookmarkKeys: const <String>{},
      cachedAssetKeys: const <String>{},
    );
    final submittedDoc =
        buildHomeworkAttachmentSearchDocuments(
          homework,
          courseName: '分子生物学',
          bookmarkKeys: const <String>{},
          cachedAssetKeys: const <String>{},
        ).singleWhere(
          (document) =>
              document.result.kind ==
              SearchResultKind.homeworkSubmittedAttachment,
        );

    expect(notificationDoc, isNotNull);
    expect(
      notificationDoc!.result.fileRouteData?.attachment?.kind,
      FileAttachmentKind.notification,
    );
    expect(
      notificationDoc.result.fileRouteData?.assetKey,
      'notification:course-1:shared-attachment',
    );
    expect(
      submittedDoc.result.fileRouteData?.attachment?.kind,
      FileAttachmentKind.homeworkSubmitted,
    );
    expect(
      submittedDoc.result.fileRouteData?.assetKey,
      'homeworkSubmitted:course-1:shared-attachment',
    );
  });
}
