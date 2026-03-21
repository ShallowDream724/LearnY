import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/database/database.dart';
import '../../../core/files/file_bookmark_repository.dart';
import '../../../core/providers/providers.dart';
import '../../search/providers/search_models.dart';

class CourseSearchRepository {
  const CourseSearchRepository(this._ref);

  final Ref _ref;

  Future<List<SearchResult>> search({
    required String courseId,
    required String courseName,
    required String query,
  }) async {
    final database = _ref.read(databaseProvider);
    final bookmarkKeys = await _ref
        .read(fileBookmarkRepositoryProvider)
        .watchKeys()
        .first;

    final notificationsFuture = database.searchNotificationsByCourseIds([
      courseId,
    ], query);
    final homeworksFuture = database.searchHomeworksByCourseIds([
      courseId,
    ], query);
    final filesFuture = database.searchFilesByCourseIds([courseId], query);

    final notifications = await notificationsFuture;
    final homeworks = await homeworksFuture;
    final files = await filesFuture;

    return [
      ...notifications.map(
        (notification) => SearchResult(
          category: SearchCategory.notification,
          id: notification.id,
          courseId: courseId,
          courseName: courseName,
          title: notification.title,
          subtitle: notification.publisher.isEmpty
              ? courseName
              : notification.publisher,
          icon: Icons.notifications_rounded,
          accentColor: AppColors.info,
        ),
      ),
      ...homeworks.map(
        (homework) => SearchResult(
          category: SearchCategory.homework,
          id: homework.id,
          courseId: courseId,
          courseName: courseName,
          title: homework.title,
          subtitle: courseName,
          icon: Icons.assignment_rounded,
          accentColor: AppColors.warning,
        ),
      ),
      ...files.map(
        (file) => SearchResult(
          category: SearchCategory.file,
          id: file.id,
          courseId: courseId,
          courseName: courseName,
          title: file.title,
          subtitle: file.size.isEmpty
              ? courseName
              : '$courseName · ${file.size}',
          icon: Icons.insert_drive_file_rounded,
          accentColor: const Color(0xFF8B5CF6),
          isFavorite: bookmarkKeys.contains(file.id),
        ),
      ),
    ];
  }
}

final courseSearchRepositoryProvider = Provider<CourseSearchRepository>((ref) {
  return CourseSearchRepository(ref);
});
