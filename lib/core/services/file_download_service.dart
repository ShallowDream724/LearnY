/// File download service — handles downloading, caching, and opening files.
///
/// Design decisions:
///
/// 1. **Stream download with progress**: Uses Dio's stream response to report
///    download progress in real-time. The UI can show a progress bar.
///
/// 2. **Persistent cache**: Downloaded files are stored in app documents dir
///    under `files/<courseId>/`. The local path is persisted in the DB so we
///    know which files are already downloaded.
///
/// 3. **Open with system**: Uses `open_filex` to open downloaded files with
///    the system's default handler (PDF reader, document viewer, etc.)
///
/// 4. **State machine**: Each file goes through:
///    `none` → `downloading` → `downloaded` (or `failed`)
///
/// 5. **Concurrent download guard**: Prevents the same file from being
///    downloaded multiple times simultaneously.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../files/cached_asset_repository.dart';
import '../files/file_models.dart';
import '../files/file_repository.dart';
import '../providers/providers.dart';
import 'file_cache_policy_service.dart';

// ---------------------------------------------------------------------------
//  Download state
// ---------------------------------------------------------------------------

class FileDownloadState {
  final String fileId;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String? localPath;
  final String? errorMessage;

  const FileDownloadState({
    required this.fileId,
    this.status = DownloadStatus.none,
    this.progress = 0.0,
    this.localPath,
    this.errorMessage,
  });

  FileDownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? errorMessage,
  }) {
    return FileDownloadState(
      fileId: fileId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      errorMessage: errorMessage,
    );
  }
}

enum DownloadStatus { none, downloading, downloaded, failed }

// ---------------------------------------------------------------------------
//  Download notifier — manages download states for all files
// ---------------------------------------------------------------------------

class FileDownloadNotifier
    extends StateNotifier<Map<String, FileDownloadState>> {
  final Ref _ref;

  /// Set of file IDs currently being downloaded (concurrent guard).
  final Set<String> _activeDownloads = {};

  FileDownloadNotifier(this._ref) : super({});

  /// Get the current download state for a file.
  FileDownloadState getFileState(String fileId) {
    return state[fileId] ??
        FileDownloadState(fileId: fileId, status: DownloadStatus.none);
  }

  /// Start downloading a file.
  ///
  /// Returns immediately — the download happens in the background.
  /// Listen to state changes to track progress.
  Future<void> downloadFile({
    required String fileId,
    required String courseId,
    required String downloadUrl,
    required String fileName,
    String? fileType,
  }) async {
    await downloadAsset(
      assetKey: fileId,
      courseId: courseId,
      downloadUrl: downloadUrl,
      fileName: fileName,
      fileType: fileType,
      persistedFileId: fileId,
      sourceKind: 'courseFile',
      routeDataJson: null,
    );
  }

  Future<void> downloadAsset({
    required String assetKey,
    required String courseId,
    required String downloadUrl,
    required String fileName,
    String? fileType,
    String? persistedFileId,
    String sourceKind = 'generic',
    String? routeDataJson,
  }) async {
    // Guard: don't double-download
    if (_activeDownloads.contains(assetKey)) return;
    _activeDownloads.add(assetKey);

    // Update state to downloading
    _updateState(
      assetKey,
      FileDownloadState(
        fileId: assetKey,
        status: DownloadStatus.downloading,
        progress: 0.0,
      ),
    );

    try {
      final api = _ref.read(apiClientProvider);
      final fileRepository = _ref.read(fileRepositoryProvider);
      final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);

      // Create download directory
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/learnx_files/$courseId');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      // Sanitize filename
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${downloadDir.path}/$safeName';

      // Download with progress tracking
      await api.dio.download(
        downloadUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            _updateState(
              assetKey,
              FileDownloadState(
                fileId: assetKey,
                status: DownloadStatus.downloading,
                progress: progress,
                localPath: filePath,
              ),
            );
          }
        },
      );

      final downloadedFile = File(filePath);
      final downloadedStat = await downloadedFile.stat();
      final accessedAt = DateTime.now().toIso8601String();

      await cachedAssetRepository.saveDownloadedAsset(
        assetKey: assetKey,
        courseId: courseId,
        title: fileName,
        fileType: fileType ?? _fileTypeFromName(fileName),
        localPath: filePath,
        fileSizeBytes: downloadedStat.size,
        persistedFileId: persistedFileId,
        sourceKind: sourceKind,
        routeDataJson: routeDataJson,
        accessedAt: accessedAt,
      );

      // Update DB
      if (persistedFileId != null) {
        await fileRepository.updateDownloadState(
          persistedFileId,
          'downloaded',
          filePath,
        );
      }

      // Update state to downloaded
      _updateState(
        assetKey,
        FileDownloadState(
          fileId: assetKey,
          status: DownloadStatus.downloaded,
          progress: 1.0,
          localPath: filePath,
        ),
      );

      final policyResult = await _ref
          .read(fileCachePolicyServiceProvider)
          .enforceLimit(protectedAssetKey: assetKey);
      final clearedKeys = {
        ...policyResult.evictedAssetKeys,
        ...policyResult.repairedAssetKeys,
      };
      if (clearedKeys.isNotEmpty) {
        clearTrackedStates(clearedKeys);
      }
    } catch (e) {
      _updateState(
        assetKey,
        FileDownloadState(
          fileId: assetKey,
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        ),
      );
    } finally {
      _activeDownloads.remove(assetKey);
    }
  }

  /// Open a downloaded file with the system handler.
  Future<bool> openFile(String assetKey) async {
    final localPath = await _resolveLocalPath(assetKey);
    if (localPath == null) return false;

    final file = File(localPath);
    if (!await file.exists()) {
      // File was deleted externally — reset state
      await _resetDownloadState(assetKey);
      return false;
    }

    final result = await OpenFilex.open(localPath);
    if (result.type == ResultType.done) {
      await _touchCachedAsset(assetKey, file);
    }
    return result.type == ResultType.done;
  }

  /// Delete a downloaded file and reset state.
  Future<void> deleteFile(String assetKey) async {
    final localPath = await _resolveLocalPath(assetKey);
    if (localPath != null) {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    }

    await _resetDownloadState(assetKey);
  }

  /// Initialize download states from DB (for files already downloaded).
  Future<void> loadInitialStates(List<CourseFile> files) async {
    final newState = Map<String, FileDownloadState>.from(state);
    for (final f in files) {
      if (f.localDownloadState == 'downloaded' && f.localFilePath != null) {
        // Verify file still exists
        final file = File(f.localFilePath!);
        if (await file.exists()) {
          newState[f.id] = FileDownloadState(
            fileId: f.id,
            status: DownloadStatus.downloaded,
            progress: 1.0,
            localPath: f.localFilePath,
          );
        } else {
          // File was deleted externally — reset
          final fileRepository = _ref.read(fileRepositoryProvider);
          await fileRepository.updateDownloadState(f.id, 'none', null);
          _activeDownloads.remove(f.id);
          newState.remove(f.id);
        }
      } else {
        _activeDownloads.remove(f.id);
        newState.remove(f.id);
      }
    }
    state = newState;
  }

  /// Clear all in-memory download states (used after cache wipe).
  void clearAll() {
    _activeDownloads.clear();
    state = {};
  }

  void clearTrackedStates(Iterable<String> fileIds) {
    final nextState = Map<String, FileDownloadState>.from(state);
    for (final fileId in fileIds) {
      _activeDownloads.remove(fileId);
      nextState.remove(fileId);
    }
    state = nextState;
  }

  void _updateState(String fileId, FileDownloadState fileState) {
    state = Map.from(state)..[fileId] = fileState;
  }

  Future<String?> _resolveLocalPath(String assetKey) async {
    final inMemoryPath = state[assetKey]?.localPath;
    if (inMemoryPath != null && inMemoryPath.isNotEmpty) {
      return inMemoryPath;
    }

    final cachedAsset = await _ref
        .read(cachedAssetRepositoryProvider)
        .getAsset(assetKey);
    if (cachedAsset != null && cachedAsset.localPath.isNotEmpty) {
      return cachedAsset.localPath;
    }

    final file = await _ref.read(fileRepositoryProvider).getFileById(assetKey);
    return file?.localFilePath;
  }

  Future<void> _resetDownloadState(String assetKey) async {
    final fileRepository = _ref.read(fileRepositoryProvider);
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final cachedAsset = await cachedAssetRepository.getAsset(assetKey);

    final persistedFileId = cachedAsset?.persistedFileId ?? assetKey;
    final persistedFile = await fileRepository.getFileById(persistedFileId);
    if (persistedFile != null) {
      await fileRepository.updateDownloadState(persistedFile.id, 'none', null);
    }

    await cachedAssetRepository.deleteAsset(assetKey);

    _activeDownloads.remove(assetKey);
    final nextState = Map<String, FileDownloadState>.from(state);
    nextState.remove(assetKey);
    state = nextState;
  }

  Future<void> _touchCachedAsset(String assetKey, File file) async {
    final cachedAssetRepository = _ref.read(cachedAssetRepositoryProvider);
    final accessedAt = DateTime.now().toIso8601String();
    final cachedAsset = await cachedAssetRepository.getAsset(assetKey);
    if (cachedAsset != null) {
      await cachedAssetRepository.touchAsset(assetKey, accessedAt: accessedAt);
      return;
    }

    final persistedFile = await _ref
        .read(fileRepositoryProvider)
        .getFileById(assetKey);
    if (persistedFile == null) {
      return;
    }
    final semesterId = _ref.read(currentSemesterIdProvider);
    final courseNames = await _ref
        .read(fileRepositoryProvider)
        .getCourseNameMap(semesterId);

    await cachedAssetRepository.saveDownloadedAsset(
      assetKey: assetKey,
      courseId: persistedFile.courseId,
      title: persistedFile.title,
      fileType: persistedFile.fileType,
      localPath: file.path,
      fileSizeBytes: await file.length(),
      persistedFileId: persistedFile.id,
      sourceKind: 'courseFile',
      routeDataJson: FileDetailRouteData.courseFile(
        fileId: persistedFile.id,
        courseId: persistedFile.courseId,
        courseName: courseNames[persistedFile.courseId] ?? '',
      ).toJsonString(),
      accessedAt: accessedAt,
    );
  }

  String _fileTypeFromName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex >= fileName.length - 1) {
      return '';
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }
}

// ---------------------------------------------------------------------------
//  Provider
// ---------------------------------------------------------------------------

final fileDownloadProvider =
    StateNotifierProvider<FileDownloadNotifier, Map<String, FileDownloadState>>(
      (ref) => FileDownloadNotifier(ref),
    );
