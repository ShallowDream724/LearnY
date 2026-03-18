/// Data sync providers — fetch data from API and cache in DB.
///
/// These providers handle the bridge between the API and local database.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
import '../api/models.dart' as api;
import '../api/enums.dart';
import '../database/database.dart';
import 'providers.dart';

// ---------------------------------------------------------------------------
// Sync state
// ---------------------------------------------------------------------------

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSynced;

  const SyncState({
    this.status = SyncStatus.idle,
    this.errorMessage,
    this.lastSynced,
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

      // 3. Fetch notifications, files, and homeworks for each course
      for (final course in courses) {
        try {
          // Notifications
          final notifications =
              await api.getNotificationList(course.id);
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
        } catch (_) {}

        try {
          // Homeworks
          final homeworks = await api.getHomeworkList(course.id);
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
        } catch (_) {}

        try {
          // Files
          final files = await api.getFileList(course.id);
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
        } catch (_) {}
      }

      state = SyncState(
        status: SyncStatus.success,
        lastSynced: DateTime.now(),
      );
    } catch (e) {
      state = SyncState(
        status: SyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Home data provider
// ---------------------------------------------------------------------------

final homeDataProvider = FutureProvider<HomeData>((ref) async {
  final db = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);

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

    // Only show urgent ones (next 7 days or overdue)
    if (remaining.inDays <= 7 || isOverdue) {
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
            publisher: n.publisher ?? '',
            publishTime: n.publishTime,
            markedImportant: n.markedImportant,
          ))
      .toList();

  return HomeData(
    urgentAssignments: urgentAssignments.take(5).toList(),
    unreadNotifications: unreadNotifications,
    newFiles: const [], // TODO: needs isNew tracking
    recentGrades: const [], // TODO: needs graded tracking
    totalCourses: courses.length,
    pendingAssignments: pendingCount,
    unreadCount: unreadNotifications.length,
  );
});
