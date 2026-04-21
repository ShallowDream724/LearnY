import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_models.dart';
import '../../../core/utils/deadline_time.dart';
import '../../../core/utils/stream_combiner.dart';

final homeDataProvider = StreamProvider<HomeData>((ref) {
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  final thresholdHours = ref.watch(deadlineThresholdHoursProvider);
  final noSubmissionNeededIds =
      ref.watch(homeworkNoSubmissionNeededIdsProvider).valueOrNull ??
      const <String>{};

  if (semesterId == null) {
    return Stream.value(const HomeData());
  }

  return combineLatest5(
    database.watchCoursesBySemester(semesterId),
    database.watchHomeworksBySemester(semesterId),
    database.watchUnreadNotificationsBySemester(semesterId),
    database.watchUnreadFilesBySemester(semesterId),
    minuteTickStream(),
    (courses, homeworks, unreadNotifications, unreadFiles, now) {
      return _buildHomeData(
        courses: courses,
        homeworks: homeworks,
        unreadNotifications: unreadNotifications,
        unreadFiles: unreadFiles,
        noSubmissionNeededIds: noSubmissionNeededIds,
        thresholdHours: thresholdHours,
        now: now,
      );
    },
  );
});

HomeData _buildHomeData({
  required List<db.Course> courses,
  required List<db.Homework> homeworks,
  required List<db.Notification> unreadNotifications,
  required List<db.CourseFile> unreadFiles,
  required Set<String> noSubmissionNeededIds,
  required int thresholdHours,
  required DateTime now,
}) {
  final courseMap = {for (final course in courses) course.id: course.name};
  if (courseMap.isEmpty) {
    return const HomeData();
  }

  final urgentAssignments = <HomeworkSummary>[];
  final recentGradeSummaries = <GradeSummary>[];
  var pendingCount = 0;

  for (final homework in homeworks) {
    final courseName = courseMap[homework.courseId];
    if (courseName == null) {
      continue;
    }

    final isNoSubmissionNeeded =
        noSubmissionNeededIds.contains(homework.id) &&
        !homework.submitted &&
        !homework.graded;

    if (!homework.submitted && !homework.graded && !isNoSubmissionNeeded) {
      pendingCount++;

      final deadlineTime = tryParseEpochMillisToLocal(homework.deadline);
      final remaining = deadlineTime?.difference(now) ?? Duration.zero;
      final isOverdue = remaining.isNegative;

      if (remaining.inHours <= thresholdHours || isOverdue) {
        urgentAssignments.add(
          HomeworkSummary(
            id: homework.id,
            courseId: homework.courseId,
            courseName: courseName,
            title: homework.title,
            deadline: homework.deadline,
            timeRemaining: remaining,
            isOverdue: isOverdue,
          ),
        );
      }
    }

    if (homework.graded &&
        (homework.grade != null || homework.gradeLevel != null)) {
      recentGradeSummaries.add(
        GradeSummary(
          id: homework.id,
          courseId: homework.courseId,
          courseName: courseName,
          title: homework.title,
          grade: homework.grade,
          gradeLevel: homework.gradeLevel,
          gradeContent: homework.gradeContent,
        ),
      );
    }
  }

  urgentAssignments.sort((a, b) => a.timeRemaining.compareTo(b.timeRemaining));
  recentGradeSummaries.sort((a, b) => b.id.compareTo(a.id));

  final notificationSummaries = unreadNotifications
      .where((notification) => courseMap.containsKey(notification.courseId))
      .take(10)
      .map(
        (notification) => NotificationSummary(
          id: notification.id,
          courseId: notification.courseId,
          courseName: courseMap[notification.courseId] ?? '',
          title: notification.title,
          publisher: notification.publisher,
          publishTime: notification.publishTime,
          markedImportant: notification.markedImportant,
        ),
      )
      .toList();

  final fileSummaries =
      unreadFiles
          .where((file) => courseMap.containsKey(file.courseId))
          .map(
            (file) => FileSummary(
              id: file.id,
              courseId: file.courseId,
              courseName: courseMap[file.courseId] ?? '',
              title: file.title,
              fileType: file.fileType,
              size: file.size,
              uploadTime: file.uploadTime,
            ),
          )
          .toList()
        ..sort((a, b) => b.uploadTime.compareTo(a.uploadTime));

  return HomeData(
    urgentAssignments: urgentAssignments,
    unreadNotifications: notificationSummaries,
    newFiles: fileSummaries,
    recentGrades: recentGradeSummaries.take(5).toList(),
    totalCourses: courses.length,
    pendingAssignments: pendingCount,
    unreadCount: notificationSummaries.length,
    totalUnreadFiles: fileSummaries.length,
  );
}
