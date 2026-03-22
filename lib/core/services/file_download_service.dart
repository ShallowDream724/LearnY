// File download service — handles downloading, caching, and opening files.
//
// Design decisions:
//
// 1. **Stream download with progress**: Uses Dio's stream response to report
//    download progress in real-time. The UI can show a progress bar.
//
// 2. **Persistent cache**: Downloaded files are stored in app documents dir
//    under `files/<courseId>/`. The local path is persisted in the DB so we
//    know which files are already downloaded.
//
// 3. **Open with system**: Uses `open_filex` to open downloaded files with
//    the system's default handler (PDF reader, document viewer, etc.)
//
// 4. **State machine**: Each file goes through:
//    `none` → `downloading` → `downloaded` (or `failed`)
//
// 5. **Concurrent download guard**: Prevents the same file from being
//    downloaded multiple times simultaneously.
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../api/learn_api.dart';
import '../database/database.dart';
import '../files/cached_asset_repository.dart';
import '../files/file_access_resolver.dart';
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

class DownloadedPayloadValidation {
  const DownloadedPayloadValidation({
    required this.isValid,
    this.looksLikeSessionExpired = false,
    this.errorMessage,
  });

  final bool isValid;
  final bool looksLikeSessionExpired;
  final String? errorMessage;

  const DownloadedPayloadValidation.valid() : this(isValid: true);

  const DownloadedPayloadValidation.invalid({
    required String errorMessage,
    bool looksLikeSessionExpired = false,
  }) : this(
         isValid: false,
         looksLikeSessionExpired: looksLikeSessionExpired,
         errorMessage: errorMessage,
       );
}

class DownloadedPayloadInspector {
  const DownloadedPayloadInspector();

  Future<DownloadedPayloadValidation> inspect({
    required File file,
    required Headers headers,
    required int? statusCode,
    String? expectedFileType,
  }) async {
    if (statusCode != 200) {
      return DownloadedPayloadValidation.invalid(
        errorMessage: '文件下载失败 ($statusCode)',
      );
    }

    final size = await file.length();
    if (size <= 0) {
      return const DownloadedPayloadValidation.invalid(
        errorMessage: '文件下载失败 (empty file)',
      );
    }

    final normalizedType = (expectedFileType ?? '').toLowerCase();
    final allowHtml = normalizedType == 'html' || normalizedType == 'htm';
    final contentType =
        headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';

    final shouldInspectSnippet =
        size <= 8192 ||
        contentType.contains('html') ||
        contentType.contains('text');
    final snippet = shouldInspectSnippet ? await _readSnippet(file) : '';
    final lowerSnippet = snippet.toLowerCase();

    if (!allowHtml && contentType.contains('text/html')) {
      return DownloadedPayloadValidation.invalid(
        errorMessage: '会话已过期，请重新登录',
        looksLikeSessionExpired: _looksLikeSessionArtifact(lowerSnippet),
      );
    }

    if (!allowHtml &&
        (_looksLikeHtml(lowerSnippet) ||
            _looksLikeSessionArtifact(lowerSnippet))) {
      return DownloadedPayloadValidation.invalid(
        errorMessage: '会话已过期，请重新登录',
        looksLikeSessionExpired: true,
      );
    }

    return const DownloadedPayloadValidation.valid();
  }

  Future<String> _readSnippet(File file) async {
    final bytes = await file
        .openRead(0, 2048)
        .fold<List<int>>(<int>[], (buffer, chunk) => buffer..addAll(chunk));
    return String.fromCharCodes(bytes);
  }

  bool _looksLikeHtml(String snippet) {
    final trimmed = snippet.trimLeft();
    return trimmed.startsWith('<!doctype html') ||
        trimmed.startsWith('<html') ||
        trimmed.startsWith('<?xml') && trimmed.contains('<html');
  }

  bool _looksLikeSessionArtifact(String snippet) {
    return snippet.contains('login_timeout') ||
        snippet.contains('location.href') ||
        snippet.contains('j_spring_security') ||
        snippet.contains('id.tsinghua.edu.cn') ||
        snippet.contains('统一身份认证') ||
        snippet.contains('请重新登录') ||
        snippet.contains('请登录');
  }
}

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
      final accessResolver = _ref.read(fileAccessResolverProvider);
      final payloadInspector = _ref.read(downloadedPayloadInspectorProvider);

      // Create download directory
      final appDir = await getApplicationDocumentsDirectory();
      final downloadDir = Directory('${appDir.path}/learnx_files/$courseId');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }

      final resolvedFileAccess = accessResolver.resolve(
        title: fileName,
        fileType: fileType,
      );
      final filePath = p.join(
        downloadDir.path,
        resolvedFileAccess.storedFileName,
      );

      await _downloadWithRecovery(
        api: api,
        assetKey: assetKey,
        downloadUrl: downloadUrl,
        filePath: filePath,
        fileType: fileType,
        payloadInspector: payloadInspector,
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

  Future<Response<dynamic>> _downloadWithRecovery({
    required Learn2018Helper api,
    required String assetKey,
    required String downloadUrl,
    required String filePath,
    required String? fileType,
    required DownloadedPayloadInspector payloadInspector,
  }) async {
    final firstResponse = await _performDownload(
      api: api,
      assetKey: assetKey,
      downloadUrl: downloadUrl,
      filePath: filePath,
    );
    final firstValidation = await payloadInspector.inspect(
      file: File(filePath),
      headers: firstResponse.headers,
      statusCode: firstResponse.statusCode,
      expectedFileType: fileType,
    );
    if (firstValidation.isValid) {
      return firstResponse;
    }

    await _deleteIfExists(filePath);
    if (!firstValidation.looksLikeSessionExpired) {
      throw StateError(firstValidation.errorMessage ?? '文件下载失败');
    }

    final recovered = await _ref
        .read(sessionRecoveryCoordinatorProvider)
        .recoverSession(apiClient: api);
    if (!recovered.recovered) {
      throw StateError(firstValidation.errorMessage ?? '会话已过期，请重新登录');
    }

    final retryResponse = await _performDownload(
      api: api,
      assetKey: assetKey,
      downloadUrl: downloadUrl,
      filePath: filePath,
    );
    final retryValidation = await payloadInspector.inspect(
      file: File(filePath),
      headers: retryResponse.headers,
      statusCode: retryResponse.statusCode,
      expectedFileType: fileType,
    );
    if (!retryValidation.isValid) {
      await _deleteIfExists(filePath);
      throw StateError(retryValidation.errorMessage ?? '文件下载失败');
    }
    return retryResponse;
  }

  Future<Response<dynamic>> _performDownload({
    required Learn2018Helper api,
    required String assetKey,
    required String downloadUrl,
    required String filePath,
  }) {
    return api.dio.download(
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
  }

  Future<void> _deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
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

    final accessDescriptor = await _resolveAccessDescriptor(
      assetKey: assetKey,
      localPath: localPath,
    );
    final result = await OpenFilex.open(
      localPath,
      type: accessDescriptor?.mimeType,
    );
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

  Future<FileAccessDescriptor?> _resolveAccessDescriptor({
    required String assetKey,
    required String localPath,
  }) async {
    final accessResolver = _ref.read(fileAccessResolverProvider);
    final cachedAsset = await _ref
        .read(cachedAssetRepositoryProvider)
        .getAsset(assetKey);
    if (cachedAsset != null) {
      return accessResolver.resolve(
        title: cachedAsset.title,
        fileType: cachedAsset.fileType,
      );
    }

    final persistedFile = await _ref
        .read(fileRepositoryProvider)
        .getFileById(assetKey);
    if (persistedFile != null) {
      return accessResolver.resolve(
        title: persistedFile.title,
        fileType: persistedFile.fileType,
      );
    }

    final fileName = p.basename(localPath);
    if (fileName.isEmpty) {
      return null;
    }
    return accessResolver.resolve(title: fileName);
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

final downloadedPayloadInspectorProvider = Provider<DownloadedPayloadInspector>(
  (ref) {
    return const DownloadedPayloadInspector();
  },
);
