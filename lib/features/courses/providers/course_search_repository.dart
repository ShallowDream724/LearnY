import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/files/cached_asset_repository.dart';
import '../../../core/files/file_bookmark_repository.dart';
import '../../../core/providers/providers.dart';
import '../../search/providers/search_engine.dart';
import '../../search/providers/search_models.dart';
import '../../search/providers/search_result_factory.dart';

class CourseSearchRepository {
  const CourseSearchRepository(this._ref);

  final Ref _ref;

  static const SearchEngine _engine = SearchEngine();

  Future<List<SearchResult>> search({
    required String courseId,
    required String courseName,
    required String query,
  }) async {
    final db.AppDatabase database = _ref.read(databaseProvider);
    final bookmarkKeysFuture = _ref
        .read(fileBookmarkRepositoryProvider)
        .watchKeys()
        .first;
    final cachedAssetsFuture = _ref
        .read(cachedAssetRepositoryProvider)
        .getAllAssets();
    final notificationsFuture = database.getNotificationsByCourse(courseId);
    final homeworksFuture = database.getHomeworksByCourse(courseId);
    final filesFuture = database.getFilesByCourse(courseId);

    final bookmarkKeys = await bookmarkKeysFuture;
    final cachedAssetKeys = (await cachedAssetsFuture)
        .where((asset) => asset.courseId == courseId)
        .map((asset) => asset.assetKey)
        .toSet();
    final notifications = await notificationsFuture;
    final homeworks = await homeworksFuture;
    final files = await filesFuture;

    final documents = <SearchDocument>[
      for (final notification in notifications) ...[
        buildNotificationSearchDocument(
          notification,
          courseName: courseName,
        ),
        ...[
          buildNotificationAttachmentSearchDocument(
            notification,
            courseName: courseName,
            bookmarkKeys: bookmarkKeys,
            cachedAssetKeys: cachedAssetKeys,
          ),
        ].whereType<SearchDocument>(),
      ],
      for (final homework in homeworks) ...[
        buildHomeworkSearchDocument(homework, courseName: courseName),
        ...buildHomeworkAttachmentSearchDocuments(
          homework,
          courseName: courseName,
          bookmarkKeys: bookmarkKeys,
          cachedAssetKeys: cachedAssetKeys,
        ),
      ],
      ...files.map(
        (file) => buildCourseFileSearchDocument(
          file,
          courseName: courseName,
          bookmarkKeys: bookmarkKeys,
          cachedAssetKeys: cachedAssetKeys,
        ),
      ),
    ];

    return _engine.search(documents: documents, query: query);
  }
}

final courseSearchRepositoryProvider = Provider<CourseSearchRepository>((ref) {
  return CourseSearchRepository(ref);
});
