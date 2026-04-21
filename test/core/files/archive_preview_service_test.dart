import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:charset/charset.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_preview_registry.dart';
import 'package:learn_y/core/files/preview/archive_preview_service.dart';
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
    });
  });
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
