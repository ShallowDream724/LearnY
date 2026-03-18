/// LearnY Database — Drift schema for offline caching.
///
/// Tables mirror the API models for local persistence.
/// Run `dart run build_runner build` to generate `database.g.dart`.
import 'package:drift/drift.dart';

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Tables
// ---------------------------------------------------------------------------

/// Cached semesters.
class Semesters extends Table {
  TextColumn get id => text()();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  IntColumn get startYear => integer()();
  IntColumn get endYear => integer()();
  TextColumn get type => text()(); // fall, spring, summer

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached courses.
class Courses extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get chineseName => text()();
  TextColumn get englishName => text().withDefault(const Constant(''))();
  TextColumn get teacherName => text().withDefault(const Constant(''))();
  TextColumn get teacherNumber => text().withDefault(const Constant(''))();
  TextColumn get courseNumber => text().withDefault(const Constant(''))();
  IntColumn get courseIndex => integer().withDefault(const Constant(0))();
  TextColumn get courseType => text()(); // student, teacher
  TextColumn get semesterId => text()();
  TextColumn get timeAndLocationJson => text().withDefault(const Constant('[]'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSynced => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached notifications.
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get courseId => text()();
  TextColumn get title => text()();
  TextColumn get content => text().withDefault(const Constant(''))();
  TextColumn get publisher => text().withDefault(const Constant(''))();
  TextColumn get publishTime => text()();
  TextColumn get expireTime => text().nullable()();
  BoolColumn get hasRead => boolean().withDefault(const Constant(false))();
  BoolColumn get hasReadLocal => boolean().withDefault(const Constant(false))();
  BoolColumn get markedImportant => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get comment => text().nullable()();
  TextColumn get attachmentJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached course files.
class CourseFiles extends Table {
  TextColumn get id => text()();
  TextColumn get courseId => text()();
  TextColumn get fileId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get rawSize => integer().withDefault(const Constant(0))();
  TextColumn get size => text().withDefault(const Constant(''))();
  TextColumn get uploadTime => text()();
  TextColumn get fileType => text().withDefault(const Constant(''))();
  TextColumn get downloadUrl => text()();
  TextColumn get previewUrl => text()();
  BoolColumn get isNew => boolean().withDefault(const Constant(false))();
  BoolColumn get markedImportant => boolean().withDefault(const Constant(false))();
  IntColumn get visitCount => integer().withDefault(const Constant(0))();
  IntColumn get downloadCount => integer().withDefault(const Constant(0))();
  TextColumn get categoryId => text().nullable()();
  TextColumn get categoryTitle => text().nullable()();
  BoolColumn get isFavorite => boolean().nullable()();
  TextColumn get comment => text().nullable()();

  /// Local download state: 'none', 'downloading', 'downloaded', 'failed'
  TextColumn get localDownloadState =>
      text().withDefault(const Constant('none'))();
  TextColumn get localFilePath => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Cached homework assignments.
class Homeworks extends Table {
  TextColumn get id => text()();
  TextColumn get courseId => text()();
  TextColumn get baseId => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get deadline => text()();
  TextColumn get lateSubmissionDeadline => text().nullable()();
  TextColumn get submitTime => text().nullable()();
  BoolColumn get submitted => boolean().withDefault(const Constant(false))();
  BoolColumn get graded => boolean().withDefault(const Constant(false))();
  RealColumn get grade => real().nullable()();
  TextColumn get gradeLevel => text().nullable()();
  TextColumn get graderName => text().nullable()();
  TextColumn get gradeContent => text().nullable()();
  TextColumn get gradeTime => text().nullable()();
  BoolColumn get isLateSubmission => boolean().withDefault(const Constant(false))();
  IntColumn get completionType => integer().nullable()();
  IntColumn get submissionType => integer().nullable()();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get comment => text().nullable()();
  TextColumn get attachmentJson => text().nullable()();
  TextColumn get answerContent => text().nullable()();
  TextColumn get answerAttachmentJson => text().nullable()();
  TextColumn get submittedContent => text().nullable()();
  TextColumn get submittedAttachmentJson => text().nullable()();
  TextColumn get gradeAttachmentJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key-value store for app state and preferences.
class AppState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  Semesters,
  Courses,
  Notifications,
  CourseFiles,
  Homeworks,
  AppState,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // ─── App State DAO ───

  Future<String?> getState(String key) async {
    final row = await (select(appState)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setState(String key, String value) async {
    await into(appState).insertOnConflictUpdate(
      AppStateCompanion(
        key: Value(key),
        value: Value(value),
      ),
    );
  }

  // ─── Semester DAO ───

  Future<List<Semester>> getAllSemesters() => select(semesters).get();

  Future<void> upsertSemester(SemestersCompanion entry) =>
      into(semesters).insertOnConflictUpdate(entry);

  // ─── Course DAO ───

  Future<List<Course>> getCoursesBySemester(String semesterId) =>
      (select(courses)..where((t) => t.semesterId.equals(semesterId))).get();

  Future<void> upsertCourse(CoursesCompanion entry) =>
      into(courses).insertOnConflictUpdate(entry);

  // ─── Notification DAO ───

  Future<List<Notification>> getNotificationsByCourse(String courseId) =>
      (select(notifications)..where((t) => t.courseId.equals(courseId))).get();

  Future<List<Notification>> getUnreadNotifications() =>
      (select(notifications)..where((t) => t.hasRead.equals(false) & t.hasReadLocal.equals(false))).get();

  Future<void> upsertNotification(NotificationsCompanion entry) =>
      into(notifications).insertOnConflictUpdate(entry);

  Future<void> markNotificationReadLocal(String id) =>
      (update(notifications)..where((t) => t.id.equals(id)))
          .write(const NotificationsCompanion(hasReadLocal: Value(true)));

  // ─── File DAO ───

  Future<List<CourseFile>> getFilesByCourse(String courseId) =>
      (select(courseFiles)..where((t) => t.courseId.equals(courseId))).get();

  Future<void> upsertFile(CourseFilesCompanion entry) =>
      into(courseFiles).insertOnConflictUpdate(entry);

  Future<void> updateFileDownloadState(
    String id,
    String state,
    String? localPath,
  ) =>
      (update(courseFiles)..where((t) => t.id.equals(id))).write(
        CourseFilesCompanion(
          localDownloadState: Value(state),
          localFilePath: Value(localPath),
        ),
      );

  // ─── Homework DAO ───

  Future<List<Homework>> getHomeworksByCourse(String courseId) =>
      (select(homeworks)..where((t) => t.courseId.equals(courseId))).get();

  Future<List<Homework>> getUpcomingHomeworks() =>
      (select(homeworks)
            ..where((t) => t.submitted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.deadline)]))
          .get();

  Future<void> upsertHomework(HomeworksCompanion entry) =>
      into(homeworks).insertOnConflictUpdate(entry);

  // ─── Bulk operations ───

  Future<void> clearCourseDependentData(String courseId) async {
    await (delete(notifications)..where((t) => t.courseId.equals(courseId))).go();
    await (delete(courseFiles)..where((t) => t.courseId.equals(courseId))).go();
    await (delete(homeworks)..where((t) => t.courseId.equals(courseId))).go();
  }

  Future<void> clearAllData() async {
    await delete(semesters).go();
    await delete(courses).go();
    await delete(notifications).go();
    await delete(courseFiles).go();
    await delete(homeworks).go();
    await delete(appState).go();
  }
}
