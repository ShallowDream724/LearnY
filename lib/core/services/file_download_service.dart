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

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../api/learn_api.dart';
import '../database/database.dart';
import '../providers/providers.dart';

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

class FileDownloadNotifier extends StateNotifier<Map<String, FileDownloadState>> {
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
  }) async {
    // Guard: don't double-download
    if (_activeDownloads.contains(fileId)) return;
    _activeDownloads.add(fileId);

    // Update state to downloading
    _updateState(fileId, FileDownloadState(
      fileId: fileId,
      status: DownloadStatus.downloading,
      progress: 0.0,
    ));

    try {
      final api = _ref.read(apiClientProvider);
      final db = _ref.read(databaseProvider);

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
            _updateState(fileId, FileDownloadState(
              fileId: fileId,
              status: DownloadStatus.downloading,
              progress: progress,
              localPath: filePath,
            ));
          }
        },
      );

      // Update DB
      await db.updateFileDownloadState(fileId, 'downloaded', filePath);

      // Update state to downloaded
      _updateState(fileId, FileDownloadState(
        fileId: fileId,
        status: DownloadStatus.downloaded,
        progress: 1.0,
        localPath: filePath,
      ));
    } catch (e) {
      _updateState(fileId, FileDownloadState(
        fileId: fileId,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      ));
    } finally {
      _activeDownloads.remove(fileId);
    }
  }

  /// Open a downloaded file with the system handler.
  Future<bool> openFile(String fileId) async {
    final fileState = getFileState(fileId);
    if (fileState.localPath == null) return false;

    final file = File(fileState.localPath!);
    if (!await file.exists()) {
      // File was deleted externally — reset state
      final db = _ref.read(databaseProvider);
      await db.updateFileDownloadState(fileId, 'none', null);
      _updateState(fileId, FileDownloadState(
        fileId: fileId,
        status: DownloadStatus.none,
      ));
      return false;
    }

    final result = await OpenFilex.open(fileState.localPath!);
    return result.type == ResultType.done;
  }

  /// Delete a downloaded file and reset state.
  Future<void> deleteFile(String fileId) async {
    final fileState = getFileState(fileId);
    if (fileState.localPath != null) {
      final file = File(fileState.localPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    final db = _ref.read(databaseProvider);
    await db.updateFileDownloadState(fileId, 'none', null);

    _updateState(fileId, FileDownloadState(
      fileId: fileId,
      status: DownloadStatus.none,
    ));
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
          final db = _ref.read(databaseProvider);
          await db.updateFileDownloadState(f.id, 'none', null);
        }
      }
    }
    state = newState;
  }

  /// Clear all in-memory download states (used after cache wipe).
  void clearAll() {
    _activeDownloads.clear();
    state = {};
  }

  void _updateState(String fileId, FileDownloadState fileState) {
    state = Map.from(state)..[fileId] = fileState;
  }
}

// ---------------------------------------------------------------------------
//  Provider
// ---------------------------------------------------------------------------

final fileDownloadProvider =
    StateNotifierProvider<FileDownloadNotifier, Map<String, FileDownloadState>>(
  (ref) => FileDownloadNotifier(ref),
);
