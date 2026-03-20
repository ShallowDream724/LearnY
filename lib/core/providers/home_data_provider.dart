/// Home data provider — aggregates data from DB for the home screen.
///
/// Separated from sync logic for clean dependency graph.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import 'providers.dart';
import 'sync_models.dart';

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
