import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/providers/providers.dart';
import '../../../core/utils/notification_read_state.dart';
import '../../../core/utils/stream_combiner.dart';
import '../../../core/design/file_type_utils.dart';

class CourseStats {
  const CourseStats({
    required this.course,
    this.unreadNotifications = 0,
    this.pendingHomeworks = 0,
    this.totalFiles = 0,
  });

  final db.Course course;
  final int unreadNotifications;
  final int pendingHomeworks;
  final int totalFiles;
}

final courseStatsProvider = StreamProvider<List<CourseStats>>((ref) {
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) {
    return Stream.value(const <CourseStats>[]);
  }

  return combineLatest4(
    database.watchCoursesBySemester(semesterId),
    database.watchNotificationsBySemester(semesterId),
    database.watchHomeworksBySemester(semesterId),
    database.watchFilesBySemester(semesterId),
    (courses, notifications, homeworks, files) {
      return _buildCourseStats(
        courses: courses,
        notifications: notifications,
        homeworks: homeworks,
        files: files,
      );
    },
  );
});

List<CourseStats> _buildCourseStats({
  required List<db.Course> courses,
  required List<db.Notification> notifications,
  required List<db.Homework> homeworks,
  required List<db.CourseFile> files,
}) {
  final stats = <CourseStats>[];

  for (final course in courses) {
    final unread = notifications
        .where(
          (notification) =>
              notification.courseId == course.id &&
              notification.isEffectivelyUnread,
        )
        .length;
    final pending = homeworks
        .where(
          (homework) =>
              homework.courseId == course.id &&
              !homework.submitted &&
              !homework.graded,
        )
        .length;
    final totalFiles = files.where((file) => file.courseId == course.id).length;

    stats.add(
      CourseStats(
        course: course,
        unreadNotifications: unread,
        pendingHomeworks: pending,
        totalFiles: totalFiles,
      ),
    );
  }

  stats.sort((a, b) {
    final aScore = a.unreadNotifications + a.pendingHomeworks * 2;
    final bScore = b.unreadNotifications + b.pendingHomeworks * 2;
    return bScore.compareTo(aScore);
  });

  return stats;
}

final courseDetailProvider = StreamProvider.family<db.Course?, String>((
  ref,
  courseId,
) {
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) return Stream.value(null);

  return database.watchCoursesBySemester(semesterId).map((courses) {
    try {
      return courses.firstWhere((course) => course.id == courseId);
    } catch (_) {
      return null;
    }
  });
});

final courseNotificationsProvider =
    StreamProvider.family<List<db.Notification>, String>((ref, courseId) {
      final database = ref.watch(databaseProvider);
      return database.watchNotificationsByCourse(courseId).map((notifications) {
        notifications.sort((a, b) {
          final aIsRead = a.isEffectivelyRead;
          final bIsRead = b.isEffectivelyRead;
          if (aIsRead != bIsRead) return aIsRead ? 1 : -1;
          return b.publishTime.compareTo(a.publishTime);
        });
        return notifications;
      });
    });

final courseFilesProvider = StreamProvider.family<List<db.CourseFile>, String>((
  ref,
  courseId,
) {
  final database = ref.watch(databaseProvider);
  return database.watchFilesByCourse(courseId).map((files) {
    files.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    return files;
  });
});

enum CourseFileFilter { all, unread, favorite, downloaded }

class CourseFilesPresentation {
  const CourseFilesPresentation({
    required this.filteredFiles,
    required this.typeCounts,
  });

  final List<db.CourseFile> filteredFiles;
  final Map<String, int> typeCounts;
}

CourseFilesPresentation buildCourseFilesPresentation({
  required List<db.CourseFile> files,
  required Set<String> favoriteKeys,
  required CourseFileFilter filter,
  String? typeFilter,
}) {
  final typeCounts = <String, int>{};
  for (final file in files) {
    final ext = FileTypeUtils.extractExt(file.title, file.fileType);
    if (ext.isEmpty) continue;
    typeCounts[ext] = (typeCounts[ext] ?? 0) + 1;
  }

  var filtered = switch (filter) {
    CourseFileFilter.all => files,
    CourseFileFilter.unread => files.where((file) => file.isNew).toList(),
    CourseFileFilter.favorite =>
      files.where((file) => favoriteKeys.contains(file.id)).toList(),
    CourseFileFilter.downloaded =>
      files.where((file) => file.localDownloadState == 'downloaded').toList(),
  };

  if (typeFilter != null && typeFilter.isNotEmpty) {
    filtered = filtered
        .where(
          (file) =>
              FileTypeUtils.extractExt(file.title, file.fileType) == typeFilter,
        )
        .toList();
  }

  return CourseFilesPresentation(
    filteredFiles: filtered,
    typeCounts: typeCounts,
  );
}

final courseHomeworksProvider =
    StreamProvider.family<List<db.Homework>, String>((ref, courseId) {
      final database = ref.watch(databaseProvider);
      return database.watchHomeworksByCourse(courseId).map((homeworks) {
        homeworks.sort((a, b) => b.deadline.compareTo(a.deadline));
        return homeworks;
      });
    });
