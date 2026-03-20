/// Data sync providers — fetch data from API and cache in DB.
///
/// These providers handle the bridge between the API and local database.
/// Partial failures are tracked and reported, not silently swallowed.
///
/// Re-exports [sync_models.dart] and [home_data_provider.dart] so that
/// consumers only need `import 'sync_provider.dart'` for full access.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart' as api;
import '../api/enums.dart';
import '../api/learn_api.dart';
import '../database/database.dart';
import 'providers.dart';
import 'sync_models.dart';

// Re-export so consumers only need one import.
export 'sync_models.dart';
export 'home_data_provider.dart';

// ---------------------------------------------------------------------------
// Sync provider
// ---------------------------------------------------------------------------

final syncStateProvider =
    StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  return SyncNotifier(ref);
});

class SyncNotifier extends StateNotifier<SyncState> {
  final Ref _ref;

  /// Last time a full sync completed.
  DateTime? _lastFullSync;

  /// Per-type last sync timestamps.
  DateTime? _lastHomeworkSync;
  DateTime? _lastFileSync;

  /// Per-course last sync timestamps.
  final _courseSyncTimes = <String, DateTime>{};

  /// Global cooldown: skip full sync if < 30s since last one.
  static const _globalCooldown = Duration(seconds: 30);

  /// Per-type cooldowns.
  static const _homeworkCooldown = Duration(seconds: 10);
  static const _fileCooldown = Duration(seconds: 15);

  /// Per-course cooldown.
  static const _courseCooldown = Duration(seconds: 5);

  SyncNotifier(this._ref) : super(const SyncState());

  // -----------------------------------------------------------------------
  // Public sync methods — one per page context
  // -----------------------------------------------------------------------

  /// Full sync for home screen / app launch.
  /// Priority: homeworks → notifications → files (streaming).
  /// Each type writes to DB immediately → Drift streams update UI.
  Future<void> syncAll() async {
    if (state.status == SyncStatus.syncing) return;

    // Cooldown check
    if (_lastFullSync != null &&
        DateTime.now().difference(_lastFullSync!) < _globalCooldown) {
      final remaining = _globalCooldown.inSeconds -
          DateTime.now().difference(_lastFullSync!).inSeconds;
      state = SyncState(
        status: SyncStatus.cooldown,
        cooldownSeconds: remaining,
        lastSynced: _lastFullSync,
      );
      return;
    }

    state = const SyncState(status: SyncStatus.syncing);

    try {
      final apiClient = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);
      final warnings = <String>[];

      // 1. Semester + courses (required before content sync)
      final courses = await _syncSemesterAndCourses(apiClient, db);

      // 2. Stream content by priority: HW → notifications → files
      //    Each type completes for ALL courses before next type starts.
      await _syncTypeForAllCourses(apiClient, db, courses, _ContentType.homework, warnings);
      // ↑ At this point DDL banner can already show fresh data

      await _syncTypeForAllCourses(apiClient, db, courses, _ContentType.notification, warnings);
      // ↑ Now unread notifications are fresh too

      await _syncTypeForAllCourses(apiClient, db, courses, _ContentType.file, warnings);
      // ↑ Finally, files are up to date

      _lastFullSync = DateTime.now();
      for (final c in courses) {
        _courseSyncTimes[c.id] = DateTime.now();
      }

      state = SyncState(
        status: SyncStatus.success,
        lastSynced: DateTime.now(),
        syncWarnings: warnings,
        updatedCount: courses.length,
      );
    } on api.ApiError catch (e) {
      _handleApiError(e);
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: '同步失败: $e',
      );
    }
  }

  /// Sync only homeworks for all courses.
  /// Used by: assignments page pull-to-refresh. Cooldown: 10s.
  Future<void> syncHomeworksOnly() async {
    if (state.status == SyncStatus.syncing) return;

    if (_lastHomeworkSync != null &&
        DateTime.now().difference(_lastHomeworkSync!) < _homeworkCooldown) {
      final remaining = _homeworkCooldown.inSeconds -
          DateTime.now().difference(_lastHomeworkSync!).inSeconds;
      state = SyncState(
        status: SyncStatus.cooldown,
        cooldownSeconds: remaining,
        lastSynced: _lastHomeworkSync,
      );
      return;
    }

    state = const SyncState(status: SyncStatus.syncing);
    try {
      final apiClient = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);
      final courses = await _getStoredCourses(db);
      final warnings = <String>[];
      await _syncTypeForAllCourses(apiClient, db, courses, _ContentType.homework, warnings);
      _lastHomeworkSync = DateTime.now();
      state = SyncState(
        status: SyncStatus.success,
        lastSynced: DateTime.now(),
        syncWarnings: warnings,
        updatedCount: courses.length,
      );
    } catch (e) {
      state = SyncState(status: SyncStatus.error, errorMessage: '$e');
    }
  }

  /// Sync only files for all courses.
  /// Used by: unread files page pull-to-refresh. Cooldown: 15s.
  Future<void> syncFilesOnly() async {
    if (state.status == SyncStatus.syncing) return;

    if (_lastFileSync != null &&
        DateTime.now().difference(_lastFileSync!) < _fileCooldown) {
      final remaining = _fileCooldown.inSeconds -
          DateTime.now().difference(_lastFileSync!).inSeconds;
      state = SyncState(
        status: SyncStatus.cooldown,
        cooldownSeconds: remaining,
        lastSynced: _lastFileSync,
      );
      return;
    }

    state = const SyncState(status: SyncStatus.syncing);
    try {
      final apiClient = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);
      final courses = await _getStoredCourses(db);
      final warnings = <String>[];
      await _syncTypeForAllCourses(apiClient, db, courses, _ContentType.file, warnings);
      _lastFileSync = DateTime.now();
      state = SyncState(
        status: SyncStatus.success,
        lastSynced: DateTime.now(),
        syncWarnings: warnings,
        updatedCount: courses.length,
      );
    } catch (e) {
      state = SyncState(status: SyncStatus.error, errorMessage: '$e');
    }
  }

  /// Sync a single course (all 3 types in parallel).
  /// Used by: course detail pull-to-refresh. Cooldown: 5s.
  Future<void> syncCourse(String courseId) async {
    final lastSync = _courseSyncTimes[courseId];
    if (lastSync != null &&
        DateTime.now().difference(lastSync) < _courseCooldown) {
      final remaining = _courseCooldown.inSeconds -
          DateTime.now().difference(lastSync).inSeconds;
      state = SyncState(
        status: SyncStatus.cooldown,
        cooldownSeconds: remaining,
        lastSynced: lastSync,
      );
      return;
    }

    final apiClient = _ref.read(apiClientProvider);
    final db = _ref.read(databaseProvider);
    final warnings = <String>[];
    final ref = _SyncCourseRef(courseId, '');

    // All 3 types in parallel for this one course
    await Future.wait([
      _syncHomeworks(apiClient, db, ref, warnings),
      _syncNotifications(apiClient, db, ref, warnings),
      _syncFiles(apiClient, db, ref, warnings),
    ]);

    _courseSyncTimes[courseId] = DateTime.now();
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  /// Sync semester info and course list. Returns typed course refs.
  Future<List<_SyncCourseRef>> _syncSemesterAndCourses(
    Learn2018Helper apiClient,
    AppDatabase db,
  ) async {
    final semester = await apiClient.getCurrentSemester();
    _ref.read(currentSemesterIdProvider.notifier).state = semester.id;

    await db.upsertSemester(SemestersCompanion.insert(
      id: semester.id,
      startDate: semester.startDate,
      endDate: semester.endDate,
      startYear: semester.startYear,
      endYear: semester.endYear,
      type: semester.type.value,
    ));

    final courses = await apiClient.getCourseList(semester.id);
    for (final c in courses) {
      await db.upsertCourse(CoursesCompanion.insert(
        id: c.id,
        name: c.name,
        chineseName: c.chineseName,
        englishName: Value(c.englishName),
        teacherName: Value(c.teacherName),
        teacherNumber: Value(c.teacherNumber),
        courseNumber: Value(c.courseNumber),
        courseIndex: Value(c.courseIndex),
        courseType: c.courseType.value,
        semesterId: semester.id,
      ));
    }
    return courses.map((c) => _SyncCourseRef(c.id, c.name)).toList();
  }

  /// Get already-stored courses from DB (for type-only syncs).
  Future<List<_SyncCourseRef>> _getStoredCourses(AppDatabase db) async {
    final semId = _ref.read(currentSemesterIdProvider);
    if (semId == null) return [];
    final courses = await db.getCoursesBySemester(semId);
    return courses.map((c) => _SyncCourseRef(c.id, c.name)).toList();
  }

  /// Sync one content type for all courses in parallel.
  Future<void> _syncTypeForAllCourses(
    Learn2018Helper apiClient,
    AppDatabase db,
    List<_SyncCourseRef> courses,
    _ContentType type,
    List<String> warnings,
  ) async {
    await Future.wait(courses.map((course) {
      return switch (type) {
        _ContentType.homework => _syncHomeworks(apiClient, db, course, warnings),
        _ContentType.notification => _syncNotifications(apiClient, db, course, warnings),
        _ContentType.file => _syncFiles(apiClient, db, course, warnings),
      };
    }));
  }

  /// Sync homeworks for one course.
  Future<void> _syncHomeworks(
    Learn2018Helper apiClient,
    AppDatabase db,
    _SyncCourseRef course,
    List<String> warnings,
  ) async {
    try {
      final homeworks = await apiClient.getHomeworkList(course.id);
      await db.transaction(() async {
        for (final h in homeworks) {
          await db.upsertHomework(HomeworksCompanion.insert(
            id: h.id,
            courseId: course.id,
            baseId: h.baseId,
            title: h.title,
            deadline: h.deadline,
            lateSubmissionDeadline: Value(h.lateSubmissionDeadline),
            submitted: Value(h.submitted),
            graded: Value(h.graded),
            grade: Value(h.grade),
            gradeLevel: Value(h.gradeLevel?.value),
            graderName: Value(h.graderName),
            gradeContent: Value(h.gradeContent),
            gradeTime: Value(h.gradeTime),
            submitTime: Value(h.submitTime),
            isLateSubmission: Value(h.isLateSubmission),
            isFavorite: Value(h.isFavorite),
            comment: Value(h.comment),
            description: Value(h.description),
          ));
        }
      });
    } catch (e) {
      warnings.add('${course.name}: 作业同步失败 ($e)');
    }
  }

  /// Sync notifications for one course.
  Future<void> _syncNotifications(
    Learn2018Helper apiClient,
    AppDatabase db,
    _SyncCourseRef course,
    List<String> warnings,
  ) async {
    try {
      final notifications = await apiClient.getNotificationList(course.id);
      await db.transaction(() async {
        for (final n in notifications) {
          await db.upsertNotification(NotificationsCompanion.insert(
            id: n.id,
            courseId: course.id,
            title: n.title,
            content: Value(n.content),
            publisher: Value(n.publisher),
            publishTime: n.publishTime,
            expireTime: Value(n.expireTime),
            hasRead: Value(n.hasRead),
            markedImportant: Value(n.markedImportant),
            isFavorite: Value(n.isFavorite),
            comment: Value(n.comment),
          ));
        }
      });
    } catch (e) {
      warnings.add('${course.name}: 通知同步失败 ($e)');
    }
  }

  /// Sync files for one course. Preserves local read state.
  Future<void> _syncFiles(
    Learn2018Helper apiClient,
    AppDatabase db,
    _SyncCourseRef course,
    List<String> warnings,
  ) async {
    try {
      final files = await apiClient.getFileList(course.id);
      await db.transaction(() async {
        for (final f in files) {
          final existing = await db.getFileById(f.id);
          final shouldBeNew = existing != null ? existing.isNew : f.isNew;

          await db.upsertFile(CourseFilesCompanion.insert(
            id: f.id,
            courseId: course.id,
            fileId: f.fileId,
            title: f.title,
            description: Value(f.description),
            rawSize: Value(f.rawSize),
            size: Value(f.size),
            uploadTime: f.uploadTime,
            fileType: Value(f.fileType),
            downloadUrl: f.downloadUrl,
            previewUrl: f.previewUrl,
            isNew: Value(shouldBeNew),
            markedImportant: Value(f.markedImportant),
            visitCount: Value(f.visitCount),
            downloadCount: Value(f.downloadCount),
          ));
        }
      });
    } catch (e) {
      debugPrint('[Sync] File sync failed for ${course.name}: $e');
      warnings.add('${course.name}: 文件同步失败 ($e)');
    }
  }

  void _handleApiError(api.ApiError e) {
    if (e.reason == FailReason.notLoggedIn || e.reason == FailReason.noCredential) {
      state = const SyncState(
        status: SyncStatus.sessionExpired,
        errorMessage: '会话过期，请重新登录',
      );
    } else {
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: '同步失败: $e',
      );
    }
  }
}

enum _ContentType { homework, notification, file }

/// Lightweight ref for sync helpers.
class _SyncCourseRef {
  final String id;
  final String name;
  const _SyncCourseRef(this.id, this.name);
}
