import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_preview_registry.dart';
import 'package:learn_y/core/files/preview/archive_preview_service.dart';
import 'package:learn_y/core/files/preview/archive_entry_name_decoder.dart';
import 'package:learn_y/core/files/preview/file_preview_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory documentsDirectory;

  setUp(() async {
    documentsDirectory = await Directory.systemTemp.createTemp(
      'learny-archive-preview-',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return documentsDirectory.path;
          }
          return documentsDirectory.path;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  });

  group('ArchivePreviewService', () {
    const registry = FilePreviewRegistry();
    late ArchivePreviewService service;

    setUp(() {
      service = ArchivePreviewService(
        registry: registry,
        resolveArchiveRootDirectory: () async =>
            Directory('${documentsDirectory.path}/LearnY Files/.archive'),
      );
    });

    test('inspects zip entries and marks previewable formats', () async {
      final zipPath = await _writeArchive(
        Archive()
          ..add(ArchiveFile.string('docs/readme.txt', 'hello'))
          ..add(ArchiveFile.string('slides/week1.pdf', 'pdf')),
        suffix: '.zip',
      );

      final preview = await service.inspect(
        descriptor: registry.describe(fileName: 'bundle.zip'),
        localPath: zipPath,
      );

      expect(preview.document.fileCount, 2);
      expect(preview.document.directoryCount, 2);
      expect(
        preview.document.nameDecodingMode,
        ArchiveNameDecodingMode.standard,
      );
      expect(preview.document.canCompatibilityOpen, isFalse);
      expect(
        preview.document.entries.map((entry) => entry.path),
        containsAll(<String>[
          'docs',
          'docs/readme.txt',
          'slides',
          'slides/week1.pdf',
        ]),
      );
    });

    test('materializes a zip entry into the archive cache workspace', () async {
      final zipPath = await _writeArchive(
        Archive()..add(ArchiveFile.string('nested/notes.md', '# LearnY')),
        suffix: '.zip',
      );

      final preview = await service.inspect(
        descriptor: registry.describe(fileName: 'bundle.zip'),
        localPath: zipPath,
      );
      final entry = preview.document.entries.firstWhere(
        (candidate) => candidate.path == 'nested/notes.md',
      );

      final extractedPath = await service.materializeEntry(
        courseId: 'course-1',
        containerAssetKey: 'archive:course-1:bundle',
        containerLocalPath: zipPath,
        entry: entry,
      );

      final extractedFile = File(extractedPath);
      expect(await extractedFile.exists(), isTrue);
      expect(await extractedFile.readAsString(), '# LearnY');
      expect(
        extractedPath.replaceAll('\\', '/'),
        contains(
          '/LearnY Files/.archive/course-1/archive_course-1_bundle/nested/notes.md',
        ),
      );

      final materialized = await service.listMaterializedEntries(
        courseId: 'course-1',
        containerAssetKey: 'archive:course-1:bundle',
      );
      expect(materialized, contains('nested/notes.md'));
    });

    test('decodes gbk zip entry names into readable chinese paths', () async {
      final zipPath = await _writeStoredZip(
        fileNameBytes: Uint8List.fromList(gbk.encode('测试资料.txt')),
        contentBytes: Uint8List.fromList('hello'.codeUnits),
      );

      final preview = await service.inspect(
        descriptor: registry.describe(fileName: 'bundle.zip'),
        localPath: zipPath,
      );

      expect(
        preview.document.entries.map((entry) => entry.path),
        contains('测试资料.txt'),
      );
      final fileEntry = preview.document.entries.firstWhere(
        (entry) => entry.path == '测试资料.txt',
      );
      expect(fileEntry.archiveFileIndex, 0);
      final extracted = await service.materializeEntry(
        courseId: 'c',
        containerAssetKey: 'gbk',
        containerLocalPath: zipPath,
        entry: fileEntry,
      );
      expect(await File(extracted).readAsString(), 'hello');
      expect(extracted, contains('测试资料.txt'));
    });

    test('archive decoding runs outside the caller isolate', () async {
      final zipPath = await _writeArchive(
        Archive()..add(ArchiveFile.string('notes.txt', 'hello')),
        suffix: '.zip',
      );
      final background = ArchivePreviewService(
        registry: registry,
        nameDecoder: _WorkerOnlyNameDecoder(Isolate.current.debugName),
        resolveArchiveRootDirectory: () async => documentsDirectory,
      );
      final preview = await background.inspect(
        descriptor: registry.describe(fileName: 'bundle.zip'),
        localPath: zipPath,
      );
      final extracted = await background.materializeEntry(
        courseId: 'c',
        containerAssetKey: 'zip',
        containerLocalPath: zipPath,
        entry: preview.document.entries.single,
      );
      expect(await File(extracted).readAsString(), 'hello');
      expect(
        (await background.extractAll(
          courseId: 'c',
          containerAssetKey: 'zip',
          containerLocalPath: zipPath,
        )).fileCount,
        1,
      );
    });

    test(
      'streamed extraction preserves multiple files and releases the source',
      () async {
        final zipPath = await _writeArchive(
          Archive()
            ..add(ArchiveFile.string('a.txt', 'A' * (2 * 1024 * 1024)))
            ..add(ArchiveFile.string('b.txt', 'B' * (2 * 1024 * 1024)))
            ..add(ArchiveFile.string('empty.txt', '')),
          suffix: '.zip',
        );
        final result = await service.extractAll(
          courseId: 'c',
          containerAssetKey: 'zip',
          containerLocalPath: zipPath,
        );
        expect(result.fileCount, 3);
        expect(result.totalBytes, 4 * 1024 * 1024);
        final cache = Directory(
          '${documentsDirectory.path}/LearnY Files/.archive/c/zip',
        );
        expect(
          await File('${cache.path}/a.txt').readAsString(),
          'A' * (2 * 1024 * 1024),
        );
        expect(await File('${cache.path}/empty.txt').length(), 0);
        await File(zipPath).rename('$zipPath.done');
      },
    );

    test('extract all observes the same size limit as preview', () async {
      final zipPath = await _writeArchive(
        Archive()..add(ArchiveFile.string('a.txt', '12345')),
        suffix: '.zip',
      );
      final limited = ArchivePreviewService(
        registry: registry,
        maxInspectableBytes: 4,
        resolveArchiveRootDirectory: () async => documentsDirectory,
      );
      await expectLater(
        limited.extractAll(
          courseId: 'c',
          containerAssetKey: 'z',
          containerLocalPath: zipPath,
        ),
        throwsFormatException,
      );
    });

    test(
      'concurrent requests publish one complete entry and preserve empty files',
      () async {
        final zipPath = await _writeArchive(
          Archive()
            ..add(ArchiveFile.string('notes.txt', 'A' * (2 * 1024 * 1024)))
            ..add(ArchiveFile.string('empty.txt', '')),
          suffix: '.zip',
        );
        final preview = await service.inspect(
          descriptor: registry.describe(fileName: 'bundle.zip'),
          localPath: zipPath,
        );
        final entry = preview.document.entries.firstWhere(
          (entry) => entry.path == 'notes.txt',
        );
        final paths = await Future.wait(
          List.generate(
            8,
            (_) => service.materializeEntry(
              courseId: 'c',
              containerAssetKey: 'zip',
              containerLocalPath: zipPath,
              entry: entry,
            ),
          ),
        );
        expect(paths.toSet(), hasLength(1));
        expect(await File(paths.first).readAsString(), 'A' * (2 * 1024 * 1024));
        final empty = preview.document.entries.firstWhere(
          (entry) => entry.path == 'empty.txt',
        );
        final emptyPath = await service.materializeEntry(
          courseId: 'c',
          containerAssetKey: 'zip',
          containerLocalPath: zipPath,
          entry: empty,
        );
        expect(await File(emptyPath).length(), 0);
        expect(
          await service.listMaterializedEntries(
            courseId: 'c',
            containerAssetKey: 'zip',
          ),
          unorderedEquals(['notes.txt', 'empty.txt']),
        );
      },
    );

    test('corrupt output is discarded and extraction can retry', () async {
      final name = Uint8List.fromList('notes.txt'.codeUnits);
      final zipPath = await _writeStoredZip(
        fileNameBytes: name,
        contentBytes: Uint8List.fromList('hello'.codeUnits),
      );
      final preview = await service.inspect(
        descriptor: registry.describe(fileName: 'bundle.zip'),
        localPath: zipPath,
      );
      final handle = await File(zipPath).open(mode: FileMode.writeOnlyAppend);
      await handle.setPosition(30 + name.length);
      await handle.writeByte('X'.codeUnitAt(0));
      await handle.close();
      final entry = preview.document.entries.single;
      Future<String> extract() => service.materializeEntry(
        courseId: 'c',
        containerAssetKey: 'zip',
        containerLocalPath: zipPath,
        entry: entry,
      );
      await expectLater(extract(), throwsFormatException);
      expect(
        await service.listMaterializedEntries(
          courseId: 'c',
          containerAssetKey: 'zip',
        ),
        isEmpty,
      );
      final repair = await File(zipPath).open(mode: FileMode.writeOnlyAppend);
      await repair.setPosition(30 + name.length);
      await repair.writeByte('h'.codeUnitAt(0));
      await repair.close();
      expect(await File(await extract()).readAsString(), 'hello');
      final course = Directory(
        '${documentsDirectory.path}/LearnY Files/.archive/c',
      );
      expect(
        await course
            .list()
            .where((entity) => entity.path.contains('.archive-pending-'))
            .length,
        0,
      );
      await File(zipPath).rename('$zipPath.done');
    });

    test(
      'concurrent course clears and writers settle without losing the barrier',
      () async {
        final zipPath = await _writeArchive(
          Archive()..add(ArchiveFile.string('notes.txt', 'hello')),
          suffix: '.zip',
        );
        final preview = await service.inspect(
          descriptor: registry.describe(fileName: 'bundle.zip'),
          localPath: zipPath,
        );
        Future<String> write() => service.materializeEntry(
          courseId: 'c',
          containerAssetKey: 'zip',
          containerLocalPath: zipPath,
          entry: preview.document.entries.single,
        );
        await write();
        await Future.wait<Object?>([
          service.clearCourseExtractedContent('c'),
          service.clearCourseExtractedContent('c'),
          write(),
          service.cleanupStaleExtractionCaches(),
        ]).timeout(const Duration(seconds: 10));
        expect(await File(await write()).readAsString(), 'hello');
      },
    );
  });
}

class _WorkerOnlyNameDecoder extends ArchiveEntryNameDecoder {
  const _WorkerOnlyNameDecoder(this.callerName);
  final String? callerName;

  @override
  ArchiveNameDecodingPlan decode({
    required Uint8List bytes,
    required ZipDecoder decoder,
    required ArchiveNameDecodingMode mode,
    int bytesOffset = 0,
  }) {
    if (Isolate.current.debugName == callerName) {
      throw StateError('ZIP decoding blocked the caller isolate');
    }
    return super.decode(
      bytes: bytes,
      decoder: decoder,
      mode: mode,
      bytesOffset: bytesOffset,
    );
  }
}

Future<String> _writeArchive(Archive archive, {required String suffix}) async {
  final directory = await Directory.systemTemp.createTemp(
    'learny-archive-source-',
  );
  final file = File('${directory.path}/preview$suffix');
  final bytes = ZipEncoder().encodeBytes(archive);
  await file.writeAsBytes(bytes, flush: true);

  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  return file.path;
}

Future<String> _writeStoredZip({
  required Uint8List fileNameBytes,
  required Uint8List contentBytes,
}) async {
  final directory = await Directory.systemTemp.createTemp(
    'learny-archive-charset-',
  );
  final file = File('${directory.path}/encoded.zip');
  final bytes = _encodeStoredZip(
    fileNameBytes: fileNameBytes,
    contentBytes: contentBytes,
  );
  await file.writeAsBytes(bytes, flush: true);

  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  return file.path;
}

Uint8List _encodeStoredZip({
  required Uint8List fileNameBytes,
  required Uint8List contentBytes,
}) {
  final crc = getCrc32(contentBytes);
  final localHeader = BytesBuilder();
  _writeUint32(localHeader, 0x04034b50);
  _writeUint16(localHeader, 20);
  _writeUint16(localHeader, 0);
  _writeUint16(localHeader, 0);
  _writeUint16(localHeader, 0);
  _writeUint16(localHeader, 0);
  _writeUint32(localHeader, crc);
  _writeUint32(localHeader, contentBytes.length);
  _writeUint32(localHeader, contentBytes.length);
  _writeUint16(localHeader, fileNameBytes.length);
  _writeUint16(localHeader, 0);
  localHeader.add(fileNameBytes);
  localHeader.add(contentBytes);

  final centralDirectory = BytesBuilder();
  _writeUint32(centralDirectory, 0x02014b50);
  _writeUint16(centralDirectory, 20);
  _writeUint16(centralDirectory, 20);
  _writeUint16(centralDirectory, 0);
  _writeUint16(centralDirectory, 0);
  _writeUint16(centralDirectory, 0);
  _writeUint16(centralDirectory, 0);
  _writeUint32(centralDirectory, crc);
  _writeUint32(centralDirectory, contentBytes.length);
  _writeUint32(centralDirectory, contentBytes.length);
  _writeUint16(centralDirectory, fileNameBytes.length);
  _writeUint16(centralDirectory, 0);
  _writeUint16(centralDirectory, 0);
  _writeUint16(centralDirectory, 0);
  _writeUint16(centralDirectory, 0);
  _writeUint32(centralDirectory, 0);
  _writeUint32(centralDirectory, 0);
  centralDirectory.add(fileNameBytes);

  final eocd = BytesBuilder();
  _writeUint32(eocd, 0x06054b50);
  _writeUint16(eocd, 0);
  _writeUint16(eocd, 0);
  _writeUint16(eocd, 1);
  _writeUint16(eocd, 1);
  _writeUint32(eocd, centralDirectory.length);
  _writeUint32(eocd, localHeader.length);
  _writeUint16(eocd, 0);

  return Uint8List.fromList([
    ...localHeader.toBytes(),
    ...centralDirectory.toBytes(),
    ...eocd.toBytes(),
  ]);
}

void _writeUint16(BytesBuilder builder, int value) {
  builder.add([value & 0xFF, (value >> 8) & 0xFF]);
}

void _writeUint32(BytesBuilder builder, int value) {
  builder.add([
    value & 0xFF,
    (value >> 8) & 0xFF,
    (value >> 16) & 0xFF,
    (value >> 24) & 0xFF,
  ]);
}
