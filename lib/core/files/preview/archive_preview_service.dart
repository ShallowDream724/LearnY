import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../file_preview_registry.dart';
import 'archive_entry_name_decoder.dart';
import 'file_preview_models.dart';
import '../../services/file_storage_workspace_service.dart';

part 'archive_preview_worker.dart';

class ArchiveExtractionResult {
  const ArchiveExtractionResult({
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;
}

class ArchivePreviewService {
  const ArchivePreviewService({
    required FilePreviewRegistry registry,
    required Future<Directory> Function() resolveArchiveRootDirectory,
    ArchiveEntryNameDecoder nameDecoder = const ArchiveEntryNameDecoder(),
    this.maxInspectableEntries = 4000,
    this.maxInspectableBytes = 1024 * 1024 * 1024,
    this.maxCacheAge = const Duration(days: 7),
  }) : _registry = registry,
       _resolveArchiveRootDirectory = resolveArchiveRootDirectory,
       _nameDecoder = nameDecoder;

  final FilePreviewRegistry _registry;
  final Future<Directory> Function() _resolveArchiveRootDirectory;
  final ArchiveEntryNameDecoder _nameDecoder;
  final int maxInspectableEntries;
  final int maxInspectableBytes;
  final Duration maxCacheAge;

  // Shared across service instances so each cache has one writer at a time.
  static final _containerOperations = <String, Future<void>>{};
  static final _entryOperations = <String, Future<String>>{};
  static final _courseClears = <String, Future<void>>{};

  _ArchivePreviewWorker get _worker => _ArchivePreviewWorker(
    nameDecoder: _nameDecoder,
    maxEntries: maxInspectableEntries,
    maxBytes: maxInspectableBytes,
  );

  Future<ArchivePreparedFilePreview> inspect({
    required FilePreviewDescriptor descriptor,
    required String localPath,
    ArchiveNameDecodingMode nameDecodingMode = ArchiveNameDecodingMode.standard,
  }) async {
    await cleanupStaleExtractionCaches();

    final sourceFile = File(localPath);
    final compressedSizeBytes = await sourceFile.length();
    final worker = _worker;
    final context = await _inspectArchiveInWorker(
      worker,
      localPath,
      nameDecodingMode,
    );

    final entriesByPath = <String, ArchivePreviewEntry>{};
    var totalUncompressedBytes = 0;

    void putDirectory(String path) {
      if (path.isEmpty || entriesByPath.containsKey(path)) {
        return;
      }
      final parentPath = _parentArchivePath(path);
      entriesByPath[path] = ArchivePreviewEntry(
        path: path,
        displayName: p.posix.basename(path),
        parentPath: parentPath,
        depth: _archivePathDepth(path),
        isDirectory: true,
        uncompressedSizeBytes: 0,
        compressedSizeBytes: 0,
        previewDescriptor: null,
        childCount: 0,
      );
    }

    for (final file in context.decodedFiles) {
      final normalizedPath = file.decodedPath;
      if (normalizedPath.isEmpty) {
        continue;
      }

      final parts = normalizedPath.split('/');
      for (var index = 1; index < parts.length; index += 1) {
        putDirectory(parts.take(index).join('/'));
      }

      totalUncompressedBytes += file.size;
      if (totalUncompressedBytes > maxInspectableBytes) {
        throw const FormatException('压缩包展开后体积过大，暂不支持内置浏览');
      }

      final previewDescriptor = _registry.describe(
        fileName: p.posix.basename(normalizedPath),
      );
      entriesByPath[normalizedPath] = ArchivePreviewEntry(
        path: normalizedPath,
        displayName: p.posix.basename(normalizedPath),
        parentPath: _parentArchivePath(normalizedPath),
        depth: _archivePathDepth(normalizedPath),
        isDirectory: false,
        uncompressedSizeBytes: file.size,
        compressedSizeBytes: 0,
        previewDescriptor: previewDescriptor,
        childCount: 0,
        archiveFileIndex: file.fileIndex,
      );
    }

    final childCountByParent = <String, int>{};
    for (final entry in entriesByPath.values) {
      childCountByParent.update(
        entry.parentPath,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final sortedEntries =
        entriesByPath.values
            .map(
              (entry) => ArchivePreviewEntry(
                path: entry.path,
                displayName: entry.displayName,
                parentPath: entry.parentPath,
                depth: entry.depth,
                isDirectory: entry.isDirectory,
                uncompressedSizeBytes: entry.uncompressedSizeBytes,
                compressedSizeBytes: entry.compressedSizeBytes,
                previewDescriptor: entry.previewDescriptor,
                childCount: childCountByParent[entry.path] ?? 0,
                archiveFileIndex: entry.archiveFileIndex,
              ),
            )
            .toList()
          ..sort(_compareArchiveEntries);

    final fileCount = sortedEntries.where((entry) => entry.isFile).length;
    final directoryCount = sortedEntries
        .where((entry) => entry.isDirectory)
        .length;

    return ArchivePreparedFilePreview(
      descriptor: descriptor,
      document: ArchivePreviewDocument(
        entries: sortedEntries,
        fileCount: fileCount,
        directoryCount: directoryCount,
        compressedSizeBytes: compressedSizeBytes,
        uncompressedSizeBytes: totalUncompressedBytes,
        nameDecodingMode: nameDecodingMode,
        canCompatibilityOpen: context.canCompatibilityOpen,
      ),
    );
  }

  Future<String> materializeEntry({
    required String courseId,
    required String containerAssetKey,
    required String containerLocalPath,
    required ArchivePreviewEntry entry,
  }) async {
    if (entry.isDirectory) {
      throw ArgumentError.value(
        entry.path,
        'entry',
        'Directory entries cannot be materialized',
      );
    }

    await cleanupStaleExtractionCaches();

    final directory = await _containerCacheDirectory(
      courseId: courseId,
      containerAssetKey: containerAssetKey,
    );
    final outputPath = _archiveOutputPath(directory.path, entry.path);
    final operationKey =
        '$containerLocalPath\u0000$outputPath\u0000${entry.archiveFileIndex}';
    final existing = _entryOperations[operationKey];
    if (existing != null) return existing;
    final worker = _worker;
    final operation = _withContainerOperation(
      directory.path,
      () => _materializeArchiveInWorker(
        worker,
        containerLocalPath,
        directory.path,
        entry.path,
        entry.archiveFileIndex,
      ),
    );
    _entryOperations[operationKey] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_entryOperations[operationKey], operation)) {
        _entryOperations.remove(operationKey);
      }
    }
  }

  Future<ArchiveExtractionResult> extractAll({
    required String courseId,
    required String containerAssetKey,
    required String containerLocalPath,
    ArchiveNameDecodingMode nameDecodingMode = ArchiveNameDecodingMode.standard,
  }) async {
    final directory = await _containerCacheDirectory(
      courseId: courseId,
      containerAssetKey: containerAssetKey,
    );
    final worker = _worker;
    return _withContainerOperation(
      directory.path,
      () => _extractArchiveInWorker(
        worker,
        containerLocalPath,
        directory.path,
        nameDecodingMode,
      ),
    );
  }

  Future<void> clearExtractedContent({
    required String courseId,
    required String containerAssetKey,
  }) async {
    final directory = await _containerCacheDirectory(
      courseId: courseId,
      containerAssetKey: containerAssetKey,
    );
    await _withContainerOperation(directory.path, () async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
  }

  Future<void> clearCourseExtractedContent(String courseId) async {
    final root = await _archiveRootDirectory();
    final directory = Directory(
      p.join(root.path, _sanitizePathSegment(courseId)),
    );
    final previous = _courseClears[directory.path];
    // Capture preceding writers before publishing this barrier. Later writers
    // wait for it and must not be included in the work it waits for.
    final precedingWriters = _containerOperations.entries
        .where((entry) => p.isWithin(directory.path, entry.key))
        .map((entry) => entry.value)
        .toList(growable: false);
    final operation = Future<void>(() async {
      if (previous != null) await previous;
      await Future.wait(precedingWriters);
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _courseClears[directory.path] = settled;
    try {
      await operation;
    } finally {
      if (identical(_courseClears[directory.path], settled)) {
        _courseClears.remove(directory.path);
      }
    }
  }

  Future<Set<String>> listMaterializedEntries({
    required String courseId,
    required String containerAssetKey,
  }) async {
    final directory = await _containerCacheDirectory(
      courseId: courseId,
      containerAssetKey: containerAssetKey,
    );
    if (!await directory.exists()) {
      return const <String>{};
    }

    final entries = <String>{};
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File) {
        continue;
      }
      final relativePath = p.relative(entity.path, from: directory.path);
      final normalized = _normalizeArchivePath(relativePath);
      if (normalized.isNotEmpty) {
        entries.add(normalized);
      }
    }
    return entries;
  }

  Future<void> cleanupStaleExtractionCaches() async {
    final root = await _archiveRootDirectory();
    if (!await root.exists()) {
      return;
    }

    final now = DateTime.now();
    await for (final courseDir in root.list()) {
      if (courseDir is! Directory) {
        continue;
      }
      if (_courseClears.containsKey(courseDir.path)) continue;
      await for (final cacheDir in courseDir.list()) {
        if (cacheDir is! Directory) {
          continue;
        }
        if (p.basename(cacheDir.path).startsWith(_archiveStagingPrefix)) {
          continue;
        }
        await _withContainerOperation(cacheDir.path, () async {
          if (!await cacheDir.exists()) return;
          final stat = await cacheDir.stat();
          if (now.difference(stat.modified) > maxCacheAge) {
            await cacheDir.delete(recursive: true);
          }
        });
      }
    }
  }

  static Future<T> _withContainerOperation<T>(
    String path,
    Future<T> Function() action,
  ) async {
    final previous = _containerOperations[path];
    final courseClear = _courseClears[p.dirname(path)];
    final operation = Future<void>(() async {
      if (previous != null) await previous;
      if (courseClear != null) await courseClear;
    }).then((_) => action());
    // A failed writer must not prevent a later retry or cleanup.
    final settled = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _containerOperations[path] = settled;
    try {
      return await operation;
    } finally {
      if (identical(_containerOperations[path], settled)) {
        _containerOperations.remove(path);
      }
    }
  }

  static Future<_ArchiveDecodeContext> _decodeArchiveContext(
    String localPath, {
    required ArchiveNameDecodingMode mode,
    required ArchiveEntryNameDecoder nameDecoder,
    required int maxEntries,
  }) async {
    final input = InputFileStream(localPath);
    try {
      final decoder = ZipDecoder();
      final archive = decoder.decodeStream(input);
      if (archive.files.length > maxEntries) {
        throw const FormatException('压缩包条目过多，暂不支持内置浏览');
      }
      final directory = decoder.directory;
      final bytes = input
          .subset(
            position: directory.centralDirectoryOffset,
            length: directory.centralDirectorySize,
          )
          .toUint8List();
      final fileEntries = archive.files
          .where((candidate) => candidate.isFile)
          .toList(growable: false);
      final standardPlan = nameDecoder.decode(
        bytes: bytes,
        decoder: decoder,
        mode: ArchiveNameDecodingMode.standard,
        bytesOffset: directory.centralDirectoryOffset,
      );
      final compatibilityPlan = nameDecoder.decode(
        bytes: bytes,
        decoder: decoder,
        mode: ArchiveNameDecodingMode.compatibility,
        bytesOffset: directory.centralDirectoryOffset,
      );

      final selectedPlan = mode == ArchiveNameDecodingMode.compatibility
          ? compatibilityPlan
          : standardPlan;
      final decodedFiles = _resolveDecodedFiles(fileEntries, selectedPlan);

      return _ArchiveDecodeContext(
        input: input,
        decodedFiles: decodedFiles,
        canCompatibilityOpen: _plansDiffer(standardPlan, compatibilityPlan),
      );
    } catch (_) {
      await input.close();
      rethrow;
    }
  }

  static List<_DecodedArchiveFile> _resolveDecodedFiles(
    List<ArchiveFile> fileEntries,
    ArchiveNameDecodingPlan plan,
  ) {
    if (plan.entries.length != fileEntries.length) {
      return _fallbackDecodedFiles(fileEntries);
    }

    final usedPaths = <String>{};
    final decodedFiles = <_DecodedArchiveFile>[];

    for (final decodedEntry in plan.entries) {
      if (decodedEntry.fileIndex < 0 ||
          decodedEntry.fileIndex >= fileEntries.length) {
        return _fallbackDecodedFiles(fileEntries);
      }
      final archiveFile = fileEntries[decodedEntry.fileIndex];
      var normalizedPath = _normalizeArchivePath(decodedEntry.decodedPath);
      if (normalizedPath.isEmpty) {
        normalizedPath = _fallbackDecodedPath(
          archiveFile.name,
          fileIndex: decodedEntry.fileIndex,
        );
      }
      final uniquePath = _ensureUniqueArchivePath(normalizedPath, usedPaths);
      usedPaths.add(uniquePath);
      decodedFiles.add(
        _DecodedArchiveFile(
          fileIndex: decodedEntry.fileIndex,
          decodedPath: uniquePath,
          archiveFile: archiveFile,
        ),
      );
    }

    return decodedFiles;
  }

  static List<_DecodedArchiveFile> _fallbackDecodedFiles(
    List<ArchiveFile> fileEntries,
  ) {
    final usedPaths = <String>{};
    final decodedFiles = <_DecodedArchiveFile>[];
    for (var index = 0; index < fileEntries.length; index += 1) {
      final archiveFile = fileEntries[index];
      final fallbackPath = _ensureUniqueArchivePath(
        _fallbackDecodedPath(archiveFile.name, fileIndex: index),
        usedPaths,
      );
      usedPaths.add(fallbackPath);
      decodedFiles.add(
        _DecodedArchiveFile(
          fileIndex: index,
          decodedPath: fallbackPath,
          archiveFile: archiveFile,
        ),
      );
    }
    return decodedFiles;
  }

  static String _fallbackDecodedPath(String rawPath, {required int fileIndex}) {
    final normalized = _normalizeArchivePath(rawPath);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return 'entry_$fileIndex';
  }

  static bool _plansDiffer(
    ArchiveNameDecodingPlan standardPlan,
    ArchiveNameDecodingPlan compatibilityPlan,
  ) {
    if (standardPlan.entries.length != compatibilityPlan.entries.length) {
      return false;
    }
    for (var index = 0; index < standardPlan.entries.length; index += 1) {
      if (_normalizeArchivePath(standardPlan.entries[index].decodedPath) !=
          _normalizeArchivePath(compatibilityPlan.entries[index].decodedPath)) {
        return true;
      }
    }
    return false;
  }

  Future<Directory> _archiveRootDirectory() async {
    return _resolveArchiveRootDirectory();
  }

  Future<Directory> _containerCacheDirectory({
    required String courseId,
    required String containerAssetKey,
  }) async {
    final root = await _archiveRootDirectory();
    return Directory(
      p.join(
        root.path,
        _sanitizePathSegment(courseId),
        _sanitizePathSegment(containerAssetKey),
      ),
    );
  }

  static String _normalizeArchivePath(String rawPath) {
    var normalized = rawPath.replaceAll('\\', '/').trim();
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    normalized = p.posix.normalize(normalized);
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }
    final safeSegments = normalized
        .split('/')
        .where(
          (segment) => segment.isNotEmpty && segment != '.' && segment != '..',
        )
        .toList();
    return safeSegments.join('/');
  }

  static String _ensureUniqueArchivePath(String path, Set<String> usedPaths) {
    if (!usedPaths.contains(path)) {
      return path;
    }

    final directory = _parentArchivePath(path);
    final extension = p.posix.extension(path);
    final basename = p.posix.basenameWithoutExtension(path);
    var suffix = 2;

    while (true) {
      final candidateName = '$basename ($suffix)$extension';
      final candidate = directory.isEmpty
          ? candidateName
          : '$directory/$candidateName';
      if (!usedPaths.contains(candidate)) {
        return candidate;
      }
      suffix += 1;
    }
  }

  static String _sanitizePathSegment(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    return sanitized.isEmpty ? '_' : sanitized;
  }

  static String _parentArchivePath(String path) {
    final dirname = p.posix.dirname(path);
    return dirname == '.' ? '' : dirname;
  }

  static int _archivePathDepth(String path) {
    if (path.isEmpty) {
      return 0;
    }
    return path.split('/').length - 1;
  }

  static int _compareArchiveEntries(
    ArchivePreviewEntry a,
    ArchivePreviewEntry b,
  ) {
    final parentCompare = a.parentPath.compareTo(b.parentPath);
    if (parentCompare != 0) {
      return parentCompare;
    }
    if (a.isDirectory != b.isDirectory) {
      return a.isDirectory ? -1 : 1;
    }
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }
}

class _ArchiveDecodeContext {
  const _ArchiveDecodeContext({
    required this.input,
    required this.decodedFiles,
    required this.canCompatibilityOpen,
  });

  final InputFileStream input;

  final List<_DecodedArchiveFile> decodedFiles;
  final bool canCompatibilityOpen;
}

class _DecodedArchiveFile {
  const _DecodedArchiveFile({
    required this.fileIndex,
    required this.decodedPath,
    required this.archiveFile,
  });

  final int fileIndex;
  final String decodedPath;
  final ArchiveFile archiveFile;
}

final archivePreviewServiceProvider = Provider<ArchivePreviewService>((ref) {
  return ArchivePreviewService(
    registry: ref.watch(filePreviewRegistryProvider),
    resolveArchiveRootDirectory: ref
        .watch(fileStorageWorkspaceServiceProvider)
        .ensureArchiveRootDirectory,
  );
});
