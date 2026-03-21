/// LearnY Database — Drift schema for offline caching.
///
/// Tables mirror the API models for local persistence.
/// Run `dart run build_runner build` to generate `database.g.dart`.
import 'package:drift/drift.dart';

import 'app_state_keys.dart';

part 'database.g.dart';
part 'daos/app_state_dao.dart';
part 'daos/cached_asset_dao.dart';
part 'daos/course_dao.dart';
part 'daos/file_dao.dart';
part 'daos/file_bookmark_dao.dart';
part 'daos/homework_dao.dart';
part 'daos/maintenance_dao.dart';
part 'daos/notification_dao.dart';
part 'daos/search_dao.dart';
part 'daos/semester_dao.dart';

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
  TextColumn get timeAndLocationJson =>
      text().withDefault(const Constant('[]'))();
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
  BoolColumn get markedImportant =>
      boolean().withDefault(const Constant(false))();
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
  BoolColumn get markedImportant =>
      boolean().withDefault(const Constant(false))();
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

/// Persistent cache registry for both course files and non-course attachments.
class CachedAssets extends Table {
  TextColumn get assetKey => text()();
  TextColumn get courseId => text()();
  TextColumn get title => text()();
  TextColumn get fileType => text().withDefault(const Constant(''))();
  TextColumn get localPath => text()();
  IntColumn get fileSizeBytes => integer().withDefault(const Constant(0))();
  TextColumn get lastAccessedAt => text().nullable()();
  TextColumn get updatedAt => text()();
  TextColumn get persistedFileId => text().nullable()();
  TextColumn get sourceKind => text().withDefault(const Constant('generic'))();
  TextColumn get routeDataJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {assetKey};
}

/// Locally bookmarked downloadable files.
class FileBookmarks extends Table {
  TextColumn get assetKey => text()();
  TextColumn get courseName => text().withDefault(const Constant(''))();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {assetKey};
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
  BoolColumn get isLateSubmission =>
      boolean().withDefault(const Constant(false))();
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

@DriftDatabase(
  tables: [
    Semesters,
    Courses,
    Notifications,
    CourseFiles,
    CachedAssets,
    FileBookmarks,
    Homeworks,
    AppState,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(cachedAssets);
        await customStatement('''
          INSERT OR REPLACE INTO cached_assets (
            asset_key,
            course_id,
            title,
            file_type,
            local_path,
            file_size_bytes,
            updated_at,
            persisted_file_id,
            source_kind
          )
          SELECT
            id,
            course_id,
            title,
            file_type,
            local_file_path,
            raw_size,
            CURRENT_TIMESTAMP,
            id,
            'courseFile'
          FROM course_files
          WHERE local_download_state = 'downloaded'
            AND local_file_path IS NOT NULL
        ''');
      }
      if (from < 3 &&
          !await _tableHasColumn('cached_assets', 'route_data_json')) {
        await m.addColumn(cachedAssets, cachedAssets.routeDataJson);
      }
      if (from < 4) {
        await m.createTable(fileBookmarks);
      }
      if (from < 5 && !await _tableHasColumn('file_bookmarks', 'course_name')) {
        await m.addColumn(fileBookmarks, fileBookmarks.courseName);
      }
    },
  );

  Future<bool> _tableHasColumn(String tableName, String columnName) async {
    final rows = await customSelect('PRAGMA table_info($tableName)').get();
    return rows.any((row) => row.data['name'] == columnName);
  }
}
