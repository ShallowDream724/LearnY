import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../file_preview_registry.dart';
import 'archive_entry_name_decoder.dart';
import 'file_preview_models.dart';
import '../../services/file_storage_workspace_service.dart';

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

  Future<ArchivePreparedFilePreview> inspect({
    required FilePreviewDescriptor descriptor,
    required String localPath,
    ArchiveNameDecodingMode nameDecodingMode = ArchiveNameDecodingMode.standard,
  }) async {
    await cleanupStaleExtractionCaches();

    final sourceFile = File(localPath);
    final compressedSizeBytes = await sourceFile.length();
    final context = await _decodeArchiveContext(
      localPath,
      mode: nameDecodingMode,
    );

    if (context.decodedFiles.length > maxInspectableEntries) {
      throw const FormatException('压缩包条目过多，暂不支持内置浏览');
    }

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

      totalUncompressedBytes += file.archiveFile.size;
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
        uncompressedSizeBytes: file.archiveFile.size,
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

    final archive = await _decodeArchive(containerLocalPath);
    final fileEntries = archive.files
        .where((candidate) => candidate.isFile)
        .toList(growable: false);

    ArchiveFile archiveFile;
    final archiveFileIndex = entry.archiveFileIndex;
    if (archiveFileIndex != null &&
        archiveFileIndex >= 0 &&
        archiveFileIndex < fileEntries.length) {
      archiveFile = fileEntries[archiveFileIndex];
    } else {
      archiveFile = fileEntries.firstWhere(
        (candidate) => _normalizeArchivePath(candidate.name) == entry.path,
        orElse: () => throw StateError('archive_entry_missing'),
      );
    }

    final bytes = archiveFile.readBytes();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('archive_entry_empty');
    }

    final outputPath = await _outputPathForEntry(
      courseId: courseId,
      containerAssetKey: containerAssetKey,
      entryPath: entry.path,
    );
    final file = File(outputPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    if (await file.exists() && await file.length() == bytes.length) {
      await file.setLastModified(DateTime.now());
      return file.path;
    }

    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<ArchiveExtractionResult> extractAll({
    required String courseId,
    required String containerAssetKey,
    required String containerLocalPath,
    ArchiveNameDecodingMode nameDecodingMode = ArchiveNameDecodingMode.standard,
  }) async {
    final context = await _decodeArchiveContext(
      containerLocalPath,
      mode: nameDecodingMode,
    );
    var fileCount = 0;
    var totalBytes = 0;

    for (final file in context.decodedFiles) {
      final bytes = file.archiveFile.readBytes();
      if (bytes == null || bytes.isEmpty) {
        continue;
      }

      final outputPath = await _outputPathForEntry(
        courseId: courseId,
        containerAssetKey: containerAssetKey,
        entryPath: file.decodedPath,
      );
      final fileOnDisk = File(outputPath);
      if (!await fileOnDisk.parent.exists()) {
        await fileOnDisk.parent.create(recursive: true);
      }
      await fileOnDisk.writeAsBytes(bytes, flush: true);
      fileCount += 1;
      totalBytes += bytes.length;
    }

    return ArchiveExtractionResult(
      fileCount: fileCount,
      totalBytes: totalBytes,
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
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<void> clearCourseExtractedContent(String courseId) async {
    final root = await _archiveRootDirectory();
    final directory = Directory(
      p.join(root.path, _sanitizePathSegment(courseId)),
    );
    if (await directory.exists()) {
      await directory.delete(recursive: true);
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
      await for (final cacheDir in courseDir.list()) {
        if (cacheDir is! Directory) {
          continue;
        }
        final stat = await cacheDir.stat();
        if (now.difference(stat.modified) > maxCacheAge) {
          await cacheDir.delete(recursive: true);
        }
      }
    }
  }

  Future<Archive> _decodeArchive(String localPath) async {
    final bytes = await File(localPath).readAsBytes();
    return ZipDecoder().decodeBytes(bytes);
  }

  Future<_ArchiveDecodeContext> _decodeArchiveContext(
    String localPath, {
    required ArchiveNameDecodingMode mode,
  }) async {
    final bytes = await File(localPath).readAsBytes();
    final decoder = ZipDecoder();
    final archive = decoder.decodeBytes(bytes);
    final fileEntries = archive.files
        .where((candidate) => candidate.isFile)
        .toList(growable: false);
    final standardPlan = _nameDecoder.decode(
      bytes: bytes,
      decoder: decoder,
      mode: ArchiveNameDecodingMode.standard,
    );
    final compatibilityPlan = _nameDecoder.decode(
      bytes: bytes,
      decoder: decoder,
      mode: ArchiveNameDecodingMode.compatibility,
    );

    final selectedPlan = mode == ArchiveNameDecodingMode.compatibility
        ? compatibilityPlan
        : standardPlan;
    final decodedFiles = _resolveDecodedFiles(fileEntries, selectedPlan);

    return _ArchiveDecodeContext(
      decodedFiles: decodedFiles,
      canCompatibilityOpen: _plansDiffer(standardPlan, compatibilityPlan),
    );
  }

  List<_DecodedArchiveFile> _resolveDecodedFiles(
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

  List<_DecodedArchiveFile> _fallbackDecodedFiles(
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

  String _fallbackDecodedPath(String rawPath, {required int fileIndex}) {
    final normalized = _normalizeArchivePath(rawPath);
    if (normalized.isNotEmpty) {
      return normalized;
    }
    return 'entry_$fileIndex';
  }

  bool _plansDiffer(
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

  Future<String> _outputPathForEntry({
    required String courseId,
    required String containerAssetKey,
    required String entryPath,
  }) async {
    final containerDir = await _containerCacheDirectory(
      courseId: courseId,
      containerAssetKey: containerAssetKey,
    );
    final safeSegments = entryPath
        .split('/')
        .where((segment) => segment.isNotEmpty)
        .map(_sanitizePathSegment)
        .toList();
    return p.joinAll([containerDir.path, ...safeSegments]);
  }

  String _normalizeArchivePath(String rawPath) {
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

  String _ensureUniqueArchivePath(String path, Set<String> usedPaths) {
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

  String _sanitizePathSegment(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
        .trim();
    return sanitized.isEmpty ? '_' : sanitized;
  }

  String _parentArchivePath(String path) {
    final dirname = p.posix.dirname(path);
    return dirname == '.' ? '' : dirname;
  }

  int _archivePathDepth(String path) {
    if (path.isEmpty) {
      return 0;
    }
    return path.split('/').length - 1;
  }

  int _compareArchiveEntries(ArchivePreviewEntry a, ArchivePreviewEntry b) {
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
    required this.decodedFiles,
    required this.canCompatibilityOpen,
  });

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
