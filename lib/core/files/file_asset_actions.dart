import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../providers/app_providers.dart';
import '../providers/learning_data_actions_provider.dart';
import '../services/file_download_service.dart';
import 'file_access_resolver.dart';
import 'file_models.dart';

class FileAssetActions {
  FileAssetActions(this._ref);

  final Ref _ref;
  final Map<String, Future<String>> _availabilityRequests = {};
  final Map<String, Future<void>> _shareRequests = {};
  final Set<void Function()> _cancelDownloadWaiters = {};
  final Completer<void> _lifecycleEnded = Completer<void>();
  bool _active = true;

  Future<String> ensureAvailable(FileDetailItem item) {
    if (!_active) return Future.error(_cancelledError);
    final active = _availabilityRequests[item.cacheKey];
    if (active != null) return active;

    final request = _ensureAvailable(item);
    _availabilityRequests[item.cacheKey] = request;
    return request.whenComplete(() {
      if (identical(_availabilityRequests[item.cacheKey], request)) {
        _availabilityRequests.remove(item.cacheKey);
      }
    });
  }

  Future<String> _ensureAvailable(FileDetailItem item) async {
    _ensureActive();
    var trackedState = _ref.read(fileDownloadProvider)[item.cacheKey];
    if (trackedState?.status == DownloadStatus.downloading) {
      trackedState = await _waitForDownload(item.cacheKey);
      _ensureActive();
      return _publishedPath(trackedState);
    }

    final trackedPath = trackedState?.status == DownloadStatus.downloaded
        ? trackedState?.localPath
        : null;
    if (trackedPath != null && await File(trackedPath).exists()) {
      return trackedPath;
    }

    if (item.localDownloadState == 'downloaded' && item.localFilePath != null) {
      final localFile = File(item.localFilePath!);
      if (await localFile.exists()) return localFile.path;
      await deleteAsset(item.cacheKey);
    }

    await download(item);
    _ensureActive();
    trackedState = _ref.read(fileDownloadProvider)[item.cacheKey];
    if (trackedState?.status == DownloadStatus.downloading) {
      trackedState = await _waitForDownload(item.cacheKey);
      _ensureActive();
    }
    return _publishedPath(trackedState);
  }

  Future<void> download(FileDetailItem item) async {
    _ensureActive();
    await _guardSession(
      _ref
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
          ),
    );
  }

  Future<bool> open(FileDetailItem item) async {
    _ensureActive();
    final opened = await _guardSession(
      _ref.read(fileDownloadProvider.notifier).openFile(item.cacheKey),
    );
    return opened;
  }

  Future<bool> ensureAvailableAndOpen(FileDetailItem item) async {
    await ensureAvailable(item);
    _ensureActive();
    return open(item);
  }

  Future<void> share(FileDetailItem item) {
    if (!_active) return Future.error(_cancelledError);
    final active = _shareRequests[item.cacheKey];
    if (active != null) return active;

    final request = _share(item);
    _shareRequests[item.cacheKey] = request;
    return request.whenComplete(() {
      if (identical(_shareRequests[item.cacheKey], request)) {
        _shareRequests.remove(item.cacheKey);
      }
    });
  }

  Future<void> _share(FileDetailItem item) async {
    final localPath = await ensureAvailable(item);
    _ensureActive();
    final accessDescriptor = _ref
        .read(fileAccessResolverProvider)
        .resolve(title: item.title, fileType: item.fileType);
    await Share.shareXFiles(
      [
        XFile(
          localPath,
          mimeType: accessDescriptor.mimeType,
          name: accessDescriptor.displayName,
        ),
      ],
      fileNameOverrides: [accessDescriptor.displayName],
    );
  }

  Future<bool> openContainingFolder(FileDetailItem item) async {
    _ensureActive();
    final opened = await _guardSession(
      _ref
          .read(fileDownloadProvider.notifier)
          .openContainingFolder(item.cacheKey),
    );
    return opened;
  }

  Future<void> deleteAsset(String assetKey) async {
    _ensureActive();
    await _guardSession(
      _ref.read(fileDownloadProvider.notifier).deleteFile(assetKey),
    );
  }

  Future<void> setReadState(FileDetailItem item, {required bool isRead}) async {
    _ensureActive();
    if (!item.supportsReadState || item.persistedFileId == null) {
      return;
    }
    await _guardSession(
      _ref
          .read(learningDataActionsProvider)
          .setFileReadState(item.persistedFileId!, isRead: isRead),
    );
  }

  Future<FileDownloadState> _waitForDownload(String assetKey) {
    if (!_active) return Future.error(_cancelledError);
    final completer = Completer<FileDownloadState>();
    ProviderSubscription<Map<String, FileDownloadState>>? subscription;
    void cancel() {
      if (!completer.isCompleted) completer.completeError(_cancelledError);
    }

    _cancelDownloadWaiters.add(cancel);
    subscription = _ref.listen<Map<String, FileDownloadState>>(
      fileDownloadProvider,
      (previous, next) {
        final nextState = next[assetKey];
        if (nextState == null) {
          if (previous?[assetKey]?.status == DownloadStatus.downloading &&
              !completer.isCompleted) {
            completer.completeError(const FileAssetActionException('文件下载已取消'));
          }
          return;
        }
        if (nextState.status == DownloadStatus.downloaded &&
            !completer.isCompleted) {
          final errorMessage = nextState.errorMessage;
          if (errorMessage == null || errorMessage.isEmpty) {
            completer.complete(nextState);
          } else {
            completer.completeError(FileAssetActionException(errorMessage));
          }
        } else if (nextState.status == DownloadStatus.failed &&
            !completer.isCompleted) {
          completer.completeError(
            FileAssetActionException(nextState.errorMessage ?? '文件下载失败'),
          );
        }
      },
      fireImmediately: true,
    );
    return completer.future.whenComplete(() {
      _cancelDownloadWaiters.remove(cancel);
      subscription?.close();
    });
  }

  Future<String> _publishedPath(FileDownloadState? state) async {
    final errorMessage = state?.errorMessage;
    if (errorMessage != null && errorMessage.isNotEmpty) {
      throw FileAssetActionException(errorMessage);
    }
    if (state?.status == DownloadStatus.downloaded &&
        state?.localPath != null &&
        state!.localPath!.isNotEmpty) {
      if (await File(state.localPath!).exists()) return state.localPath!;
      await deleteAsset(state.fileId);
    }
    throw FileAssetActionException(state?.errorMessage ?? '文件下载失败');
  }

  void dispose() {
    if (!_active) return;
    _active = false;
    _lifecycleEnded.complete();
    for (final cancel in _cancelDownloadWaiters.toList()) {
      cancel();
    }
    _cancelDownloadWaiters.clear();
  }

  void _ensureActive() {
    if (!_active) throw _cancelledError;
  }

  Future<T> _guardSession<T>(Future<T> operation) async {
    _ensureActive();
    final result = await Future.any<T>([
      operation,
      _lifecycleEnded.future.then<T>((_) => throw _cancelledError),
    ]);
    _ensureActive();
    return result;
  }

  static const _cancelledError = FileAssetActionException('账户已切换，文件操作已取消');
}

class FileAssetActionException implements Exception {
  const FileAssetActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

final fileAssetActionsProvider = Provider<FileAssetActions>((ref) {
  ref.watch(dataSessionEpochProvider);
  final actions = FileAssetActions(ref);
  ref.onDispose(actions.dispose);
  return actions;
});
