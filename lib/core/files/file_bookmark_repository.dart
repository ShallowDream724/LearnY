import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart' as db;
import '../providers/app_providers.dart';

abstract class FileBookmarkRepository {
  Stream<List<db.FileBookmark>> watchAll();
  Stream<Set<String>> watchKeys();
  Stream<bool> watchIsBookmarked(String assetKey);

  Future<bool> isBookmarked(String assetKey);
  Future<void> save(String assetKey, {required String courseName});
  Future<void> remove(String assetKey);
}

final fileBookmarkRepositoryProvider = Provider<FileBookmarkRepository>((ref) {
  return DriftFileBookmarkRepository(ref.watch(databaseProvider));
});

class DriftFileBookmarkRepository implements FileBookmarkRepository {
  DriftFileBookmarkRepository(this._database);

  final db.AppDatabase _database;

  @override
  Stream<List<db.FileBookmark>> watchAll() => _database.watchAllFileBookmarks();

  @override
  Stream<Set<String>> watchKeys() =>
      watchAll().map((bookmarks) => bookmarks.map((b) => b.assetKey).toSet());

  @override
  Stream<bool> watchIsBookmarked(String assetKey) =>
      _database.watchIsFileBookmarked(assetKey);

  @override
  Future<bool> isBookmarked(String assetKey) =>
      _database.isFileBookmarked(assetKey);

  @override
  Future<void> save(String assetKey, {required String courseName}) {
    return _database.upsertFileBookmark(
      db.FileBookmarksCompanion.insert(
        assetKey: assetKey,
        courseName: Value(courseName),
        createdAt: DateTime.now().toIso8601String(),
      ),
    );
  }

  @override
  Future<void> remove(String assetKey) =>
      _database.deleteFileBookmark(assetKey);
}
