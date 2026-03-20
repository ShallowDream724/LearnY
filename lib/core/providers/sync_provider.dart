/// Data sync providers — fetch data from API and cache in DB.
///
/// These providers handle the bridge between the API and local database.
/// Partial failures are tracked and reported, not silently swallowed.
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart' as api;
import '../api/enums.dart';
import '../api/learn_api.dart';
import '../database/database.dart';
import 'providers.dart';

// ---------------------------------------------------------------------------
// Sync state
// ---------------------------------------------------------------------------

enum SyncStatus { idle, syncing, success, error, sessionExpired, cooldown }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSynced;

  /// Per-course warnings (partial failures that didn't block overall sync).
  final List<String> syncWarnings;

  /// Number of items updated in the last sync.
  final int updatedCount;

  /// Seconds remaining before next sync allowed (only for cooldown status).
  final int cooldownSeconds;

  const SyncState({
    this.status = SyncStatus.idle,
    this.errorMessage,
    this.lastSynced,
    this.syncWarnings = const [],
    this.updatedCount = 0,
    this.cooldownSeconds = 0,
  });
}

// ---------------------------------------------------------------------------
// Home data — aggregated from multiple sources
// ---------------------------------------------------------------------------

class HomeData {
  final List<HomeworkSummary> urgentAssignments;
  final List<NotificationSummary> unreadNotifications;
  final List<FileSummary> newFiles;
  final List<GradeSummary> recentGrades;
  final int totalCourses;
  final int pendingAssignments;
  final int unreadCount;
  final int totalUnreadFiles;

  const HomeData({
    this.urgentAssignments = const [],
    this.unreadNotifications = const [],
    this.newFiles = const [],
    this.recentGrades = const [],
    this.totalCourses = 0,
    this.pendingAssignments = 0,
    this.unreadCount = 0,
    this.totalUnreadFiles = 0,
  });
}

/// Lightweight homework summary for home screen cards.
class HomeworkSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String deadline;
  final Duration timeRemaining;
  final bool isOverdue;

  const HomeworkSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.deadline,
    required this.timeRemaining,
    required this.isOverdue,
  });
}

/// Lightweight notification summary.
class NotificationSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String publisher;
  final String publishTime;
  final bool markedImportant;

  const NotificationSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.publisher,
    required this.publishTime,
    required this.markedImportant,
  });
}

/// Lightweight file summary.
class FileSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String size;
  final String fileType;
  final String uploadTime;

  const FileSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.size,
    required this.fileType,
    required this.uploadTime,
  });
}

/// Lightweight grade summary.
class GradeSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final double? grade;
  final String? gradeLevel;
  final String? gradeContent;

  const GradeSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    this.grade,
    this.gradeLevel,
    this.gradeContent,
  });
}

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
      final api = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);
      final warnings = <String>[];

      // 1. Semester + courses (required before content sync)
      final courses = await _syncSemesterAndCourses(api, db);

      // 2. Stream content by priority: HW → notifications → files
      //    Each type completes for ALL courses before next type starts.
      //    Within each type, batch 4 courses in parallel.
      await _syncTypeForAllCourses(api, db, courses, _ContentType.homework, warnings);
      // ↑ At this point DDL banner can already show fresh data

      await _syncTypeForAllCourses(api, db, courses, _ContentType.notification, warnings);
      // ↑ Now unread notifications are fresh too

      await _syncTypeForAllCourses(api, db, courses, _ContentType.file, warnings);
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
      final api = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);
      final courses = await _getStoredCourses(db);
      final warnings = <String>[];
      await _syncTypeForAllCourses(api, db, courses, _ContentType.homework, warnings);
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
      final api = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);
      final courses = await _getStoredCourses(db);
      final warnings = <String>[];
      await _syncTypeForAllCourses(api, db, courses, _ContentType.file, warnings);
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

    final api = _ref.read(apiClientProvider);
    final db = _ref.read(databaseProvider);
    final warnings = <String>[];
    final ref = _SyncCourseRef(courseId, '');

    // All 3 types in parallel for this one course
    await Future.wait([
      _syncHomeworks(api, db, ref, warnings),
      _syncNotifications(api, db, ref, warnings),
      _syncFiles(api, db, ref, warnings),
    ]);

    _courseSyncTimes[courseId] = DateTime.now();
  }

  // -----------------------------------------------------------------------
  // Internal helpers
  // -----------------------------------------------------------------------

  /// Sync semester info and course list. Returns courses.
  Future<List<dynamic>> _syncSemesterAndCourses(
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
    return courses;
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
    List<dynamic> courses,
    _ContentType type,
    List<String> warnings,
  ) async {
    await Future.wait(courses.map((course) {
      final ref = course is _SyncCourseRef
          ? course
          : _SyncCourseRef(course.id, course.name);
      return switch (type) {
        _ContentType.homework => _syncHomeworks(apiClient, db, ref, warnings),
        _ContentType.notification => _syncNotifications(apiClient, db, ref, warnings),
        _ContentType.file => _syncFiles(apiClient, db, ref, warnings),
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

// ---------------------------------------------------------------------------
// Home data provider
// ---------------------------------------------------------------------------

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final db = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  final thresholdHours = ref.watch(deadlineThresholdHoursProvider);

  if (semesterId == null) return const HomeData();

  final courses = await db.getCoursesBySemester(semesterId);
  final courseMap = {for (final c in courses) c.id: c.name};

  // Get upcoming homeworks (not submitted)
  final allHomeworks = await db.getUpcomingHomeworks();
  final now = DateTime.now();

  final urgentAssignments = <HomeworkSummary>[];
  int pendingCount = 0;

  for (final hw in allHomeworks) {
    if (!courseMap.containsKey(hw.courseId)) continue;

    final deadlineMs = int.tryParse(hw.deadline);
    DateTime? deadlineTime;
    if (deadlineMs != null) {
      deadlineTime = DateTime.fromMillisecondsSinceEpoch(deadlineMs);
    }

    final remaining = deadlineTime?.difference(now) ?? Duration.zero;
    final isOverdue = remaining.isNegative;

    pendingCount++;

    // Only show assignments within threshold or overdue
    if (remaining.inHours <= thresholdHours || isOverdue) {
      urgentAssignments.add(HomeworkSummary(
        id: hw.id,
        courseId: hw.courseId,
        courseName: courseMap[hw.courseId] ?? '',
        title: hw.title,
        deadline: hw.deadline,
        timeRemaining: remaining,
        isOverdue: isOverdue,
      ));
    }
  }

  // Sort by urgency (most urgent first)
  urgentAssignments.sort((a, b) => a.timeRemaining.compareTo(b.timeRemaining));

  // Get unread notifications
  final unreadNotifs = await db.getUnreadNotifications();
  final unreadNotifications = unreadNotifs
      .where((n) => courseMap.containsKey(n.courseId))
      .take(10)
      .map((n) => NotificationSummary(
            id: n.id,
            courseId: n.courseId,
            courseName: courseMap[n.courseId] ?? '',
            title: n.title,
            publisher: n.publisher,
            publishTime: n.publishTime,
            markedImportant: n.markedImportant,
          ))
      .toList();

  // Get unread files — single efficient query instead of per-course loop
  final unreadFiles = await db.getUnreadFiles();
  final newFileSummaries = unreadFiles
      .where((f) => courseMap.containsKey(f.courseId))
      .map((f) => FileSummary(
            id: f.id,
            courseId: f.courseId,
            courseName: courseMap[f.courseId] ?? '',
            title: f.title,
            size: f.size,
            fileType: f.fileType,
            uploadTime: f.uploadTime,
          ))
      .toList();

  // Get recent grades (graded homeworks)
  final recentGradeSummaries = <GradeSummary>[];
  for (final course in courses) {
    final homeworks = await db.getHomeworksByCourse(course.id);
    for (final hw in homeworks) {
      if (hw.graded && hw.grade != null) {
        recentGradeSummaries.add(GradeSummary(
          id: hw.id,
          courseId: course.id,
          courseName: course.name,
          title: hw.title,
          grade: hw.grade,
          gradeLevel: hw.gradeLevel,
          gradeContent: hw.gradeContent,
        ));
      }
    }
  }
  recentGradeSummaries.sort((a, b) => b.id.compareTo(a.id));

  return HomeData(
    urgentAssignments: urgentAssignments.take(5).toList(),
    unreadNotifications: unreadNotifications,
    newFiles: newFileSummaries.take(5).toList(),
    recentGrades: recentGradeSummaries.take(5).toList(),
    totalCourses: courses.length,
    pendingAssignments: pendingCount,
    unreadCount: unreadNotifications.length,
    totalUnreadFiles: newFileSummaries.length,
  );
});

