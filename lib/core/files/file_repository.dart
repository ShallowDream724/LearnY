import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart' as api;
import '../database/database.dart' as db;
import '../providers/app_providers.dart';
import '../utils/stream_combiner.dart';
import 'file_models.dart';

abstract class FileRepository {
  Stream<List<db.CourseFile>> watchAllFiles();
  Stream<List<db.CourseFile>> watchUnreadFiles();
  Stream<List<db.CourseFile>> watchFilesByCourse(String courseId);
  Stream<db.CourseFile?> watchFileById(String fileId);
  Stream<List<FileWithCourse>> watchAllFilesWithCourse(String? semesterId);

  Future<List<db.CourseFile>> getAllFiles();
  Future<List<db.CourseFile>> getFilesByCourse(String courseId);
  Future<List<db.CourseFile>> getUnreadFiles();
  Future<db.CourseFile?> getFileById(String fileId);
  Future<Map<String, String>> getCourseNameMap(String? semesterId);

  Future<void> markRead(String fileId);
  Future<void> markUnread(String fileId);
  Future<void> setReadState(String fileId, {required bool isRead});
  Future<void> setFavoriteState(String fileId, {required bool isFavorite});
  Future<void> updateDownloadState(
    String fileId,
    String state,
    String? localPath,
  );
  Future<void> saveRemoteFiles({
    required String courseId,
    required List<api.CourseFile> files,
  });
}

final fileRepositoryProvider = Provider<FileRepository>((ref) {
  return DriftFileRepository(ref.watch(databaseProvider));
});

class DriftFileRepository implements FileRepository {
  DriftFileRepository(this._database);

  final db.AppDatabase _database;

  @override
  Stream<List<db.CourseFile>> watchAllFiles() => _database.watchAllFiles();

  @override
  Stream<List<db.CourseFile>> watchUnreadFiles() =>
      _database.watchUnreadFiles();

  @override
  Stream<List<db.CourseFile>> watchFilesByCourse(String courseId) =>
      _database.watchFilesByCourse(courseId);

  @override
  Stream<db.CourseFile?> watchFileById(String fileId) =>
      _database.watchFileById(fileId);

  @override
  Stream<List<FileWithCourse>> watchAllFilesWithCourse(String? semesterId) {
    if (semesterId == null) return Stream.value(const <FileWithCourse>[]);

    return combineLatest2(
      _database.watchCoursesBySemester(semesterId),
      _database.watchFilesBySemester(semesterId),
      (courses, files) {
        final courseMap = {
          for (final course in courses) course.id: course.name,
        };
        return files
            .map(
              (file) => FileWithCourse(
                file: file,
                courseName: courseMap[file.courseId] ?? '',
              ),
            )
            .toList();
      },
    );
  }

  @override
  Future<List<db.CourseFile>> getAllFiles() => _database.getAllFiles();

  @override
  Future<List<db.CourseFile>> getFilesByCourse(String courseId) =>
      _database.getFilesByCourse(courseId);

  @override
  Future<List<db.CourseFile>> getUnreadFiles() => _database.getUnreadFiles();

  @override
  Future<db.CourseFile?> getFileById(String fileId) =>
      _database.getFileById(fileId);

  @override
  Future<Map<String, String>> getCourseNameMap(String? semesterId) async {
    if (semesterId == null) return {};

    final courses = await _database.getCoursesBySemester(semesterId);
    return {for (final course in courses) course.id: course.name};
  }

  @override
  Future<void> markRead(String fileId) => _database.markFileRead(fileId);

  @override
  Future<void> markUnread(String fileId) => _database.markFileUnread(fileId);

  @override
  Future<void> setReadState(String fileId, {required bool isRead}) {
    if (isRead) {
      return markRead(fileId);
    }
    return markUnread(fileId);
  }

  @override
  Future<void> setFavoriteState(String fileId, {required bool isFavorite}) =>
      _database.toggleFileFavorite(fileId, isFavorite);

  @override
  Future<void> updateDownloadState(
    String fileId,
    String state,
    String? localPath,
  ) => _database.updateFileDownloadState(fileId, state, localPath);

  @override
  Future<void> saveRemoteFiles({
    required String courseId,
    required List<api.CourseFile> files,
  }) async {
    await _database.transaction(() async {
      for (final file in files) {
        final existing = await _database.getFileById(file.id);
        final shouldBeNew = existing != null ? existing.isNew : file.isNew;

        await _database.upsertFile(
          db.CourseFilesCompanion.insert(
            id: file.id,
            courseId: courseId,
            fileId: file.fileId,
            title: file.title,
            description: Value(file.description),
            rawSize: Value(file.rawSize),
            size: Value(file.size),
            uploadTime: file.uploadTime,
            fileType: Value(file.fileType),
            downloadUrl: file.downloadUrl,
            previewUrl: file.previewUrl,
            isNew: Value(shouldBeNew),
            markedImportant: Value(file.markedImportant),
            visitCount: Value(file.visitCount),
            downloadCount: Value(file.downloadCount),
            isFavorite: Value(file.isFavorite),
            comment: Value(file.comment),
          ),
        );
      }
    });
  }
}
