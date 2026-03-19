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

enum SyncStatus { idle, syncing, success, error, sessionExpired }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSynced;

  /// Per-course warnings (partial failures that didn't block overall sync).
  final List<String> syncWarnings;

  /// Number of items updated in the last sync.
  final int updatedCount;

  const SyncState({
    this.status = SyncStatus.idle,
    this.errorMessage,
    this.lastSynced,
    this.syncWarnings = const [],
    this.updatedCount = 0,
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

  const HomeData({
    this.urgentAssignments = const [],
    this.unreadNotifications = const [],
    this.newFiles = const [],
    this.recentGrades = const [],
    this.totalCourses = 0,
    this.pendingAssignments = 0,
    this.unreadCount = 0,
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

  SyncNotifier(this._ref) : super(const SyncState());

  Future<void> syncAll() async {
    if (state.status == SyncStatus.syncing) return;

    state = const SyncState(status: SyncStatus.syncing);

    try {
      final api = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);
      final warnings = <String>[];
      int updated = 0;

      // 1. Get current semester
      final semester = await api.getCurrentSemester();
      _ref.read(currentSemesterIdProvider.notifier).state = semester.id;

      await db.upsertSemester(SemestersCompanion.insert(
        id: semester.id,
        startDate: semester.startDate,
        endDate: semester.endDate,
        startYear: semester.startYear,
        endYear: semester.endYear,
        type: semester.type.value,
      ));

      // 2. Get courses for current semester
      final courses = await api.getCourseList(semester.id);

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
      updated += courses.length;

      // 3. Fetch notifications, files, and homeworks — 4 courses concurrently
      const batchSize = 4;
      for (var i = 0; i < courses.length; i += batchSize) {
        final batch = courses.skip(i).take(batchSize);
        await Future.wait(batch.map((course) => _syncCourseData(
          api, db, _SyncCourseRef(course.id, course.name), warnings,
        )));
        updated += batch.length; // rough count
      }

      state = SyncState(
        status: SyncStatus.success,
        lastSynced: DateTime.now(),
        syncWarnings: warnings,
        updatedCount: updated,
      );

      // Force home screen to re-read data from DB.
      _ref.invalidate(homeDataProvider);
    } on api.ApiError catch (e) {
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
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: '同步失败: $e',
      );
    }
  }

  /// Sync a single course's data (notifications + homeworks + files in parallel).
  /// Used by pull-to-refresh in course detail.
  Future<void> syncCourse(String courseId) async {
    final api = _ref.read(apiClientProvider);
    final db = _ref.read(databaseProvider);
    final warnings = <String>[];
    await _syncCourseData(api, db,
        _SyncCourseRef(courseId, ''), warnings);
  }

  /// Internal helper: sync notifications, homeworks, and files for one course
  /// with parallel API fetches. Errors are collected into [warnings] instead
  /// of thrown.
  Future<void> _syncCourseData(
    Learn2018Helper api,
    AppDatabase db,
    _SyncCourseRef course,
    List<String> warnings,
  ) async {
    await Future.wait([
      // Notifications
      api.getNotificationList(course.id).then((notifications) async {
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
      }).catchError((e) {
        warnings.add('${course.name}: 通知同步失败 ($e)');
      }),

      // Homeworks
      api.getHomeworkList(course.id).then((homeworks) async {
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
      }).catchError((e) {
        warnings.add('${course.name}: 作业同步失败 ($e)');
      }),

      // Files
      api.getFileList(course.id).then((files) async {
        for (final f in files) {
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
            isNew: Value(f.isNew),
            markedImportant: Value(f.markedImportant),
            visitCount: Value(f.visitCount),
            downloadCount: Value(f.downloadCount),
          ));
        }
      }).catchError((e, stackTrace) {
        debugPrint('[Sync] File sync failed for ${course.name}: $e');
        debugPrint('[Sync] Stack trace:\n$stackTrace');
        warnings.add('${course.name}: 文件同步失败 ($e)');
      }),
    ]);
  }
}

/// Lightweight ref for _syncCourseData to avoid passing full Course objects.
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

  // Get new files (isNew == true)
  final newFileSummaries = <FileSummary>[];
  for (final course in courses) {
    final files = await db.getFilesByCourse(course.id);
    for (final f in files) {
      if (f.isNew) {
        newFileSummaries.add(FileSummary(
          id: f.id,
          courseId: course.id,
          courseName: course.name,
          title: f.title,
          size: f.size,
          fileType: f.fileType,
          uploadTime: f.uploadTime,
        ));
      }
    }
  }
  // Sort by upload time descending, take top 5
  newFileSummaries.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));

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
  // Sort by grade time descending if available, take top 5
  recentGradeSummaries.sort((a, b) {
    // Fallback: sort by ID descending
    return b.id.compareTo(a.id);
  });

  return HomeData(
    urgentAssignments: urgentAssignments.take(5).toList(),
    unreadNotifications: unreadNotifications,
    newFiles: newFileSummaries.take(5).toList(),
    recentGrades: recentGradeSummaries.take(5).toList(),
    totalCourses: courses.length,
    pendingAssignments: pendingCount,
    unreadCount: unreadNotifications.length,
  );
});

