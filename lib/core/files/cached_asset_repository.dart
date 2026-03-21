import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart' as db;
import '../providers/app_providers.dart';

abstract class CachedAssetRepository {
  Stream<db.CachedAsset?> watchAsset(String assetKey);
  Stream<List<db.CachedAsset>> watchAllAssets();
  Future<db.CachedAsset?> getAsset(String assetKey);
  Future<List<db.CachedAsset>> getAllAssets();

  Future<void> saveDownloadedAsset({
    required String assetKey,
    required String courseId,
    required String title,
    required String fileType,
    required String localPath,
    required int fileSizeBytes,
    String? persistedFileId,
    String sourceKind = 'generic',
    String? routeDataJson,
    String? accessedAt,
  });

  Future<void> touchAsset(String assetKey, {String? accessedAt});
  Future<void> deleteAsset(String assetKey);
  Future<void> deleteAssetsByCourse(String courseId);
  Future<void> clearAll();
}

final cachedAssetRepositoryProvider = Provider<CachedAssetRepository>((ref) {
  return DriftCachedAssetRepository(ref.watch(databaseProvider));
});

final cachedAssetProvider = StreamProvider.family<db.CachedAsset?, String>((
  ref,
  assetKey,
) {
  final repository = ref.watch(cachedAssetRepositoryProvider);
  return repository.watchAsset(assetKey);
});

class DriftCachedAssetRepository implements CachedAssetRepository {
  DriftCachedAssetRepository(this._database);

  final db.AppDatabase _database;

  @override
  Stream<db.CachedAsset?> watchAsset(String assetKey) =>
      _database.watchCachedAsset(assetKey);

  @override
  Stream<List<db.CachedAsset>> watchAllAssets() =>
      _database.watchAllCachedAssets();

  @override
  Future<db.CachedAsset?> getAsset(String assetKey) =>
      _database.getCachedAsset(assetKey);

  @override
  Future<List<db.CachedAsset>> getAllAssets() => _database.getAllCachedAssets();

  @override
  Future<void> saveDownloadedAsset({
    required String assetKey,
    required String courseId,
    required String title,
    required String fileType,
    required String localPath,
    required int fileSizeBytes,
    String? persistedFileId,
    String sourceKind = 'generic',
    String? routeDataJson,
    String? accessedAt,
  }) {
    final timestamp = accessedAt ?? DateTime.now().toIso8601String();
    return _database.upsertCachedAsset(
      db.CachedAssetsCompanion.insert(
        assetKey: assetKey,
        courseId: courseId,
        title: title,
        fileType: Value(fileType),
        localPath: localPath,
        fileSizeBytes: Value(fileSizeBytes),
        lastAccessedAt: Value(timestamp),
        updatedAt: timestamp,
        persistedFileId: Value(persistedFileId),
        sourceKind: Value(sourceKind),
        routeDataJson: Value(routeDataJson),
      ),
    );
  }

  @override
  Future<void> touchAsset(String assetKey, {String? accessedAt}) {
    final timestamp = accessedAt ?? DateTime.now().toIso8601String();
    return _database.touchCachedAsset(assetKey, timestamp);
  }

  @override
  Future<void> deleteAsset(String assetKey) =>
      _database.deleteCachedAsset(assetKey);

  @override
  Future<void> deleteAssetsByCourse(String courseId) =>
      _database.deleteCachedAssetsByCourse(courseId);

  @override
  Future<void> clearAll() => _database.clearCachedAssets();
}
