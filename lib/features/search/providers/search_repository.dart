import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/colors.dart';
import '../../../core/database/app_state_keys.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/files/file_bookmark_repository.dart';
import '../../../core/providers/providers.dart';
import 'search_models.dart';

class SearchRepository {
  const SearchRepository(this._ref);

  final Ref _ref;

  db.AppDatabase get _database => _ref.read(databaseProvider);
  FileBookmarkRepository get _bookmarks =>
      _ref.read(fileBookmarkRepositoryProvider);

  Future<List<SearchResult>> search({
    required String semesterId,
    required String query,
  }) async {
    final coursesFuture = _database.getCoursesBySemester(semesterId);
    final courseMatchesFuture = _database.searchCoursesBySemester(
      semesterId,
      query,
    );
    final notificationMatchesFuture = _database.searchNotificationsBySemester(
      semesterId,
      query,
    );
    final homeworkMatchesFuture = _database.searchHomeworksBySemester(
      semesterId,
      query,
    );
    final fileMatchesFuture = _database.searchFilesBySemester(
      semesterId,
      query,
    );
    final favoriteKeysFuture = _bookmarks.watchKeys().first;

    final courses = await coursesFuture;
    final courseMap = {for (final course in courses) course.id: course.name};
    if (courseMap.isEmpty) {
      return const <SearchResult>[];
    }

    final courseMatches = await courseMatchesFuture;

    final results = <SearchResult>[
      ...courseMatches.map(
        (course) => SearchResult(
          category: SearchCategory.course,
          id: course.id,
          courseId: course.id,
          courseName: course.name,
          title: course.name,
          subtitle: course.teacherName,
          icon: Icons.school_rounded,
          accentColor: AppColors.primary,
        ),
      ),
    ];

    final notificationMatches = await notificationMatchesFuture;
    results.addAll(
      notificationMatches.map(
        (notification) => SearchResult(
          category: SearchCategory.notification,
          id: notification.id,
          courseId: notification.courseId,
          courseName: courseMap[notification.courseId] ?? '',
          title: notification.title,
          subtitle: courseMap[notification.courseId] ?? '',
          icon: Icons.notifications_rounded,
          accentColor: AppColors.info,
        ),
      ),
    );

    final homeworkMatches = await homeworkMatchesFuture;
    results.addAll(
      homeworkMatches.map(
        (homework) => SearchResult(
          category: SearchCategory.homework,
          id: homework.id,
          courseId: homework.courseId,
          courseName: courseMap[homework.courseId] ?? '',
          title: homework.title,
          subtitle: courseMap[homework.courseId] ?? '',
          icon: Icons.assignment_rounded,
          accentColor: AppColors.warning,
        ),
      ),
    );

    final fileMatches = await fileMatchesFuture;
    final favoriteKeys = await favoriteKeysFuture;
    results.addAll(
      fileMatches.map(
        (file) => SearchResult(
          category: SearchCategory.file,
          id: file.id,
          courseId: file.courseId,
          courseName: courseMap[file.courseId] ?? '',
          title: file.title,
          subtitle: '${courseMap[file.courseId] ?? ''} · ${file.size}',
          icon: Icons.insert_drive_file_rounded,
          accentColor: const Color(0xFF8B5CF6),
          isFavorite: favoriteKeys.contains(file.id),
        ),
      ),
    );

    return results;
  }

  Future<List<String>> loadRecentSearches() async {
    final raw = await _database.getState(AppStateKeys.recentSearches);
    if (raw == null || raw.isEmpty) {
      return const <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        await _database.setState(AppStateKeys.recentSearches, '[]');
        return const <String>[];
      }

      return decoded.whereType<String>().toList(growable: false);
    } catch (_) {
      await _database.setState(AppStateKeys.recentSearches, '[]');
      return const <String>[];
    }
  }

  Future<List<String>> addRecentSearch(String query) async {
    final next = await loadRecentSearches();
    next.remove(query);
    next.insert(0, query);
    if (next.length > 10) {
      next.removeRange(10, next.length);
    }
    await _database.setState(AppStateKeys.recentSearches, jsonEncode(next));
    return next;
  }

  Future<void> clearRecentSearches() {
    return _database.setState(AppStateKeys.recentSearches, '[]');
  }
}

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref);
});
