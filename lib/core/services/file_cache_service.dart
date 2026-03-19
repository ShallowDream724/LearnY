/// File cache service — manages disk storage for downloaded files.
///
/// Responsibilities:
/// 1. Calculate cache sizes (total, per-course, per-file)
/// 2. Clear caches (total, per-course, per-file)
/// 3. Enumerate cached files with disk size
/// 4. Integrity checks (DB ↔ disk sync)
///
/// Design:
/// - Always reads from disk for size info (DB doesn't track file sizes on disk)
/// - Resets DB state when deleting files
/// - Defensive: never throws on missing files/directories
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../providers/providers.dart';
import 'file_download_service.dart';

// ---------------------------------------------------------------------------
//  Data model
// ---------------------------------------------------------------------------

class CachedFileInfo {
  final String fileId;
  final String courseId;
  final String title;
  final String fileType;
  final String localPath;
  final int diskSizeBytes;

  const CachedFileInfo({
    required this.fileId,
    required this.courseId,
    required this.title,
    required this.fileType,
    required this.localPath,
    required this.diskSizeBytes,
  });
}

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

// ---------------------------------------------------------------------------
//  Service
// ---------------------------------------------------------------------------

class FileCacheService {
  final Ref _ref;

  FileCacheService(this._ref);

  /// Root directory for all downloaded files.
  Future<Directory> get _rootDir async {
    final appDir = await getApplicationDocumentsDirectory();
    return Directory('${appDir.path}/learnx_files');
  }

  // ─── Size queries ───

  /// Total cache size across all courses.
  Future<int> getTotalCacheSize() async {
    final root = await _rootDir;
    if (!await root.exists()) return 0;
    return _directorySize(root);
  }

  /// Cache size for a single course.
  Future<int> getCourseCacheSize(String courseId) async {
    final root = await _rootDir;
    final courseDir = Directory('${root.path}/$courseId');
    if (!await courseDir.exists()) return 0;
    return _directorySize(courseDir);
  }

  /// Get per-course cache breakdown. Needs course names from DB.
  Future<List<CourseCacheInfo>> getCacheByCourse() async {
    final root = await _rootDir;
    if (!await root.exists()) return [];

    final db = _ref.read(databaseProvider);
    final result = <CourseCacheInfo>[];

    await for (final entity in root.list()) {
      if (entity is Directory) {
        final courseId = entity.path.split(Platform.pathSeparator).last;
        final size = await _directorySize(entity);
        if (size == 0) continue;

        // Count files
        int fileCount = 0;
        await for (final _ in entity.list()) {
          fileCount++;
        }

        // Try to get course name
        String courseName = courseId;
        try {
          final courses = await db.getCoursesBySemester('');
          // Fallback: get from all courses
          final allFiles = await db.getFilesByCourse(courseId);
          if (allFiles.isNotEmpty) {
            courseName = courseId; // Will be resolved by caller
          }
        } catch (_) {}

        result.add(CourseCacheInfo(
          courseId: courseId,
          courseName: courseName,
          fileCount: fileCount,
          totalBytes: size,
        ));
      }
    }

    // Sort by size descending
    result.sort((a, b) => b.totalBytes.compareTo(a.totalBytes));
    return result;
  }

  /// List all cached files with disk sizes.
  Future<List<CachedFileInfo>> getCachedFiles() async {
    final db = _ref.read(databaseProvider);
    final allFiles = await db.getAllFiles();
    final result = <CachedFileInfo>[];

    for (final f in allFiles) {
      if (f.localDownloadState == 'downloaded' && f.localFilePath != null) {
        final file = File(f.localFilePath!);
        if (await file.exists()) {
          final stat = await file.stat();
          result.add(CachedFileInfo(
            fileId: f.id,
            courseId: f.courseId,
            title: f.title,
            fileType: f.fileType,
            localPath: f.localFilePath!,
            diskSizeBytes: stat.size,
          ));
        }
      }
    }

    return result;
  }

  // ─── Cleanup ───

  /// Clear ALL cached files and reset DB states.
  Future<void> clearAllCache() async {
    final root = await _rootDir;
    if (await root.exists()) {
      await root.delete(recursive: true);
    }

    // Reset all DB download states
    final db = _ref.read(databaseProvider);
    final allFiles = await db.getAllFiles();
    for (final f in allFiles) {
      if (f.localDownloadState != 'none') {
        await db.updateFileDownloadState(f.id, 'none', null);
      }
    }

    // Clear in-memory download states
    _ref.read(fileDownloadProvider.notifier).clearAll();
  }

  /// Clear cache for a single course.
  Future<void> clearCourseCache(String courseId) async {
    final root = await _rootDir;
    final courseDir = Directory('${root.path}/$courseId');
    if (await courseDir.exists()) {
      await courseDir.delete(recursive: true);
    }

    // Reset DB states for this course
    final db = _ref.read(databaseProvider);
    final files = await db.getFilesByCourse(courseId);
    for (final f in files) {
      if (f.localDownloadState != 'none') {
        await db.updateFileDownloadState(f.id, 'none', null);
      }
    }
  }

  /// Clear a single file's cache.
  Future<void> clearFile(String fileId) async {
    final notifier = _ref.read(fileDownloadProvider.notifier);
    await notifier.deleteFile(fileId);
  }

  // ─── Integrity ───

  /// Verify all "downloaded" files still exist on disk.
  /// Resets DB state for any missing files.
  Future<int> verifyIntegrity() async {
    final db = _ref.read(databaseProvider);
    final allFiles = await db.getAllFiles();
    int repaired = 0;

    for (final f in allFiles) {
      if (f.localDownloadState == 'downloaded' && f.localFilePath != null) {
        final file = File(f.localFilePath!);
        if (!await file.exists()) {
          await db.updateFileDownloadState(f.id, 'none', null);
          repaired++;
        }
      }
    }

    return repaired;
  }

  // ─── Helpers ───

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
}

// ---------------------------------------------------------------------------
//  Provider
// ---------------------------------------------------------------------------

final fileCacheServiceProvider = Provider<FileCacheService>((ref) {
  return FileCacheService(ref);
});

/// Reactive cache size — recomputed when download states change.
final fileCacheSizeProvider = FutureProvider<int>((ref) async {
  // Depend on download states so we recompute when files are downloaded/deleted
  ref.watch(fileDownloadProvider);
  final service = ref.read(fileCacheServiceProvider);
  return service.getTotalCacheSize();
});
