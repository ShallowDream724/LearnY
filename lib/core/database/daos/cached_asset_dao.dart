part of '../database.dart';

extension CachedAssetDao on AppDatabase {
  Future<void> upsertCachedAsset(CachedAssetsCompanion entry) =>
      into(cachedAssets).insertOnConflictUpdate(entry);

  Future<CachedAsset?> getCachedAsset(String assetKey) => (select(
    cachedAssets,
  )..where((t) => t.assetKey.equals(assetKey))).getSingleOrNull();

  Stream<CachedAsset?> watchCachedAsset(String assetKey) => (select(
    cachedAssets,
  )..where((t) => t.assetKey.equals(assetKey))).watchSingleOrNull();

  Stream<List<CachedAsset>> watchAllCachedAssets() =>
      (select(cachedAssets)..orderBy([
            (t) => OrderingTerm.desc(t.lastAccessedAt),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
          .watch();

  Future<List<CachedAsset>> getAllCachedAssets() =>
      (select(cachedAssets)..orderBy([
            (t) => OrderingTerm.desc(t.lastAccessedAt),
            (t) => OrderingTerm.desc(t.updatedAt),
          ]))
          .get();

  Future<void> deleteCachedAsset(String assetKey) => transaction(() async {
    await deleteFileBookmark(assetKey);
    await (delete(
      cachedAssets,
    )..where((t) => t.assetKey.equals(assetKey))).go();
  });

  Future<void> deleteCachedAssetsByCourse(String courseId) =>
      transaction(() async {
        await deleteFileBookmarksByCourse(courseId);
        await (delete(
          cachedAssets,
        )..where((t) => t.courseId.equals(courseId))).go();
      });

  Future<void> clearCachedAssets() => transaction(() async {
    await clearFileBookmarks();
    await delete(cachedAssets).go();
  });

  Future<void> touchCachedAsset(String assetKey, String accessedAt) =>
      (update(cachedAssets)..where((t) => t.assetKey.equals(assetKey))).write(
        CachedAssetsCompanion(
          lastAccessedAt: Value(accessedAt),
          updatedAt: Value(accessedAt),
        ),
      );

  Future<void> updateCachedAssetLocalPath(String assetKey, String localPath) =>
      (update(cachedAssets)..where((t) => t.assetKey.equals(assetKey))).write(
        CachedAssetsCompanion(localPath: Value(localPath)),
      );

  Future<void> rewriteCachedAssetPathPrefix(
    String fromPrefix,
    String toPrefix,
  ) {
    return customUpdate(
      '''
      UPDATE cached_assets
      SET local_path = REPLACE(local_path, ?, ?)
      WHERE local_path LIKE ?
      ''',
      variables: [
        Variable<String>(fromPrefix),
        Variable<String>(toPrefix),
        Variable<String>('$fromPrefix%'),
      ],
      updates: {cachedAssets},
    );
  }
}
