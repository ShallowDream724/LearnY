/// File cache service — manages disk storage for downloaded files.
///
/// Responsibilities:
/// 1. Calculate cache sizes (total, per-course, per-file)
/// 2. Clear caches (total, per-course, per-file)
/// 3. Enumerate cached files with disk size
/// 4. Integrity checks (DB ↔ disk sync)
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database.dart' as db;
import '../files/cached_asset_repository.dart';
import '../files/file_models.dart';
import '../files/file_repository.dart';
import '../providers/providers.dart';
import 'file_cache_policy_service.dart';
import 'file_download_service.dart';

// ---------------------------------------------------------------------------
//  Data model
// ---------------------------------------------------------------------------

class CourseCacheInfo {
  final String courseId;
  final String courseName;
  final int fileCount;
  final int totalBytes;

  const CourseCacheInfo({
    required this.courseId,
    required this.courseName,
    required this.fileCount,
    required this.totalBytes,
  });
}

class FileCacheSnapshot {
  const FileCacheSnapshot({
    required this.files,
    required this.totalSizeBytes,
    this.policyResult,
  });

  final List<CachedAssetListItem> files;
  final int totalSizeBytes;
  final CachePolicyResult? policyResult;
}

// ---------------------------------------------------------------------------
//  Service
// ---------------------------------------------------------------------------

class FileCacheService {
  final Ref _ref;

  FileCacheService(this._ref);

  Future<Directory> get _rootDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/learnx_files');
  }

  // ─── Size queries ───

  Future<int> getTotalCacheSize() async {
    final root = await _rootDir;
    if (!await root.exists()) return 0;
    return _directorySize(root);
  }

  Future<int> getCourseCacheSize(String courseId) async {
    final root = await _rootDir;
    final courseDir = Directory('${root.path}/$courseId');
    if (!await courseDir.exists()) return 0;
    return _directorySize(courseDir);
  }

  Future<List<CourseCacheInfo>> getCacheByCourse() async {
    await _repairCachedAssetEntries();
    await _syncCourseFileDownloadStates();

    final semesterId = _ref.read(currentSemesterIdProvider);
    final fileRepository = _ref.read(fileRepositoryProvider);
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final courseNames = await fileRepository.getCourseNameMap(semesterId);
    final aggregates = <String, ({int fileCount, int totalBytes})>{};

    for (final asset in await cachedAssetRepository.getAllAssets()) {
      final file = File(asset.localPath);
      if (!await file.exists()) {
        continue;
      }

      final stat = await file.stat();
      final current = aggregates[asset.courseId];
      if (current == null) {
        aggregates[asset.courseId] = (fileCount: 1, totalBytes: stat.size);
      } else {
        aggregates[asset.courseId] = (
          fileCount: current.fileCount + 1,
          totalBytes: current.totalBytes + stat.size,
        );
      }
    }

    final result = aggregates.entries
        .map(
          (entry) => CourseCacheInfo(
            courseId: entry.key,
            courseName: courseNames[entry.key] ?? entry.key,
            fileCount: entry.value.fileCount,
            totalBytes: entry.value.totalBytes,
          ),
        )
        .toList();

    result.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return result;
  }

  Future<List<CachedAssetListItem>> getCachedFiles() async {
    await _repairCachedAssetEntries();
    await _syncCourseFileDownloadStates();
    await _repairCachedAssetRoutes();

    final semesterId = _ref.read(currentSemesterIdProvider);
    final courseNames = await _ref
        .read(fileRepositoryProvider)
        .getCourseNameMap(semesterId);
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final result = <CachedAssetListItem>[];

    for (final asset in await cachedAssetRepository.getAllAssets()) {
      final file = File(asset.localPath);
      if (!await file.exists()) {
        continue;
      }

      final stat = await file.stat();
      result.add(
        CachedAssetListItem.fromCachedAsset(
          asset.copyWith(fileSizeBytes: stat.size),
          courseName: courseNames[asset.courseId] ?? '',
        ),
      );
    }

    return result;
  }

  Future<CachePolicyResult> applyCachePolicy({
    String? protectedAssetKey,
    int? overrideLimitBytes,
  }) async {
    final result = await _ref
        .read(fileCachePolicyServiceProvider)
        .enforceLimit(
          protectedAssetKey: protectedAssetKey,
          overrideLimitBytes: overrideLimitBytes,
        );

    final clearedKeys = {
      ...result.evictedAssetKeys,
      ...result.repairedAssetKeys,
    };
    if (clearedKeys.isNotEmpty) {
      _ref.read(fileDownloadProvider.notifier).clearTrackedStates(clearedKeys);
    }

    return result;
  }

  Future<FileCacheSnapshot> loadSnapshot({
    bool applyPolicy = false,
    String? protectedAssetKey,
    int? overrideLimitBytes,
  }) async {
    final policyResult = applyPolicy
        ? await applyCachePolicy(
            protectedAssetKey: protectedAssetKey,
            overrideLimitBytes: overrideLimitBytes,
          )
        : null;
    final files = await getCachedFiles();
    final totalSizeBytes = files.fold<int>(
      0,
      (total, file) => total + file.diskSizeBytes,
    );
    return FileCacheSnapshot(
      files: files,
      totalSizeBytes: totalSizeBytes,
      policyResult: policyResult,
    );
  }

  // ─── Cleanup ───

  Future<void> clearAllCache() async {
    final root = await _rootDir;
    if (await root.exists()) {
      await root.delete(recursive: true);
    }

    final fileRepository = _ref.read(fileRepositoryProvider);
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final allFiles = await fileRepository.getAllFiles();
    for (final file in allFiles) {
      if (file.localDownloadState != 'none') {
        await fileRepository.updateDownloadState(file.id, 'none', null);
      }
    }

    await cachedAssetRepository.clearAll();
    _ref.read(fileDownloadProvider.notifier).clearAll();
  }

  Future<void> clearCourseCache(String courseId) async {
    final root = await _rootDir;
    final courseDir = Directory('${root.path}/$courseId');
    if (await courseDir.exists()) {
      await courseDir.delete(recursive: true);
    }

    final fileRepository = _ref.read(fileRepositoryProvider);
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final files = await fileRepository.getFilesByCourse(courseId);
    final assetKeys = (await cachedAssetRepository.getAllAssets())
        .where((asset) => asset.courseId == courseId)
        .map((asset) => asset.assetKey)
        .toList();

    for (final file in files) {
      if (file.localDownloadState != 'none') {
        await fileRepository.updateDownloadState(file.id, 'none', null);
      }
    }

    await cachedAssetRepository.deleteAssetsByCourse(courseId);
    _ref.read(fileDownloadProvider.notifier).clearTrackedStates({
      ...files.map((file) => file.id),
      ...assetKeys,
    });
  }

  Future<void> clearFile(String assetKey) async {
    await _ref.read(fileDownloadProvider.notifier).deleteFile(assetKey);
  }

  // ─── Integrity ───

  Future<int> verifyIntegrity() async {
    final repairedAssets = await _repairCachedAssetEntries();
    final repairedFiles = await _syncCourseFileDownloadStates();
    return repairedAssets + repairedFiles;
  }

  // ─── Helpers ───

  Future<int> _repairCachedAssetEntries() async {
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    int repaired = 0;
    final repairedKeys = <String>[];

    for (final asset in await cachedAssetRepository.getAllAssets()) {
      final file = File(asset.localPath);
      if (await file.exists()) {
        continue;
      }

      repaired++;
      repairedKeys.add(asset.assetKey);
      await _resetPersistedFileState(asset.persistedFileId);
      await cachedAssetRepository.deleteAsset(asset.assetKey);
    }

    if (repairedKeys.isNotEmpty) {
      _ref.read(fileDownloadProvider.notifier).clearTrackedStates(repairedKeys);
    }

    return repaired;
  }

  Future<int> _syncCourseFileDownloadStates() async {
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final fileRepository = _ref.read(fileRepositoryProvider);
    final semesterId = _ref.read(currentSemesterIdProvider);
    final courseNames = await fileRepository.getCourseNameMap(semesterId);
    final cachedKeys = {
      for (final asset in await cachedAssetRepository.getAllAssets())
        asset.assetKey,
    };
    final allFiles = await fileRepository.getAllFiles();
    int repaired = 0;
    final repairedKeys = <String>[];

    for (final file in allFiles) {
      if (file.localDownloadState != 'downloaded' ||
          file.localFilePath == null) {
        continue;
      }

      final localFile = File(file.localFilePath!);
      if (!await localFile.exists()) {
        await fileRepository.updateDownloadState(file.id, 'none', null);
        await cachedAssetRepository.deleteAsset(file.id);
        repaired++;
        repairedKeys.add(file.id);
        continue;
      }

      if (cachedKeys.contains(file.id)) {
        continue;
      }

      final stat = await localFile.stat();
      await cachedAssetRepository.saveDownloadedAsset(
        assetKey: file.id,
        courseId: file.courseId,
        title: file.title,
        fileType: file.fileType,
        localPath: localFile.path,
        fileSizeBytes: stat.size,
        persistedFileId: file.id,
        sourceKind: 'courseFile',
        routeDataJson: FileDetailRouteData.courseFile(
          fileId: file.id,
          courseId: file.courseId,
          courseName: courseNames[file.courseId] ?? '',
        ).toJsonString(),
      );
    }

    if (repairedKeys.isNotEmpty) {
      _ref.read(fileDownloadProvider.notifier).clearTrackedStates(repairedKeys);
    }

    return repaired;
  }

  Future<int> _repairCachedAssetRoutes() async {
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final semesterId = _ref.read(currentSemesterIdProvider);
    final fileRepository = _ref.read(fileRepositoryProvider);
    final database = _ref.read(databaseProvider);
    final courseNames = await fileRepository.getCourseNameMap(semesterId);
    final notificationCache = <String, Future<List<db.Notification>>>{};
    final homeworkCache = <String, Future<List<db.Homework>>>{};
    int repaired = 0;

    for (final asset in await cachedAssetRepository.getAllAssets()) {
      if (asset.routeDataJson != null && asset.routeDataJson!.isNotEmpty) {
        continue;
      }

      final courseName = courseNames[asset.courseId] ?? '';
      final routeData =
          _routeDataForPersistedFile(asset, courseName: courseName) ??
          await _resolveAttachmentRouteData(
            asset,
            courseName: courseName,
            database: database,
            notificationCache: notificationCache,
            homeworkCache: homeworkCache,
          );
      if (routeData == null) {
        continue;
      }

      repaired++;
      await cachedAssetRepository.saveDownloadedAsset(
        assetKey: asset.assetKey,
        courseId: asset.courseId,
        title: asset.title,
        fileType: asset.fileType,
        localPath: asset.localPath,
        fileSizeBytes: asset.fileSizeBytes,
        persistedFileId: asset.persistedFileId,
        sourceKind: asset.sourceKind,
        routeDataJson: routeData.toJsonString(),
        accessedAt: asset.lastAccessedAt ?? asset.updatedAt,
      );
    }

    return repaired;
  }

  Future<void> _resetPersistedFileState(String? persistedFileId) async {
    if (persistedFileId == null || persistedFileId.isEmpty) {
      return;
    }

    final fileRepository = _ref.read(fileRepositoryProvider);
    final file = await fileRepository.getFileById(persistedFileId);
    if (file == null || file.localDownloadState == 'none') {
      return;
    }

    await fileRepository.updateDownloadState(file.id, 'none', null);
  }

  Future<int> _directorySize(Directory dir) async {
    int total = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (_) {}
    return total;
  }

  Future<FileDetailRouteData?> _resolveAttachmentRouteData(
    db.CachedAsset asset, {
    required String courseName,
    required db.AppDatabase database,
    required Map<String, Future<List<db.Notification>>> notificationCache,
    required Map<String, Future<List<db.Homework>>> homeworkCache,
  }) async {
    if (asset.sourceKind == FileAttachmentKind.notification.name) {
      final notifications = await notificationCache.putIfAbsent(
        asset.courseId,
        () => database.getNotificationsByCourse(asset.courseId),
      );
      for (final notification in notifications) {
        final routeData = _matchAttachmentRouteData(
          notification.attachmentJson,
          asset: asset,
          courseName: courseName,
        );
        if (routeData != null) {
          return routeData;
        }
      }
      return null;
    }

    final homeworks = await homeworkCache.putIfAbsent(
      asset.courseId,
      () => database.getHomeworksByCourse(asset.courseId),
    );
    for (final homework in homeworks) {
      final candidateJsons = switch (asset.sourceKind) {
        'homeworkAttachment' => [homework.attachmentJson],
        'homeworkAnswer' => [homework.answerAttachmentJson],
        'homeworkSubmitted' => [homework.submittedAttachmentJson],
        'homeworkGrade' => [homework.gradeAttachmentJson],
        _ => [
          homework.attachmentJson,
          homework.answerAttachmentJson,
          homework.submittedAttachmentJson,
          homework.gradeAttachmentJson,
        ],
      };
      for (final rawJson in candidateJsons) {
        final routeData = _matchAttachmentRouteData(
          rawJson,
          asset: asset,
          courseName: courseName,
        );
        if (routeData != null) {
          return routeData;
        }
      }
    }
    return null;
  }

  FileDetailRouteData? _matchAttachmentRouteData(
    String? rawJson, {
    required db.CachedAsset asset,
    required String courseName,
  }) {
    final attachment = FileAttachment.tryParseJsonString(rawJson);
    if (attachment == null) {
      return null;
    }
    if (attachment.cacheKeyForCourse(asset.courseId) != asset.assetKey) {
      return null;
    }
    return FileDetailRouteData.attachment(
      attachment: attachment,
      courseId: asset.courseId,
      courseName: courseName,
    );
  }

  FileDetailRouteData? _routeDataForPersistedFile(
    db.CachedAsset asset, {
    required String courseName,
  }) {
    final persistedFileId = asset.persistedFileId;
    if (persistedFileId == null || persistedFileId.isEmpty) {
      return null;
    }
    return FileDetailRouteData.courseFile(
      fileId: persistedFileId,
      courseId: asset.courseId,
      courseName: courseName,
    );
  }
}

// ---------------------------------------------------------------------------
//  Provider
// ---------------------------------------------------------------------------

final fileCacheServiceProvider = Provider<FileCacheService>((ref) {
  return FileCacheService(ref);
});

final fileCacheSizeProvider = FutureProvider<int>((ref) async {
  ref.watch(fileDownloadProvider);
  final service = ref.read(fileCacheServiceProvider);
  return service.getTotalCacheSize();
});
