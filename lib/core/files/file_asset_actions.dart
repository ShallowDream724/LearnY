import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/learning_data_actions_provider.dart';
import '../services/file_download_service.dart';
import 'file_models.dart';

class FileAssetActions {
  const FileAssetActions(this._ref);

  final Ref _ref;

  Future<void> ensureAvailable(FileDetailItem item) async {
    if (item.localDownloadState == 'downloaded' && item.localFilePath != null) {
      final localFile = File(item.localFilePath!);
      if (await localFile.exists()) {
        return;
      }

      await deleteAsset(item.cacheKey);
    }

    await download(item);
  }

  Future<void> download(FileDetailItem item) {
    return _ref
        .read(fileDownloadProvider.notifier)
        .downloadAsset(
          assetKey: item.cacheKey,
          courseId: item.courseId,
          downloadUrl: item.downloadUrl,
          fileName: item.title,
          fileType: item.fileType,
          persistedFileId: item.persistedFileId,
          sourceKind: item.sourceKind,
          routeDataJson: item.routeData.toJsonString(),
        );
  }

  Future<bool> open(FileDetailItem item) {
    return _ref.read(fileDownloadProvider.notifier).openFile(item.cacheKey);
  }

  Future<void> deleteAsset(String assetKey) {
    return _ref.read(fileDownloadProvider.notifier).deleteFile(assetKey);
  }

  Future<void> setReadState(FileDetailItem item, {required bool isRead}) async {
    if (!item.supportsReadState || item.persistedFileId == null) {
      return;
    }
    await _ref
        .read(learningDataActionsProvider)
        .setFileReadState(item.persistedFileId!, isRead: isRead);
  }
}

final fileAssetActionsProvider = Provider<FileAssetActions>((ref) {
  return FileAssetActions(ref);
});
