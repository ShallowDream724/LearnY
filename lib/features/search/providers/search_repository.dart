import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_state_keys.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/files/cached_asset_repository.dart';
import '../../../core/files/file_bookmark_repository.dart';
import '../../../core/providers/providers.dart';
import 'search_engine.dart';
import 'search_models.dart';
import 'search_result_factory.dart';

class SearchRepository {
  const SearchRepository(this._ref);

  final Ref _ref;

  db.AppDatabase get _database => _ref.read(databaseProvider);
  FileBookmarkRepository get _bookmarks =>
      _ref.read(fileBookmarkRepositoryProvider);
  CachedAssetRepository get _cachedAssets =>
      _ref.read(cachedAssetRepositoryProvider);

  static const SearchEngine _engine = SearchEngine();

  Future<List<SearchResult>> search({
    required String semesterId,
    required String query,
  }) async {
    final coursesFuture = _database.getCoursesBySemester(semesterId);
    final notificationsFuture = _database.getNotificationsBySemester(semesterId);
    final homeworksFuture = _database.getHomeworksBySemester(semesterId);
    final filesFuture = _database.getFilesBySemester(semesterId);
    final bookmarkKeysFuture = _bookmarks.watchKeys().first;
    final cachedAssetsFuture = _cachedAssets.getAllAssets();

    final courses = await coursesFuture;
    if (courses.isEmpty) {
      return const <SearchResult>[];
    }

    final courseMap = {for (final course in courses) course.id: course.name};
    final bookmarkKeys = await bookmarkKeysFuture;
    final cachedAssetKeys = (await cachedAssetsFuture)
        .where((asset) => courseMap.containsKey(asset.courseId))
        .map((asset) => asset.assetKey)
        .toSet();
    final notifications = await notificationsFuture;
    final homeworks = await homeworksFuture;
    final files = await filesFuture;

    final documents = <SearchDocument>[
      ...courses.map(buildCourseSearchDocument),
      for (final notification in notifications) ...[
        buildNotificationSearchDocument(
          notification,
          courseName: courseMap[notification.courseId] ?? '',
        ),
        ...[
          buildNotificationAttachmentSearchDocument(
            notification,
            courseName: courseMap[notification.courseId] ?? '',
            bookmarkKeys: bookmarkKeys,
            cachedAssetKeys: cachedAssetKeys,
          ),
        ].whereType<SearchDocument>(),
      ],
      for (final homework in homeworks) ...[
        buildHomeworkSearchDocument(
          homework,
          courseName: courseMap[homework.courseId] ?? '',
        ),
        ...buildHomeworkAttachmentSearchDocuments(
          homework,
          courseName: courseMap[homework.courseId] ?? '',
          bookmarkKeys: bookmarkKeys,
          cachedAssetKeys: cachedAssetKeys,
        ),
      ],
      ...files.map(
        (file) => buildCourseFileSearchDocument(
          file,
          courseName: courseMap[file.courseId] ?? '',
          bookmarkKeys: bookmarkKeys,
          cachedAssetKeys: cachedAssetKeys,
        ),
      ),
    ];

    return _engine.search(documents: documents, query: query);
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
