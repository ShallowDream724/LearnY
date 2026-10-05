part of 'archive_preview_service.dart';

const _archiveStagingPrefix = '.archive-pending-';

// Standalone entry points keep service closures (including storage/plugin
// callbacks) out of the object graph copied into a new isolate.
Future<_ArchiveInspection> _inspectArchiveInWorker(
  _ArchivePreviewWorker worker,
  String path,
  ArchiveNameDecodingMode mode,
) => Isolate.run(() => worker.inspect(path, mode));

Future<String> _materializeArchiveInWorker(
  _ArchivePreviewWorker worker,
  String source,
  String cache,
  String path,
  int? index,
) => Isolate.run(() => worker.materialize(source, cache, path, index));

Future<ArchiveExtractionResult> _extractArchiveInWorker(
  _ArchivePreviewWorker worker,
  String source,
  String cache,
  ArchiveNameDecodingMode mode,
) => Isolate.run(() => worker.extractAll(source, cache, mode));

String _archiveOutputPath(String root, String entryPath) => p.joinAll([
  root,
  ...entryPath
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(ArchivePreviewService._sanitizePathSegment),
]);

// Only paths, limits and lightweight metadata cross the isolate boundary.
// ArchiveFile objects retain a live input stream and stay in the worker.
class _ArchivePreviewWorker {
  const _ArchivePreviewWorker({
    required this.nameDecoder,
    required this.maxEntries,
    required this.maxBytes,
  });

  final ArchiveEntryNameDecoder nameDecoder;
  final int maxEntries;
  final int maxBytes;

  Future<_ArchiveDecodeContext> _decode(
    String path,
    ArchiveNameDecodingMode mode,
  ) => ArchivePreviewService._decodeArchiveContext(
    path,
    mode: mode,
    nameDecoder: nameDecoder,
    maxEntries: maxEntries,
  );

  Future<_ArchiveInspection> inspect(
    String path,
    ArchiveNameDecodingMode mode,
  ) async {
    final context = await _decode(path, mode);
    try {
      _validateSize(context);
      return _ArchiveInspection(
        decodedFiles: context.decodedFiles
            .map(
              (file) => _ArchiveEntryMetadata(
                fileIndex: file.fileIndex,
                decodedPath: file.decodedPath,
                size: file.archiveFile.size,
              ),
            )
            .toList(growable: false),
        canCompatibilityOpen: context.canCompatibilityOpen,
      );
    } finally {
      await context.input.close();
    }
  }

  Future<String> materialize(
    String sourcePath,
    String cachePath,
    String entryPath,
    int? index,
  ) async {
    final context = await _decode(sourcePath, ArchiveNameDecodingMode.standard);
    try {
      final files = context.decodedFiles;
      final file = index != null && index >= 0 && index < files.length
          ? files[index].archiveFile
          : files
                .firstWhere(
                  (file) => file.decodedPath == entryPath,
                  orElse: () => throw StateError('archive_entry_missing'),
                )
                .archiveFile;
      if (file.size > maxBytes) throw const FormatException('文件展开后体积过大');
      final outputPath = _archiveOutputPath(cachePath, entryPath);
      final outputFile = File(outputPath);
      if (await outputFile.exists() && await outputFile.length() == file.size) {
        await outputFile.setLastModified(DateTime.now());
        return outputPath;
      }
      await _withStagingDirectory(cachePath, (staging) async {
        await _writeFile(file, outputPath, p.join(staging.path, 'entry'));
      });
      return outputPath;
    } finally {
      await context.input.close();
    }
  }

  Future<ArchiveExtractionResult> extractAll(
    String sourcePath,
    String cachePath,
    ArchiveNameDecodingMode mode,
  ) async {
    final context = await _decode(sourcePath, mode);
    try {
      final totalBytes = _validateSize(context);
      await _withStagingDirectory(cachePath, (staging) async {
        for (final file in context.decodedFiles) {
          await _writeFile(
            file.archiveFile,
            _archiveOutputPath(cachePath, file.decodedPath),
            p.join(staging.path, '${file.fileIndex}'),
          );
        }
      });
      return ArchiveExtractionResult(
        fileCount: context.decodedFiles.length,
        totalBytes: totalBytes,
      );
    } finally {
      await context.input.close();
    }
  }

  int _validateSize(_ArchiveDecodeContext context) {
    var total = 0;
    for (final file in context.decodedFiles) {
      total += file.archiveFile.size;
      if (total > maxBytes) {
        throw const FormatException('压缩包展开后体积过大，暂不支持内置浏览');
      }
    }
    return total;
  }

  Future<void> _withStagingDirectory(
    String cachePath,
    Future<void> Function(Directory staging) action,
  ) async {
    final cache = Directory(cachePath);
    await cache.parent.create(recursive: true);
    // Keep pending output beside the cache on the same volume, so a completed
    // file can be published by rename and is never listed as extracted content.
    final staging = await cache.parent.createTemp(_archiveStagingPrefix);
    try {
      await action(staging);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<void> _writeFile(
    ArchiveFile file,
    String outputPath,
    String temporaryPath,
  ) async {
    final output = _CheckedArchiveOutput(temporaryPath, file.size);
    try {
      file.writeContent(output);
      if (output.length != file.size ||
          (file.crc32 != null && output.crc32 != file.crc32)) {
        throw const FormatException('压缩包文件内容校验失败');
      }
    } finally {
      await output.close();
    }
    final target = File(outputPath);
    await target.parent.create(recursive: true);
    await File(temporaryPath).rename(outputPath);
  }
}

class _ArchiveInspection {
  const _ArchiveInspection({
    required this.decodedFiles,
    required this.canCompatibilityOpen,
  });
  final List<_ArchiveEntryMetadata> decodedFiles;
  final bool canCompatibilityOpen;
}

class _ArchiveEntryMetadata {
  const _ArchiveEntryMetadata({
    required this.fileIndex,
    required this.decodedPath,
    required this.size,
  });
  final int fileIndex;
  final String decodedPath;
  final int size;
}

// Enforce the advertised size while streaming, instead of trusting ZIP headers
// or retaining decompressed bytes to verify the CRC after extraction.
class _CheckedArchiveOutput extends OutputFileStream {
  factory _CheckedArchiveOutput(String path, int maxLength) =>
      _CheckedArchiveOutput._(
        FileHandle(path, mode: FileAccess.write),
        maxLength,
      );

  _CheckedArchiveOutput._(this._handle, this.maxLength)
    : super.withFileHandle(_handle);

  final FileHandle _handle;
  final int maxLength;
  int _crc = 0xffffffff;
  int get crc32 => _crc ^ 0xffffffff;

  @override
  Future<void> close() async {
    try {
      flush();
    } finally {
      // OutputFileStream.close flushes before closing. Still close the handle
      // when a disk write fails during flush, so pending files can be removed.
      await _handle.close();
    }
  }

  void _checkLength(int added) {
    if (length + added > maxLength) {
      throw const FormatException('压缩包文件展开后超出声明大小');
    }
  }

  @override
  void writeByte(int value) {
    _checkLength(1);
    _crc = getCrc32Byte(_crc, value);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _checkLength(count);
    if (count == bytes.length) {
      _crc = getCrc32(bytes, crc32) ^ 0xffffffff;
    } else {
      for (var i = 0; i < count; i += 1) {
        _crc = getCrc32Byte(_crc, bytes[i]);
      }
    }
    super.writeBytes(bytes, length: count);
  }
}
