/// Data models for the thu-learn-lib API.
///
/// These are plain Dart classes mirroring the TypeScript interfaces.
/// We intentionally avoid code-gen (freezed) in this library layer
/// to keep it dependency-free. The app layer can wrap these if needed.
library;

import 'enums.dart';

// ---------------------------------------------------------------------------
// UserInfo
// ---------------------------------------------------------------------------

class UserInfo {
  final String name;
  final String department;

  const UserInfo({required this.name, required this.department});
}

// ---------------------------------------------------------------------------
// SemesterInfo
// ---------------------------------------------------------------------------

class SemesterInfo {
  final String id;
  final String startDate;
  final String endDate;
  final int startYear;
  final int endYear;
  final SemesterType type;

  const SemesterInfo({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.startYear,
    required this.endYear,
    required this.type,
  });
}

// ---------------------------------------------------------------------------
// CourseInfo
// ---------------------------------------------------------------------------

class CourseInfo {
  final String id;
  final String name;
  final String chineseName;
  final String englishName;
  final List<dynamic> timeAndLocation;
  final String url;
  final String teacherName;
  final String teacherNumber;
  final String courseNumber;
  final int courseIndex;
  final CourseType courseType;

  const CourseInfo({
    required this.id,
    required this.name,
    required this.chineseName,
    required this.englishName,
    required this.timeAndLocation,
    required this.url,
    required this.teacherName,
    required this.teacherNumber,
    required this.courseNumber,
    required this.courseIndex,
    required this.courseType,
  });
}

// ---------------------------------------------------------------------------
// RemoteFile
// ---------------------------------------------------------------------------

class RemoteFile {
  final String id;
  final String name;
  final String downloadUrl;
  final String previewUrl;
  final String size;

  const RemoteFile({
    required this.id,
    required this.name,
    required this.downloadUrl,
    required this.previewUrl,
    required this.size,
  });
}

// ---------------------------------------------------------------------------
// Notification (课程公告)
// ---------------------------------------------------------------------------

class Notification {
  final String id;
  final String title;
  final String content;
  final bool hasRead;
  final String url;
  final bool markedImportant;
  final String publishTime;
  final String publisher;
  final String? expireTime;
  final bool isFavorite;
  final String? comment;

  /// Detail fields (fetched separately)
  final RemoteFile? attachment;

  const Notification({
    required this.id,
    required this.title,
    required this.content,
    required this.hasRead,
    required this.url,
    required this.markedImportant,
    required this.publishTime,
    required this.publisher,
    this.expireTime,
    required this.isFavorite,
    this.comment,
    this.attachment,
  });

  Notification copyWith({RemoteFile? attachment}) {
    return Notification(
      id: id,
      title: title,
      content: content,
      hasRead: hasRead,
      url: url,
      markedImportant: markedImportant,
      publishTime: publishTime,
      publisher: publisher,
      expireTime: expireTime,
      isFavorite: isFavorite,
      comment: comment,
      attachment: attachment ?? this.attachment,
    );
  }
}

// ---------------------------------------------------------------------------
// FileCategory
// ---------------------------------------------------------------------------

class FileCategory {
  final String id;
  final String title;
  final String creationTime;

  const FileCategory({
    required this.id,
    required this.title,
    required this.creationTime,
  });
}

// ---------------------------------------------------------------------------
// CourseFile (named to avoid collision with dart:io File)
// ---------------------------------------------------------------------------

class CourseFile {
  /// Previously `id2` in the original library.
  final String id;

  /// Previously `id` in the original library.
  final String fileId;

  final FileCategory? category;
  final int rawSize;
  final String size;
  final String title;
  final String description;
  final String uploadTime;
  final String publishTime;
  final String downloadUrl;
  final String previewUrl;
  final bool isNew;
  final bool markedImportant;
  final int visitCount;
  final int downloadCount;
  final String fileType;
  final RemoteFile remoteFile;
  final bool? isFavorite;
  final String? comment;

  const CourseFile({
    required this.id,
    required this.fileId,
    this.category,
    required this.rawSize,
    required this.size,
    required this.title,
    required this.description,
    required this.uploadTime,
    required this.publishTime,
    required this.downloadUrl,
    required this.previewUrl,
    required this.isNew,
    required this.markedImportant,
    required this.visitCount,
    required this.downloadCount,
    required this.fileType,
    required this.remoteFile,
    this.isFavorite,
    this.comment,
  });
}

// ---------------------------------------------------------------------------
// Homework (课程作业)
// ---------------------------------------------------------------------------

class Homework {
  final String id;
  @Deprecated('Use id instead')
  final String studentHomeworkId;
  final String baseId;
  final String title;
  final String deadline;
  final String? lateSubmissionDeadline;
  final String url;
  final HomeworkCompletionType? completionType;
  final HomeworkSubmissionType? submissionType;
  final String submitUrl;
  final String? submitTime;
  final bool isLateSubmission;
  final bool submitted;
  final bool graded;
  final double? grade;
  final HomeworkGradeLevel? gradeLevel;
  final String? gradeTime;
  final String? graderName;
  final String? gradeContent;
  final bool isFavorite;
  final String? favoriteTime;
  final String? comment;
  final List<ExcellentHomework>? excellentHomeworkList;

  /// Detail fields
  final String? description;
  final RemoteFile? attachment;
  final String? answerContent;
  final RemoteFile? answerAttachment;
  final String? submittedContent;
  final RemoteFile? submittedAttachment;
  final RemoteFile? gradeAttachment;

  const Homework({
    required this.id,
    required this.studentHomeworkId,
    required this.baseId,
    required this.title,
    required this.deadline,
    this.lateSubmissionDeadline,
    required this.url,
    this.completionType,
    this.submissionType,
    required this.submitUrl,
    this.submitTime,
    required this.isLateSubmission,
    required this.submitted,
    required this.graded,
    this.grade,
    this.gradeLevel,
    this.gradeTime,
    this.graderName,
    this.gradeContent,
    required this.isFavorite,
    this.favoriteTime,
    this.comment,
    this.excellentHomeworkList,
    this.description,
    this.attachment,
    this.answerContent,
    this.answerAttachment,
    this.submittedContent,
    this.submittedAttachment,
    this.gradeAttachment,
  });
}

// ---------------------------------------------------------------------------
// ExcellentHomework
// ---------------------------------------------------------------------------

class HomeworkAuthor {
  final String? id;
  final String? name;
  final bool anonymous;

  const HomeworkAuthor({this.id, this.name, required this.anonymous});
}

class ExcellentHomework {
  final String id;
  final String baseId;
  final String title;
  final String url;
  final HomeworkCompletionType? completionType;
  final HomeworkAuthor author;

  /// Detail fields
  final String? description;
  final RemoteFile? attachment;
  final String? answerContent;
  final RemoteFile? answerAttachment;
  final String? submittedContent;
  final RemoteFile? submittedAttachment;
  final RemoteFile? gradeAttachment;

  const ExcellentHomework({
    required this.id,
    required this.baseId,
    required this.title,
    required this.url,
    this.completionType,
    required this.author,
    this.description,
    this.attachment,
    this.answerContent,
    this.answerAttachment,
    this.submittedContent,
    this.submittedAttachment,
    this.gradeAttachment,
  });
}

// ---------------------------------------------------------------------------
// HomeworkTA (teacher assistant view)
// ---------------------------------------------------------------------------

class HomeworkTA {
  final String id;
  final int index;
  final String title;
  final String description;
  final String publisherId;
  final String publishTime;
  final String startTime;
  final String deadline;
  final String? lateSubmissionDeadline;
  final String url;
  final HomeworkCompletionType? completionType;
  final HomeworkSubmissionType? submissionType;
  final int gradedCount;
  final int submittedCount;
  final int unsubmittedCount;

  const HomeworkTA({
    required this.id,
    required this.index,
    required this.title,
    required this.description,
    required this.publisherId,
    required this.publishTime,
    required this.startTime,
    required this.deadline,
    this.lateSubmissionDeadline,
    required this.url,
    this.completionType,
    this.submissionType,
    required this.gradedCount,
    required this.submittedCount,
    required this.unsubmittedCount,
  });
}

// ---------------------------------------------------------------------------
// Discussion
// ---------------------------------------------------------------------------

class Discussion {
  final String id;
  final String title;
  final String publisherName;
  final String publishTime;
  final String lastReplierName;
  final String lastReplyTime;
  final int visitCount;
  final int replyCount;
  final bool isFavorite;
  final String? comment;
  final String url;
  final String boardId;

  const Discussion({
    required this.id,
    required this.title,
    required this.publisherName,
    required this.publishTime,
    required this.lastReplierName,
    required this.lastReplyTime,
    required this.visitCount,
    required this.replyCount,
    required this.isFavorite,
    this.comment,
    required this.url,
    required this.boardId,
  });
}

// ---------------------------------------------------------------------------
// Question (课程答疑)
// ---------------------------------------------------------------------------

class Question {
  final String id;
  final String title;
  final String publisherName;
  final String publishTime;
  final String lastReplierName;
  final String lastReplyTime;
  final int visitCount;
  final int replyCount;
  final bool isFavorite;
  final String? comment;
  final String url;
  final String question;

  const Question({
    required this.id,
    required this.title,
    required this.publisherName,
    required this.publishTime,
    required this.lastReplierName,
    required this.lastReplyTime,
    required this.visitCount,
    required this.replyCount,
    required this.isFavorite,
    this.comment,
    required this.url,
    required this.question,
  });
}

// ---------------------------------------------------------------------------
// Questionnaire
// ---------------------------------------------------------------------------

class QuestionnaireOption {
  final String id;
  final int index;
  final String title;

  const QuestionnaireOption({
    required this.id,
    required this.index,
    required this.title,
  });
}

class QuestionnaireDetail {
  final String id;
  final int index;
  final QuestionnaireDetailType type;
  final bool required_;
  final String title;
  final double? score;
  final List<QuestionnaireOption>? options;

  const QuestionnaireDetail({
    required this.id,
    required this.index,
    required this.type,
    required this.required_,
    required this.title,
    this.score,
    this.options,
  });
}

class Questionnaire {
  final String id;
  final QuestionnaireType type;
  final String title;
  final String startTime;
  final String endTime;
  final String uploadTime;
  final String uploaderId;
  final String uploaderName;
  final String? submitTime;
  final bool isFavorite;
  final String? comment;
  final String url;
  final List<QuestionnaireDetail> detail;

  const Questionnaire({
    required this.id,
    required this.type,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.uploadTime,
    required this.uploaderId,
    required this.uploaderName,
    this.submitTime,
    required this.isFavorite,
    this.comment,
    required this.url,
    required this.detail,
  });
}

// ---------------------------------------------------------------------------
// CalendarEvent
// ---------------------------------------------------------------------------

class CalendarEvent {
  final String location;
  final String status;
  final String startTime;
  final String endTime;
  final String date;
  final String courseName;

  const CalendarEvent({
    required this.location,
    required this.status,
    required this.startTime,
    required this.endTime,
    required this.date,
    required this.courseName,
  });
}

// ---------------------------------------------------------------------------
// FavoriteItem
// ---------------------------------------------------------------------------

class FavoriteItem {
  final String id;
  final ContentType type;
  final String title;
  final String time;
  final String state;
  final String? extra;
  final String semesterId;
  final String courseId;
  final bool pinned;
  final String? pinnedTime;
  final String? comment;
  final String addedTime;
  final String itemId;

  const FavoriteItem({
    required this.id,
    required this.type,
    required this.title,
    required this.time,
    required this.state,
    this.extra,
    required this.semesterId,
    required this.courseId,
    required this.pinned,
    this.pinnedTime,
    this.comment,
    required this.addedTime,
    required this.itemId,
  });
}

// ---------------------------------------------------------------------------
// CommentItem
// ---------------------------------------------------------------------------

class CommentItem {
  final String id;
  final ContentType type;
  final String content;
  final String contentHTML;
  final String title;
  final String semesterId;
  final String courseId;
  final String commentTime;
  final String itemId;

  const CommentItem({
    required this.id,
    required this.type,
    required this.content,
    required this.contentHTML,
    required this.title,
    required this.semesterId,
    required this.courseId,
    required this.commentTime,
    required this.itemId,
  });
}

// ---------------------------------------------------------------------------
// ApiError
// ---------------------------------------------------------------------------

class ApiError implements Exception {
  final FailReason reason;
  final dynamic extra;

  const ApiError({required this.reason, this.extra});

  @override
  String toString() => 'ApiError(${reason.message}${extra != null ? ', $extra' : ''})';
}
