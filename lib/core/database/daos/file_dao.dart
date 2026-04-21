part of '../database.dart';

extension FileDao on AppDatabase {
  Future<List<CourseFile>> getFilesByCourse(String courseId) =>
      (select(courseFiles)..where((t) => t.courseId.equals(courseId))).get();

  Future<List<CourseFile>> getFilesBySemester(String semesterId) {
    final query =
        select(courseFiles).join([
            innerJoin(courses, courses.id.equalsExp(courseFiles.courseId)),
          ])
          ..where(courses.semesterId.equals(semesterId))
          ..orderBy([OrderingTerm.desc(courseFiles.uploadTime)]);

    return query.map((row) => row.readTable(courseFiles)).get();
  }

  Future<void> upsertFile(CourseFilesCompanion entry) =>
      into(courseFiles).insertOnConflictUpdate(entry);

  Future<void> updateFileDownloadState(
    String id,
    String state,
    String? localPath,
  ) => (update(courseFiles)..where((t) => t.id.equals(id))).write(
    CourseFilesCompanion(
      localDownloadState: Value(state),
      localFilePath: Value(localPath),
    ),
  );

  Future<void> updateFileLocalPath(String id, String? localPath) =>
      (update(courseFiles)..where((t) => t.id.equals(id))).write(
        CourseFilesCompanion(localFilePath: Value(localPath)),
      );

  Future<void> rewriteDownloadedFilePathPrefix(
    String fromPrefix,
    String toPrefix,
  ) {
    return customUpdate(
      '''
      UPDATE course_files
      SET local_file_path = REPLACE(local_file_path, ?, ?)
      WHERE local_file_path LIKE ?
      ''',
      variables: [
        Variable<String>(fromPrefix),
        Variable<String>(toPrefix),
        Variable<String>('$fromPrefix%'),
      ],
      updates: {courseFiles},
    );
  }

  Stream<List<CourseFile>> watchFilesByCourse(String courseId) =>
      (select(courseFiles)..where((t) => t.courseId.equals(courseId))).watch();

  Stream<List<CourseFile>> watchFilesBySemester(String semesterId) {
    final query =
        select(courseFiles).join([
            innerJoin(courses, courses.id.equalsExp(courseFiles.courseId)),
          ])
          ..where(courses.semesterId.equals(semesterId))
          ..orderBy([OrderingTerm.desc(courseFiles.uploadTime)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(courseFiles)).toList(),
    );
  }

  Stream<CourseFile?> watchFileById(String id) =>
      (select(courseFiles)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<List<CourseFile>> watchAllFiles() => (select(
    courseFiles,
  )..orderBy([(t) => OrderingTerm.desc(t.uploadTime)])).watch();

  Future<List<CourseFile>> getAllFiles() => (select(
    courseFiles,
  )..orderBy([(t) => OrderingTerm.desc(t.uploadTime)])).get();

  Future<CourseFile?> getFileById(String id) =>
      (select(courseFiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> toggleFileFavorite(String id, bool value) =>
      (update(courseFiles)..where((t) => t.id.equals(id))).write(
        CourseFilesCompanion(isFavorite: Value(value)),
      );

  Future<void> markFileRead(String id) =>
      (update(courseFiles)..where((t) => t.id.equals(id))).write(
        const CourseFilesCompanion(isNew: Value(false)),
      );

  Future<void> markFileUnread(String id) =>
      (update(courseFiles)..where((t) => t.id.equals(id))).write(
        const CourseFilesCompanion(isNew: Value(true)),
      );

  Stream<List<CourseFile>> watchUnreadFiles() =>
      (select(courseFiles)
            ..where((t) => t.isNew.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.uploadTime)]))
          .watch();

  Stream<List<CourseFile>> watchUnreadFilesBySemester(String semesterId) {
    final query =
        select(courseFiles).join([
            innerJoin(courses, courses.id.equalsExp(courseFiles.courseId)),
          ])
          ..where(
            courses.semesterId.equals(semesterId) &
                courseFiles.isNew.equals(true),
          )
          ..orderBy([OrderingTerm.desc(courseFiles.uploadTime)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(courseFiles)).toList(),
    );
  }

  Future<List<CourseFile>> getUnreadFiles() =>
      (select(courseFiles)
            ..where((t) => t.isNew.equals(true))
            ..orderBy([(t) => OrderingTerm.desc(t.uploadTime)]))
          .get();
}
