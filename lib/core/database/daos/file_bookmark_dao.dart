part of '../database.dart';

extension FileBookmarkDao on AppDatabase {
  Future<void> upsertFileBookmark(FileBookmarksCompanion entry) =>
      into(fileBookmarks).insertOnConflictUpdate(entry);

  Future<void> deleteFileBookmark(String assetKey) =>
      (delete(fileBookmarks)..where((t) => t.assetKey.equals(assetKey))).go();

  Future<void> deleteFileBookmarks(Iterable<String> assetKeys) {
    final keys = assetKeys.toList(growable: false);
    if (keys.isEmpty) {
      return Future.value();
    }
    return (delete(fileBookmarks)..where((t) => t.assetKey.isIn(keys))).go();
  }

  Future<void> deleteFileBookmarksByCourse(String courseId) => customStatement(
    '''
        DELETE FROM file_bookmarks
        WHERE asset_key IN (
          SELECT asset_key FROM cached_assets WHERE course_id = ?
        )
        ''',
    [courseId],
  );

  Future<void> clearFileBookmarks() => delete(fileBookmarks).go();

  Stream<List<FileBookmark>> watchAllFileBookmarks() => (select(
    fileBookmarks,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Stream<bool> watchIsFileBookmarked(String assetKey) =>
      (select(fileBookmarks)..where((t) => t.assetKey.equals(assetKey)))
          .watchSingleOrNull()
          .map((bookmark) => bookmark != null);

  Future<bool> isFileBookmarked(String assetKey) async {
    final bookmark = await (select(
      fileBookmarks,
    )..where((t) => t.assetKey.equals(assetKey))).getSingleOrNull();
    return bookmark != null;
  }
}
