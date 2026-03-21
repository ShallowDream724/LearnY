import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../api/enums.dart';
import '../api/learn_api.dart';
import '../api/models.dart' as api;
import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../files/file_models.dart';
import '../files/file_repository.dart';

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
    required this.setCurrentSemesterId,
  });

  final Learn2018Helper apiClient;
  final AppDatabase database;
  final FileRepository fileRepository;
  final void Function(String semesterId) setCurrentSemesterId;

  Future<SyncExecutionResult> syncAll() async {
    final warnings = <String>[];
    final courses = await _syncSemesterAndCourses();

    await _syncTypeForAllCourses(courses, _SyncContentType.homework, warnings);
    await _syncTypeForAllCourses(
      courses,
      _SyncContentType.notification,
      warnings,
    );
    await _syncTypeForAllCourses(courses, _SyncContentType.file, warnings);

    return SyncExecutionResult(
      updatedCount: courses.length,
      syncedCourseIds: [for (final course in courses) course.id],
      warnings: warnings,
    );
  }

  Future<SyncExecutionResult> syncHomeworksOnly(String? semesterId) async {
    final warnings = <String>[];
    final courses = await _getStoredCourses(semesterId);

    await _syncTypeForAllCourses(courses, _SyncContentType.homework, warnings);

    return SyncExecutionResult(
      updatedCount: courses.length,
      syncedCourseIds: [for (final course in courses) course.id],
      warnings: warnings,
    );
  }

  Future<SyncExecutionResult> syncFilesOnly(String? semesterId) async {
    final warnings = <String>[];
    final courses = await _getStoredCourses(semesterId);

    await _syncTypeForAllCourses(courses, _SyncContentType.file, warnings);

    return SyncExecutionResult(
      updatedCount: courses.length,
      syncedCourseIds: [for (final course in courses) course.id],
      warnings: warnings,
    );
  }

  Future<SyncExecutionResult> syncCourse(String courseId) async {
    final warnings = <String>[];
    final course = _SyncCourseRef(courseId, '');

    await Future.wait([
      _syncHomeworks(course, warnings),
      _syncNotifications(course, warnings),
      _syncFiles(course, warnings),
    ]);

    return SyncExecutionResult(
      updatedCount: 1,
      syncedCourseIds: [courseId],
      warnings: warnings,
    );
  }

  Future<List<_SyncCourseRef>> _syncSemesterAndCourses() async {
    final semester = await apiClient.getCurrentSemester();

    await database.upsertSemester(
      SemestersCompanion.insert(
        id: semester.id,
        startDate: semester.startDate,
        endDate: semester.endDate,
        startYear: semester.startYear,
        endYear: semester.endYear,
        type: semester.type.value,
      ),
    );

    final courses = await apiClient.getCourseList(semester.id);
    final syncedAt = DateTime.now();
    for (final course in courses) {
      await database.upsertCourse(
        CoursesCompanion.insert(
          id: course.id,
          name: course.name,
          chineseName: course.chineseName,
          englishName: Value(course.englishName),
          teacherName: Value(course.teacherName),
          teacherNumber: Value(course.teacherNumber),
          courseNumber: Value(course.courseNumber),
          courseIndex: Value(course.courseIndex),
          courseType: course.courseType.value,
          semesterId: semester.id,
          timeAndLocationJson: Value(jsonEncode(course.timeAndLocation)),
          lastSynced: Value(syncedAt),
        ),
      );
    }

    setCurrentSemesterId(semester.id);
    await database.setState(AppStateKeys.currentSemesterId, semester.id);
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
  ) async {
    await Future.wait(
      courses.map((course) {
        return switch (type) {
          _SyncContentType.homework => _syncHomeworks(course, warnings),
          _SyncContentType.notification => _syncNotifications(course, warnings),
          _SyncContentType.file => _syncFiles(course, warnings),
        };
      }),
    );
  }

  Future<void> _syncHomeworks(
    _SyncCourseRef course,
    List<String> warnings,
  ) async {
    try {
      final homeworks = await apiClient.getHomeworkList(course.id);
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
      });
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
  ) async {
    try {
      final notifications = await apiClient.getNotificationList(course.id);
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
      });
    } on api.ApiError catch (error) {
      if (_isSessionError(error)) rethrow;
      warnings.add('${course.name}: 通知同步失败 ($error)');
    } catch (error) {
      warnings.add('${course.name}: 通知同步失败 ($error)');
    }
  }

  Future<void> _syncFiles(_SyncCourseRef course, List<String> warnings) async {
    try {
      final files = await apiClient.getFileList(course.id);
      await fileRepository.saveRemoteFiles(courseId: course.id, files: files);
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
