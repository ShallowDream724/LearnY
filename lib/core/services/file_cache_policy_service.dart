import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_state_keys.dart';
import '../database/database.dart' as db;
import '../files/cached_asset_repository.dart';
import '../files/file_repository.dart';
import '../providers/app_providers.dart';
import '../providers/preferences_providers.dart';

class CachePolicyResult {
  const CachePolicyResult({
    this.limitBytes,
    this.totalBytes = 0,
    this.evictedAssetKeys = const [],
    this.repairedAssetKeys = const [],
    this.evictedBytes = 0,
    this.repairedBytes = 0,
  });

  final int? limitBytes;
  final int totalBytes;
  final List<String> evictedAssetKeys;
  final List<String> repairedAssetKeys;
  final int evictedBytes;
  final int repairedBytes;

  bool get limitApplied => limitBytes != null;
  bool get hasChanges =>
      evictedAssetKeys.isNotEmpty || repairedAssetKeys.isNotEmpty;
}

class FileCachePolicyService {
  FileCachePolicyService(this._ref);

  final Ref _ref;

  Future<CachePolicyResult> enforceLimit({
    String? protectedAssetKey,
    int? overrideLimitBytes,
  }) async {
    final limitBytes = await _resolveLimitBytes(
      overrideLimitBytes: overrideLimitBytes,
    );
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final fileRepository = _ref.read(fileRepositoryProvider);

    final assets = await cachedAssetRepository.getAllAssets();
    final repairedAssetKeys = <String>[];
    final candidates = <_CachedAssetCandidate>[];
    var repairedBytes = 0;
    var totalBytes = 0;

    for (final asset in assets) {
      final file = File(asset.localPath);
      if (!await file.exists()) {
        repairedAssetKeys.add(asset.assetKey);
        if (asset.fileSizeBytes > 0) {
          repairedBytes += asset.fileSizeBytes;
        }
        await _resetPersistedFileState(fileRepository, asset.persistedFileId);
        await cachedAssetRepository.deleteAsset(asset.assetKey);
        continue;
      }

      final fileSize = asset.fileSizeBytes > 0
          ? asset.fileSizeBytes
          : await file.length();
      totalBytes += fileSize;
      candidates.add(
        _CachedAssetCandidate(
          asset: asset,
          file: file,
          fileSizeBytes: fileSize,
          evictionKey: _evictionKey(asset),
        ),
      );
    }

    if (limitBytes == null || limitBytes <= 0 || totalBytes <= limitBytes) {
      return CachePolicyResult(
        limitBytes: limitBytes,
        totalBytes: totalBytes,
        repairedAssetKeys: repairedAssetKeys,
        repairedBytes: repairedBytes,
      );
    }

    candidates.sort((a, b) => a.evictionKey.compareTo(b.evictionKey));
    final evictedAssetKeys = <String>[];
    var evictedBytes = 0;

    for (final candidate in candidates) {
      if (totalBytes <= limitBytes) {
        break;
      }
      if (candidate.asset.assetKey == protectedAssetKey) {
        continue;
      }

      if (await candidate.file.exists()) {
        await candidate.file.delete();
      }
      await cachedAssetRepository.deleteAsset(candidate.asset.assetKey);
      await _resetPersistedFileState(
        fileRepository,
        candidate.asset.persistedFileId,
      );
      totalBytes -= candidate.fileSizeBytes;
      evictedBytes += candidate.fileSizeBytes;
      evictedAssetKeys.add(candidate.asset.assetKey);
    }

    return CachePolicyResult(
      limitBytes: limitBytes,
      totalBytes: totalBytes,
      evictedAssetKeys: evictedAssetKeys,
      repairedAssetKeys: repairedAssetKeys,
      evictedBytes: evictedBytes,
      repairedBytes: repairedBytes,
    );
  }

  Future<int?> _resolveLimitBytes({int? overrideLimitBytes}) async {
    if (overrideLimitBytes != null && overrideLimitBytes > 0) {
      return overrideLimitBytes;
    }

    final inMemoryLimit = _ref.read(fileCacheLimitBytesProvider);
    if (inMemoryLimit != null && inMemoryLimit > 0) {
      return inMemoryLimit;
    }

    final saved = await _ref
        .read(databaseProvider)
        .getState(AppStateKeys.fileCacheLimitMb);
    if (saved == null || saved.isEmpty) {
      return null;
    }

    final limitMb = int.tryParse(saved);
    if (limitMb == null || limitMb <= 0) {
      return null;
    }

    return limitMb * 1024 * 1024;
  }

  DateTime _evictionKey(db.CachedAsset asset) {
    final raw = asset.lastAccessedAt ?? asset.updatedAt;
    return DateTime.tryParse(raw) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  Future<void> _resetPersistedFileState(
    FileRepository fileRepository,
    String? persistedFileId,
  ) async {
    if (persistedFileId == null || persistedFileId.isEmpty) {
      return;
    }

    final file = await fileRepository.getFileById(persistedFileId);
    if (file == null || file.localDownloadState == 'none') {
      return;
    }

    await fileRepository.updateDownloadState(file.id, 'none', null);
  }
}

final fileCachePolicyServiceProvider = Provider<FileCachePolicyService>((ref) {
  return FileCachePolicyService(ref);
});

class _CachedAssetCandidate {
  const _CachedAssetCandidate({
    required this.asset,
    required this.file,
    required this.fileSizeBytes,
    required this.evictionKey,
  });

  final db.CachedAsset asset;
  final File file;
  final int fileSizeBytes;
  final DateTime evictionKey;
}
