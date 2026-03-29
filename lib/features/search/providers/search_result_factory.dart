import '../../../core/database/database.dart' as db;
import '../../../core/files/file_models.dart';
import 'search_engine.dart';
import 'search_models.dart';

SearchDocument buildCourseSearchDocument(db.Course course) {
  return SearchDocument(
    result: SearchResult(
      key: 'course:${course.id}',
      kind: SearchResultKind.course,
      navigationType: SearchNavigationType.courseDetail,
      id: course.id,
      courseId: course.id,
      courseName: course.name,
      title: course.name,
      subtitle: course.teacherName,
      section: buildExactSectionMeta(SearchResultKind.course),
    ),
    fields: [
      SearchField(course.name, weight: 4, isPrimary: true),
      SearchField(course.chineseName, weight: 3.6),
      SearchField(course.englishName, weight: 3.2),
      SearchField(course.teacherName, weight: 2.4),
      SearchField(course.courseNumber, weight: 2),
    ],
  );
}

SearchDocument buildNotificationSearchDocument(
  db.Notification notification, {
  required String courseName,
}) {
  final attachment = FileAttachment.tryParseJsonString(notification.attachmentJson);
  return SearchDocument(
    result: SearchResult(
      key: 'notification:${notification.id}',
      kind: SearchResultKind.notification,
      navigationType: SearchNavigationType.notificationDetail,
      id: notification.id,
      courseId: notification.courseId,
      courseName: courseName,
      title: notification.title,
      subtitle: notification.publisher.isEmpty
          ? courseName
          : '$courseName · ${notification.publisher}',
      section: buildExactSectionMeta(SearchResultKind.notification),
    ),
    fields: [
      SearchField(notification.title, weight: 4, isPrimary: true),
      SearchField(notification.content, weight: 3.4),
      SearchField(notification.publisher, weight: 2.2),
      SearchField(courseName, weight: 2.5),
      SearchField(attachment?.name ?? '', weight: 2.6),
    ],
  );
}

SearchDocument? buildNotificationAttachmentSearchDocument(
  db.Notification notification, {
  required String courseName,
  required Set<String> bookmarkKeys,
  required Set<String> cachedAssetKeys,
}) {
  final attachment = FileAttachment.tryParseJsonString(notification.attachmentJson);
  if (attachment == null || attachment.name.isEmpty) {
    return null;
  }
  final assetKey = attachment.cacheKeyForCourse(notification.courseId);
  return SearchDocument(
    result: SearchResult(
      key: 'notificationAttachment:$assetKey',
      kind: SearchResultKind.notificationAttachment,
      navigationType: SearchNavigationType.fileDetail,
      id: attachment.id,
      courseId: notification.courseId,
      courseName: courseName,
      title: attachment.name,
      subtitle: _attachmentSubtitle(
        courseName: courseName,
        label: '通知附件',
        size: attachment.size,
      ),
      section: buildExactSectionMeta(SearchResultKind.notificationAttachment),
      fileRouteData: FileDetailRouteData.attachment(
        attachment: attachment,
        courseId: notification.courseId,
        courseName: courseName,
      ),
      isFavorite: bookmarkKeys.contains(assetKey),
      isDownloaded: cachedAssetKeys.contains(assetKey),
    ),
    fileExtension: _normalizeExtension(attachment.fileType),
    fields: [
      SearchField(attachment.name, weight: 4, isPrimary: true),
      SearchField(notification.title, weight: 3.2),
      SearchField(notification.content, weight: 2.8),
      SearchField(courseName, weight: 2.4),
      SearchField('通知附件', weight: 2.8),
      SearchField(attachment.fileType, weight: 2.2),
    ],
  );
}

SearchDocument buildHomeworkSearchDocument(
  db.Homework homework, {
  required String courseName,
}) {
  final attachmentNames = _collectAttachmentNames(
    homework.attachmentJson,
    homework.submittedAttachmentJson,
    homework.gradeAttachmentJson,
    homework.answerAttachmentJson,
  );
  return SearchDocument(
    result: SearchResult(
      key: 'homework:${homework.id}',
      kind: SearchResultKind.homework,
      navigationType: SearchNavigationType.homeworkDetail,
      id: homework.id,
      courseId: homework.courseId,
      courseName: courseName,
      title: homework.title,
      subtitle: courseName,
      section: buildExactSectionMeta(SearchResultKind.homework),
    ),
    fields: [
      SearchField(homework.title, weight: 4, isPrimary: true),
      SearchField(homework.description ?? '', weight: 3.2),
      SearchField(courseName, weight: 2.4),
      SearchField(homework.gradeContent ?? '', weight: 2.3),
      SearchField(homework.submittedContent ?? '', weight: 2.2),
      SearchField(homework.answerContent ?? '', weight: 2.1),
      for (final name in attachmentNames) SearchField(name, weight: 2.5),
    ],
  );
}

Iterable<SearchDocument> buildHomeworkAttachmentSearchDocuments(
  db.Homework homework, {
  required String courseName,
  required Set<String> bookmarkKeys,
  required Set<String> cachedAssetKeys,
}) sync* {
  yield* _buildHomeworkAttachmentDocument(
    rawJson: homework.attachmentJson,
    kind: SearchResultKind.homeworkAttachment,
    label: '作业附件',
    homework: homework,
    courseName: courseName,
    bookmarkKeys: bookmarkKeys,
    cachedAssetKeys: cachedAssetKeys,
  );
  yield* _buildHomeworkAttachmentDocument(
    rawJson: homework.submittedAttachmentJson,
    kind: SearchResultKind.homeworkSubmittedAttachment,
    label: '提交附件',
    homework: homework,
    courseName: courseName,
    bookmarkKeys: bookmarkKeys,
    cachedAssetKeys: cachedAssetKeys,
  );
  yield* _buildHomeworkAttachmentDocument(
    rawJson: homework.gradeAttachmentJson,
    kind: SearchResultKind.homeworkGradeAttachment,
    label: '教师反馈附件',
    homework: homework,
    courseName: courseName,
    bookmarkKeys: bookmarkKeys,
    cachedAssetKeys: cachedAssetKeys,
  );
  yield* _buildHomeworkAttachmentDocument(
    rawJson: homework.answerAttachmentJson,
    kind: SearchResultKind.homeworkAnswerAttachment,
    label: '参考答案附件',
    homework: homework,
    courseName: courseName,
    bookmarkKeys: bookmarkKeys,
    cachedAssetKeys: cachedAssetKeys,
  );
}

SearchDocument buildCourseFileSearchDocument(
  db.CourseFile file, {
  required String courseName,
  required Set<String> bookmarkKeys,
  required Set<String> cachedAssetKeys,
}) {
  final isDownloaded =
      file.localDownloadState == 'downloaded' || cachedAssetKeys.contains(file.id);
  return SearchDocument(
    result: SearchResult(
      key: 'courseFile:${file.id}',
      kind: SearchResultKind.courseFile,
      navigationType: SearchNavigationType.fileDetail,
      id: file.id,
      courseId: file.courseId,
      courseName: courseName,
      title: file.title,
      subtitle: file.size.isEmpty ? courseName : '$courseName · ${file.size}',
      section: buildExactSectionMeta(SearchResultKind.courseFile),
      fileRouteData: FileDetailRouteData.courseFile(
        fileId: file.id,
        courseId: file.courseId,
        courseName: courseName,
      ),
      isFavorite: bookmarkKeys.contains(file.id),
      isDownloaded: isDownloaded,
    ),
    fileExtension: _normalizeExtension(file.fileType),
    fields: [
      SearchField(file.title, weight: 4, isPrimary: true),
      SearchField(file.description, weight: 3.1),
      SearchField(courseName, weight: 2.4),
      SearchField(file.fileType, weight: 2.5),
      SearchField(file.categoryTitle ?? '', weight: 2.2),
      SearchField(file.comment ?? '', weight: 1.8),
    ],
  );
}

Iterable<SearchDocument> _buildHomeworkAttachmentDocument({
  required String? rawJson,
  required SearchResultKind kind,
  required String label,
  required db.Homework homework,
  required String courseName,
  required Set<String> bookmarkKeys,
  required Set<String> cachedAssetKeys,
}) sync* {
  final attachment = FileAttachment.tryParseJsonString(rawJson);
  if (attachment == null || attachment.name.isEmpty) {
    return;
  }
  final assetKey = attachment.cacheKeyForCourse(homework.courseId);
  yield SearchDocument(
    result: SearchResult(
      key: '${kind.name}:$assetKey',
      kind: kind,
      navigationType: SearchNavigationType.fileDetail,
      id: attachment.id,
      courseId: homework.courseId,
      courseName: courseName,
      title: attachment.name,
      subtitle: _attachmentSubtitle(
        courseName: courseName,
        label: label,
        size: attachment.size,
      ),
      section: buildExactSectionMeta(kind),
      fileRouteData: FileDetailRouteData.attachment(
        attachment: attachment,
        courseId: homework.courseId,
        courseName: courseName,
      ),
      isFavorite: bookmarkKeys.contains(assetKey),
      isDownloaded: cachedAssetKeys.contains(assetKey),
    ),
    fileExtension: _normalizeExtension(attachment.fileType),
    fields: [
      SearchField(attachment.name, weight: 4, isPrimary: true),
      SearchField(homework.title, weight: 3.2),
      SearchField(homework.description ?? '', weight: 2.6),
      SearchField(courseName, weight: 2.4),
      SearchField(label, weight: 2.8),
      SearchField(homework.gradeContent ?? '', weight: 2.1),
      SearchField(homework.submittedContent ?? '', weight: 2.0),
      SearchField(homework.answerContent ?? '', weight: 2.0),
      SearchField(attachment.fileType, weight: 2.2),
    ],
  );
}

List<String> _collectAttachmentNames(String? first, String? second, String? third, String? fourth) {
  final names = <String>[];
  for (final rawJson in [first, second, third, fourth]) {
    final attachment = FileAttachment.tryParseJsonString(rawJson);
    if (attachment != null && attachment.name.isNotEmpty) {
      names.add(attachment.name);
    }
  }
  return names;
}

String _attachmentSubtitle({
  required String courseName,
  required String label,
  required String size,
}) {
  if (size.isEmpty) {
    return '$courseName · $label';
  }
  return '$courseName · $label · $size';
}

String? _normalizeExtension(String? rawExtension) {
  if (rawExtension == null || rawExtension.isEmpty) {
    return null;
  }
  return rawExtension.replaceFirst('.', '').trim().toLowerCase();
}
