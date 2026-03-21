import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart' as db;
import '../services/file_download_service.dart';
import 'file_models.dart';

class FileAssetRuntime {
  const FileAssetRuntime({
    required this.assetKey,
    required this.status,
    this.progress = 0,
    this.localPath,
    this.errorMessage,
  });

  final String assetKey;
  final DownloadStatus status;
  final double progress;
  final String? localPath;
  final String? errorMessage;

  bool get isDownloaded => status == DownloadStatus.downloaded;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get hasFailure => status == DownloadStatus.failed;
}

class FileAssetRuntimeResolver {
  const FileAssetRuntimeResolver();

  FileAssetRuntime resolveCourseFile(
    db.CourseFile file,
    Map<String, FileDownloadState> trackedStates,
  ) {
    return _resolve(
      assetKey: file.id,
      trackedState: trackedStates[file.id],
      persistedDownloaded: file.localDownloadState == 'downloaded',
      persistedLocalPath: file.localFilePath,
    );
  }

  FileAssetRuntime resolveDetailItem(
    FileDetailItem item,
    Map<String, FileDownloadState> trackedStates,
  ) {
    return _resolve(
      assetKey: item.cacheKey,
      trackedState: trackedStates[item.cacheKey],
      persistedDownloaded: item.localDownloadState == 'downloaded',
      persistedLocalPath: item.localFilePath,
    );
  }

  FileAssetRuntime resolveAttachment({
    required String assetKey,
    required db.CachedAsset? cachedAsset,
    required Map<String, FileDownloadState> trackedStates,
  }) {
    return _resolve(
      assetKey: assetKey,
      trackedState: trackedStates[assetKey],
      persistedDownloaded: cachedAsset != null,
      persistedLocalPath: cachedAsset?.localPath,
    );
  }

  FileAssetRuntime _resolve({
    required String assetKey,
    required FileDownloadState? trackedState,
    required bool persistedDownloaded,
    required String? persistedLocalPath,
  }) {
    if (trackedState?.status == DownloadStatus.downloading ||
        trackedState?.status == DownloadStatus.failed) {
      return FileAssetRuntime(
        assetKey: assetKey,
        status: trackedState!.status,
        progress: trackedState.progress,
        localPath: trackedState.localPath,
        errorMessage: trackedState.errorMessage,
      );
    }

    if (persistedDownloaded && persistedLocalPath != null) {
      return FileAssetRuntime(
        assetKey: assetKey,
        status: DownloadStatus.downloaded,
        progress: 1,
        localPath: persistedLocalPath,
      );
    }

    if (trackedState?.status == DownloadStatus.downloaded &&
        trackedState?.localPath != null) {
      return FileAssetRuntime(
        assetKey: assetKey,
        status: DownloadStatus.downloaded,
        progress: trackedState!.progress,
        localPath: trackedState.localPath,
      );
    }

    return FileAssetRuntime(assetKey: assetKey, status: DownloadStatus.none);
  }
}

final fileAssetRuntimeResolverProvider = Provider<FileAssetRuntimeResolver>((
  ref,
) {
  return const FileAssetRuntimeResolver();
});
