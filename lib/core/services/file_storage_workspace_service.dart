import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../files/file_access_resolver.dart';
import '../providers/app_providers.dart';

typedef AppDocumentsDirectoryResolver = Future<Directory> Function();

const String primaryFileStorageFolderName = 'LearnY Files';
const List<String> legacyFileStorageFolderNames = <String>[
  'learnx_files',
  'learny_files',
];

class FileStorageWorkspaceService {
  FileStorageWorkspaceService({
    required AppDatabase database,
    AppDocumentsDirectoryResolver? getDocumentsDirectory,
  }) : _database = database,
       _getDocumentsDirectory =
           getDocumentsDirectory ?? getApplicationDocumentsDirectory;

  final AppDatabase _database;
  final AppDocumentsDirectoryResolver _getDocumentsDirectory;
  final FileAccessResolver _fileAccessResolver = const FileAccessResolver();

  Future<void>? _prepareTask;

  Future<void> prepare() {
    final existingTask = _prepareTask;
    if (existingTask != null) {
      return existingTask;
    }

    final task = _prepare();
    _prepareTask = task;
    return task.catchError((error) {
      _prepareTask = null;
      throw error;
    });
  }

  Future<Directory> ensureFilesRootDirectory() async {
    await prepare();
    return _primaryRootDirectory();
  }

  Future<Directory> ensureArchiveRootDirectory() async {
    final root = await ensureFilesRootDirectory();
    return Directory(p.join(root.path, '.archive'));
  }

  Future<Directory> ensureCourseDirectory({
    required String courseId,
    String? courseName,
  }) async {
    await prepare();

    final root = await _primaryRootDirectory();
    final directoryName = await _preferredCourseDirectoryName(
      courseId: courseId,
      fallbackCourseName: courseName,
    );
    final preferredDirectory = Directory(p.join(root.path, directoryName));
    if (await preferredDirectory.exists()) {
      return preferredDirectory;
    }

    final legacyDirectory = Directory(
      p.join(root.path, _sanitizePathSegment(courseId)),
    );
    if (await legacyDirectory.exists() &&
        !p.equals(legacyDirectory.path, preferredDirectory.path)) {
      await _migrateLegacyRoot(legacyDirectory, preferredDirectory);
      await _rewritePersistedPaths(
        fromPrefix: legacyDirectory.path,
        toPrefix: preferredDirectory.path,
      );
      return preferredDirectory;
    }

    await preferredDirectory.create(recursive: true);
    return preferredDirectory;
  }

  Future<void> _prepare() async {
    final primaryRoot = await _primaryRootDirectory();
    final legacyRoots = await _legacyRootDirectories();

    for (final legacyRoot in legacyRoots) {
      if (p.equals(legacyRoot.path, primaryRoot.path)) {
        continue;
      }
      if (await legacyRoot.exists()) {
        await _migrateLegacyRoot(legacyRoot, primaryRoot);
      }
      await _rewritePersistedPaths(
        fromPrefix: legacyRoot.path,
        toPrefix: primaryRoot.path,
      );
    }

    await _migrateCourseDirectories(primaryRoot);
    await _migratePersistedDownloadPaths(primaryRoot);
  }

  Future<Directory> _primaryRootDirectory() async {
    final documentsDirectory = await _getDocumentsDirectory();
    return Directory(
      p.join(documentsDirectory.path, primaryFileStorageFolderName),
    );
  }

  Future<List<Directory>> _legacyRootDirectories() async {
    final documentsDirectory = await _getDocumentsDirectory();
    return legacyFileStorageFolderNames
        .map((name) => Directory(p.join(documentsDirectory.path, name)))
        .toList(growable: false);
  }

  Future<void> _migrateLegacyRoot(
    Directory legacyRoot,
    Directory primaryRoot,
  ) async {
    if (!await legacyRoot.exists()) {
      return;
    }

    await _mergeDirectoryContents(source: legacyRoot, target: primaryRoot);
    if (await legacyRoot.exists()) {
      try {
        await legacyRoot.delete(recursive: true);
      } on FileSystemException {
        // Best effort: the new workspace is already usable as long as the
        // moved/copied files exist at the target location. A later launch can
        // retry removing any leftover legacy shell.
      }
    }
  }

  Future<void> _mergeDirectoryContents({
    required Directory source,
    required Directory target,
  }) async {
    await target.create(recursive: true);

    await for (final entity in source.list(
      recursive: false,
      followLinks: false,
    )) {
      final relativePath = p.relative(entity.path, from: source.path);
      final targetPath = p.join(target.path, relativePath);

      if (entity is Directory) {
        await _mergeDirectoryContents(
          source: entity,
          target: Directory(targetPath),
        );
        if (await entity.exists()) {
          try {
            await entity.delete(recursive: true);
          } on FileSystemException {
            // Ignore and keep retrying higher up; files have already been
            // materialized into the target tree.
          }
        }
        continue;
      }

      if (entity is! File) {
        continue;
      }

      final targetFile = File(targetPath);
      if (!await targetFile.parent.exists()) {
        await targetFile.parent.create(recursive: true);
      }

      if (!await targetFile.exists()) {
        await _moveFileOrCopyFallback(source: entity, target: targetFile);
        continue;
      }

      final sourceStat = await entity.stat();
      final targetStat = await targetFile.stat();
      final shouldReplaceTarget =
          sourceStat.size > 0 &&
          (targetStat.size == 0 ||
              sourceStat.modified.isAfter(targetStat.modified));

      if (shouldReplaceTarget) {
        await targetFile.delete();
        await _moveFileOrCopyFallback(source: entity, target: targetFile);
      } else {
        try {
          await entity.delete();
        } on FileSystemException {
          // The source copy is stale, but the target copy is already the one we
          // want to keep. Leaving the old copy behind is acceptable until a
          // later cleanup pass can remove it.
        }
      }
    }
  }

  Future<void> _moveFileOrCopyFallback({
    required File source,
    required File target,
  }) async {
    try {
      await source.rename(target.path);
      return;
    } on FileSystemException {
      await source.copy(target.path);
      try {
        await source.delete();
      } on FileSystemException {
        // Keep the copied target; the leftover source can be cleaned later.
      }
    }
  }

  Future<void> _rewritePersistedPaths({
    required String fromPrefix,
    required String toPrefix,
  }) async {
    if (_normalizePathForComparison(fromPrefix) ==
        _normalizePathForComparison(toPrefix)) {
      return;
    }

    await _database.transaction(() async {
      for (final file in await _database.getAllFiles()) {
        final localPath = file.localFilePath;
        if (localPath == null || localPath.isEmpty) {
          continue;
        }
        final rewrittenPath = _rebasePersistedPath(
          localPath,
          fromPrefix: fromPrefix,
          toPrefix: toPrefix,
        );
        if (rewrittenPath == null || rewrittenPath == localPath) {
          continue;
        }
        await _database.updateFileLocalPath(file.id, rewrittenPath);
      }

      for (final asset in await _database.getAllCachedAssets()) {
        final rewrittenPath = _rebasePersistedPath(
          asset.localPath,
          fromPrefix: fromPrefix,
          toPrefix: toPrefix,
        );
        if (rewrittenPath == null || rewrittenPath == asset.localPath) {
          continue;
        }
        await _database.updateCachedAssetLocalPath(
          asset.assetKey,
          rewrittenPath,
        );
      }
    });
  }

  Future<void> _migrateCourseDirectories(Directory primaryRoot) async {
    final courses = await _database.getAllCourses();
    if (courses.isEmpty) {
      return;
    }

    final directoryNamesByCourseId = _directoryNamesByCourseId(courses);
    for (final course in courses) {
      final directoryName = directoryNamesByCourseId[course.id];
      if (directoryName == null || directoryName.isEmpty) {
        continue;
      }

      final legacyDirectory = Directory(
        p.join(primaryRoot.path, _sanitizePathSegment(course.id)),
      );
      final preferredDirectory = Directory(
        p.join(primaryRoot.path, directoryName),
      );
      if (!await legacyDirectory.exists() ||
          p.equals(legacyDirectory.path, preferredDirectory.path)) {
        continue;
      }

      await _migrateLegacyRoot(legacyDirectory, preferredDirectory);
      await _rewritePersistedPaths(
        fromPrefix: legacyDirectory.path,
        toPrefix: preferredDirectory.path,
      );
    }
  }

  Future<void> _migratePersistedDownloadPaths(Directory primaryRoot) async {
    final courses = await _database.getAllCourses();
    if (courses.isEmpty) {
      return;
    }

    final directoryNamesByCourseId = _directoryNamesByCourseId(courses);
    final cachedAssets = await _database.getAllCachedAssets();
    final targetPathByPersistedFileId = <String, String>{};
    for (final asset in cachedAssets) {
      final persistedFileId = asset.persistedFileId;
      if (persistedFileId != null && persistedFileId.isNotEmpty) {
        final courseDirectoryName = directoryNamesByCourseId[asset.courseId];
        if (courseDirectoryName != null) {
          targetPathByPersistedFileId[persistedFileId] = p.join(
            primaryRoot.path,
            courseDirectoryName,
            _fileAccessResolver
                .resolve(
                  title: asset.title,
                  fileType: asset.fileType,
                  assetKey: asset.assetKey,
                )
                .storedFileName,
          );
        }
      }
    }

    await _database.transaction(() async {
      for (final asset in cachedAssets) {
        if (asset.localPath.isEmpty) {
          continue;
        }
        final courseDirectoryName = directoryNamesByCourseId[asset.courseId];
        if (courseDirectoryName == null) {
          continue;
        }
        final storedFileName = _fileAccessResolver
            .resolve(
              title: asset.title,
              fileType: asset.fileType,
              assetKey: asset.assetKey,
            )
            .storedFileName;
        final targetPath = p.join(
          primaryRoot.path,
          courseDirectoryName,
          storedFileName,
        );
        if (!await _materializeMigratedFile(
          sourcePath: asset.localPath,
          targetPath: targetPath,
        )) {
          continue;
        }
        if (!p.equals(p.normalize(asset.localPath), p.normalize(targetPath))) {
          await _database.updateCachedAssetLocalPath(
            asset.assetKey,
            targetPath,
          );
        }
      }

      for (final file in await _database.getAllFiles()) {
        final localPath = file.localFilePath;
        if (localPath == null || localPath.isEmpty) {
          continue;
        }
        final courseDirectoryName = directoryNamesByCourseId[file.courseId];
        if (courseDirectoryName == null) {
          continue;
        }
        final targetPath =
            targetPathByPersistedFileId[file.id] ??
            p.join(
              primaryRoot.path,
              courseDirectoryName,
              _fileAccessResolver
                  .resolve(
                    title: file.title,
                    fileType: file.fileType,
                    assetKey: file.id,
                  )
                  .storedFileName,
            );
        if (!await _materializeMigratedFile(
          sourcePath: localPath,
          targetPath: targetPath,
        )) {
          continue;
        }
        if (!p.equals(p.normalize(localPath), p.normalize(targetPath))) {
          await _database.updateFileLocalPath(file.id, targetPath);
        }
      }
    });
  }

  Future<bool> _materializeMigratedFile({
    required String sourcePath,
    required String targetPath,
  }) async {
    final source = File(sourcePath);
    final target = File(targetPath);
    if (p.equals(p.normalize(source.path), p.normalize(target.path))) {
      return target.exists();
    }

    if (await target.exists() && await target.length() > 0) {
      return true;
    }
    if (!await source.exists()) {
      return false;
    }

    await target.parent.create(recursive: true);
    final temporaryTarget = File(
      '${target.path}.migrating-${DateTime.now().microsecondsSinceEpoch}-$pid',
    );
    try {
      await source.copy(temporaryTarget.path);
      if (await target.exists()) {
        await target.delete();
      }
      await temporaryTarget.rename(target.path);
      return true;
    } on FileSystemException {
      return false;
    } finally {
      if (await temporaryTarget.exists()) {
        try {
          await temporaryTarget.delete();
        } on FileSystemException {
          // A later preparation pass can remove or replace this staging file.
        }
      }
    }
  }

  Future<String> _preferredCourseDirectoryName({
    required String courseId,
    String? fallbackCourseName,
  }) async {
    final course = await _database.getCourseById(courseId);
    return _displayDirectoryNameForCourse(
      courseId: courseId,
      courseName: course?.name ?? fallbackCourseName,
      semesterId: null,
    );
  }

  Map<String, String> _directoryNamesByCourseId(List<Course> courses) {
    final result = <String, String>{};
    for (final course in courses) {
      result[course.id] = _displayDirectoryNameForCourse(
        courseId: course.id,
        courseName: course.name,
        semesterId: null,
      );
    }
    return result;
  }

  String _displayDirectoryNameForCourse({
    required String courseId,
    required String? courseName,
    required String? semesterId,
  }) {
    final baseName = _sanitizePathSegment(courseName ?? '');
    final identity = encodeFileStorageIdentity(courseId);
    if (baseName.isEmpty || baseName == '_') {
      return identity.isEmpty ? '_' : identity;
    }
    return identity.isEmpty ? baseName : '$baseName [$identity]';
  }

  String? _rebasePersistedPath(
    String? currentPath, {
    required String fromPrefix,
    required String toPrefix,
  }) {
    if (currentPath == null || currentPath.isEmpty) {
      return currentPath;
    }

    final normalizedCurrentPath = _normalizePathForComparison(currentPath);
    final normalizedFromPrefix = _normalizePathForComparison(fromPrefix);
    if (normalizedCurrentPath == normalizedFromPrefix) {
      return p.normalize(toPrefix);
    }

    final prefixWithSeparator = '$normalizedFromPrefix/';
    if (!normalizedCurrentPath.startsWith(prefixWithSeparator)) {
      return currentPath;
    }

    final suffix = normalizedCurrentPath.substring(prefixWithSeparator.length);
    if (suffix.isEmpty) {
      return p.normalize(toPrefix);
    }

    final suffixSegments = suffix
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    return p.joinAll([p.normalize(toPrefix), ...suffixSegments]);
  }

  String _normalizePathForComparison(String path) {
    var normalized = path.replaceAll('\\', '/');
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  String _sanitizePathSegment(String value) {
    final collapsedWhitespace = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    final withoutIllegalCharacters = collapsedWhitespace.replaceAll(
      RegExp(r'[\\/:*?"<>|\x00-\x1F]'),
      '_',
    );
    final withoutTrailingDotsOrSpaces = withoutIllegalCharacters.replaceFirst(
      RegExp(r'[\. ]+$'),
      '',
    );
    final normalized = withoutTrailingDotsOrSpaces.trim();
    if (normalized.isEmpty) {
      return '_';
    }

    const reservedDeviceNames = <String>{
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    };
    if (reservedDeviceNames.contains(normalized.toUpperCase())) {
      return '${normalized}_';
    }

    return normalized;
  }
}

final fileStorageWorkspaceServiceProvider =
    Provider<FileStorageWorkspaceService>((ref) {
      return FileStorageWorkspaceService(database: ref.watch(databaseProvider));
    });
