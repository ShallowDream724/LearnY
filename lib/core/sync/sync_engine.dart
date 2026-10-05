import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../api/enums.dart';
import '../api/learning_read_api.dart';
import '../api/models.dart' as api;
import '../database/database.dart';
import '../files/file_models.dart';
import '../files/file_repository.dart';
import '../courses/course_catalog_repository.dart';
import '../semester/semester_repository.dart';
import '../utils/concurrent_map.dart';
import 'sync_operation.dart';

class SyncExecutionResult {
  const SyncExecutionResult({
    required this.updatedCount,
    required this.syncedCourseIds,
    this.warnings = const [],
  });

  final int updatedCount;
  final List<String> syncedCourseIds;
  final List<String> warnings;
}

class SyncEngine {
  SyncEngine({
    required this.apiClient,
    required this.database,
    required this.fileRepository,
    required this.semesterRepository,
    CourseCatalogRepository? courseCatalog,
  }) : _courseCatalog =
           courseCatalog ??
           CourseCatalogRepository(database: database, apiClient: apiClient);

  final LearningReadApi apiClient;
  final AppDatabase database;
  final FileRepository fileRepository;
  final SemesterRepository semesterRepository;
  final CourseCatalogRepository _courseCatalog;

  Future<SyncExecutionResult> syncAll(
    String semesterId, {
    SyncOperation? operation,
  }) async {
    operation ??= SyncOperation();
    final warnings = <String>[];
    final courses = await _syncSemesterAndCourses(semesterId, operation);

    await _syncTypeForAllCourses(
      courses,
      _SyncContentType.homework,
      warnings,
      operation,
    );
    await _syncTypeForAllCourses(
      courses,
      _SyncContentType.notification,
      warnings,
      operation,
    );
    await _syncTypeForAllCourses(
      courses,
      _SyncContentType.file,
      warnings,
      operation,
    );
    operation.ensureActive();
    _requireSomeContentSucceeded(courses.length * 3, warnings);

    return SyncExecutionResult(
      updatedCount: courses.length,
      syncedCourseIds: [for (final course in courses) course.id],
      warnings: warnings,
    );
  }

  Future<SyncExecutionResult> syncHomeworksOnly(
    String? semesterId, {
    SyncOperation? operation,
  }) async {
    operation ??= SyncOperation();
    final warnings = <String>[];
    final courses = await _getStoredCourses(semesterId);

    await _syncTypeForAllCourses(
      courses,
      _SyncContentType.homework,
      warnings,
      operation,
    );
    operation.ensureActive();
    _requireSomeContentSucceeded(courses.length, warnings);

    return SyncExecutionResult(
      updatedCount: courses.length,
      syncedCourseIds: [for (final course in courses) course.id],
      warnings: warnings,
    );
  }

  Future<SyncExecutionResult> syncFilesOnly(
    String? semesterId, {
    SyncOperation? operation,
  }) async {
    operation ??= SyncOperation();
    final warnings = <String>[];
    final courses = await _getStoredCourses(semesterId);

    await _syncTypeForAllCourses(
      courses,
      _SyncContentType.file,
      warnings,
      operation,
    );
    operation.ensureActive();
    _requireSomeContentSucceeded(courses.length, warnings);

    return SyncExecutionResult(
      updatedCount: courses.length,
      syncedCourseIds: [for (final course in courses) course.id],
      warnings: warnings,
    );
  }

  Future<SyncExecutionResult> syncCourse(
    String courseId, {
    SyncOperation? operation,
  }) async {
    operation ??= SyncOperation();
    final warnings = <String>[];
    final course = _SyncCourseRef(courseId, '');

    await Future.wait([
      _syncHomeworks(course, warnings, operation),
      _syncNotifications(course, warnings, operation),
      _syncFiles(course, warnings, operation),
    ]);
    operation.ensureActive();
    _requireSomeContentSucceeded(3, warnings);

    return SyncExecutionResult(
      updatedCount: 1,
      syncedCourseIds: [courseId],
      warnings: warnings,
    );
  }

  Future<List<_SyncCourseRef>> _syncSemesterAndCourses(
    String semesterId,
    SyncOperation operation,
  ) async {
    operation.ensureActive();
    final semester = await semesterRepository.ensureSemester(
      semesterId,
      ensureActive: operation.ensureActive,
    );
    final courses = await _courseCatalog.refresh(semester.id, operation);

    return courses
        .map((course) => _SyncCourseRef(course.id, course.name))
        .toList();
  }

  Future<List<_SyncCourseRef>> _getStoredCourses(String? semesterId) async {
    if (semesterId == null) return [];

    final courses = await database.getCoursesBySemester(semesterId);
    return courses
        .map((course) => _SyncCourseRef(course.id, course.name))
        .toList();
  }

  Future<void> _syncTypeForAllCourses(
    List<_SyncCourseRef> courses,
    _SyncContentType type,
    List<String> warnings,
    SyncOperation operation,
  ) async {
    // Keep each content type bounded while slow courses do not hold an entire
    // batch. Cancellation prevents new work and waits for in-flight operations.
    await mapWithConcurrency<_SyncCourseRef, void>(courses, (course) {
      operation.ensureActive();
      return switch (type) {
        _SyncContentType.homework => _syncHomeworks(
          course,
          warnings,
          operation,
        ),
        _SyncContentType.notification => _syncNotifications(
          course,
          warnings,
          operation,
        ),
        _SyncContentType.file => _syncFiles(course, warnings, operation),
      };
    });
  }

  Future<void> _syncHomeworks(
    _SyncCourseRef course,
    List<String> warnings,
    SyncOperation operation,
  ) async {
    try {
      operation.ensureActive();
      final homeworks = await apiClient.getHomeworkList(course.id);
      operation.ensureActive();
      await database.transaction(() async {
        for (final homework in homeworks) {
          await database.upsertHomework(
            HomeworksCompanion.insert(
              id: homework.id,
              courseId: course.id,
              baseId: homework.baseId,
              title: homework.title,
              deadline: homework.deadline,
              lateSubmissionDeadline: Value(homework.lateSubmissionDeadline),
              submitted: Value(homework.submitted),
              graded: Value(homework.graded),
              grade: Value(homework.grade),
              gradeLevel: Value(homework.gradeLevel?.value),
              graderName: Value(homework.graderName),
              gradeContent: Value(homework.gradeContent),
              gradeTime: Value(homework.gradeTime),
              submitTime: Value(homework.submitTime),
              isLateSubmission: Value(homework.isLateSubmission),
              completionType: Value(homework.completionType?.value),
              submissionType: Value(homework.submissionType?.value),
              isFavorite: Value(homework.isFavorite),
              comment: Value(homework.comment),
              description: Value(homework.description),
              attachmentJson: Value(
                _encodeAttachment(
                  homework.attachment,
                  kind: FileAttachmentKind.homeworkAttachment,
                ),
              ),
              answerContent: Value(homework.answerContent),
              answerAttachmentJson: Value(
                _encodeAttachment(
                  homework.answerAttachment,
                  kind: FileAttachmentKind.homeworkAnswer,
                ),
              ),
              submittedContent: Value(homework.submittedContent),
              submittedAttachmentJson: Value(
                _encodeAttachment(
                  homework.submittedAttachment,
                  kind: FileAttachmentKind.homeworkSubmitted,
                ),
              ),
              gradeAttachmentJson: Value(
                _encodeAttachment(
                  homework.gradeAttachment,
                  kind: FileAttachmentKind.homeworkGrade,
                ),
              ),
            ),
          );
        }
        await (database.delete(database.homeworks)..where(
              (row) =>
                  row.courseId.equals(course.id) &
                  row.id.isNotIn(homeworks.map((item) => item.id)),
            ))
            .go();
        operation.ensureActive();
      });
    } on SyncCancelled {
      rethrow;
    } on api.ApiError catch (error) {
      if (_isSessionError(error)) rethrow;
      warnings.add('${course.name}: 作业同步失败 ($error)');
    } catch (error) {
      warnings.add('${course.name}: 作业同步失败 ($error)');
    }
  }

  Future<void> _syncNotifications(
    _SyncCourseRef course,
    List<String> warnings,
    SyncOperation operation,
  ) async {
    try {
      operation.ensureActive();
      final notifications = await apiClient.getNotificationList(course.id);
      operation.ensureActive();
      await database.transaction(() async {
        for (final notification in notifications) {
          await database.upsertNotification(
            NotificationsCompanion.insert(
              id: notification.id,
              courseId: course.id,
              title: notification.title,
              content: Value(notification.content),
              publisher: Value(notification.publisher),
              publishTime: notification.publishTime,
              expireTime: Value(notification.expireTime),
              hasRead: Value(notification.hasRead),
              markedImportant: Value(notification.markedImportant),
              isFavorite: Value(notification.isFavorite),
              comment: Value(notification.comment),
              attachmentJson: Value(
                _encodeAttachment(
                  notification.attachment,
                  kind: FileAttachmentKind.notification,
                ),
              ),
            ),
          );
        }
        await (database.delete(database.notifications)..where(
              (row) =>
                  row.courseId.equals(course.id) &
                  row.id.isNotIn(notifications.map((item) => item.id)),
            ))
            .go();
        operation.ensureActive();
      });
    } on SyncCancelled {
      rethrow;
    } on api.ApiError catch (error) {
      if (_isSessionError(error)) rethrow;
      warnings.add('${course.name}: 通知同步失败 ($error)');
    } catch (error) {
      warnings.add('${course.name}: 通知同步失败 ($error)');
    }
  }

  Future<void> _syncFiles(
    _SyncCourseRef course,
    List<String> warnings,
    SyncOperation operation,
  ) async {
    try {
      operation.ensureActive();
      final files = await apiClient.getFileList(course.id);
      operation.ensureActive();
      await database.transaction(() async {
        await fileRepository.saveRemoteFiles(courseId: course.id, files: files);
        await (database.delete(database.courseFiles)..where(
              (row) =>
                  row.courseId.equals(course.id) &
                  row.id.isNotIn(files.map((item) => item.id)) &
                  row.localDownloadState.equals('none'),
            ))
            .go();
        operation.ensureActive();
      });
    } on SyncCancelled {
      rethrow;
    } on api.ApiError catch (error) {
      if (_isSessionError(error)) rethrow;
      debugPrint('[Sync] File sync failed for ${course.name}: $error');
      warnings.add('${course.name}: 文件同步失败 ($error)');
    } catch (error) {
      debugPrint('[Sync] File sync failed for ${course.name}: $error');
      warnings.add('${course.name}: 文件同步失败 ($error)');
    }
  }

  bool _isSessionError(api.ApiError error) {
    return error.reason == FailReason.notLoggedIn ||
        error.reason == FailReason.noCredential;
  }

  void _requireSomeContentSucceeded(int attempted, List<String> warnings) {
    if (attempted > 0 && warnings.length >= attempted) {
      throw SyncContentFailure(warnings);
    }
  }
}

class SyncContentFailure implements Exception {
  const SyncContentFailure(this.warnings);

  final List<String> warnings;

  @override
  String toString() => '课程内容未能更新，已保留本地缓存';
}

String? _encodeAttachment(
  api.RemoteFile? file, {
  required FileAttachmentKind kind,
}) {
  if (file == null) {
    return null;
  }
  return FileAttachment.fromApi(file, kind: kind).toJsonString();
}

enum _SyncContentType { homework, notification, file }

class _SyncCourseRef {
  const _SyncCourseRef(this.id, this.name);

  final String id;
  final String name;
}
