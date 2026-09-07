import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/files/cached_asset_repository.dart';
import 'package:learn_y/core/providers/api_client_provider.dart';
import 'package:learn_y/core/providers/app_providers.dart';
import 'package:learn_y/core/services/file_download_service.dart';
import 'package:learn_y/core/services/file_storage_workspace_service.dart';

void main() {
  group('DownloadedPayloadInspector', () {
    const inspector = DownloadedPayloadInspector();

    test('rejects session-expired html payloads for non-html files', () async {
      final file = await _writeTempFile(
        'login_timeout<script>location.href="/login"</script>',
      );

      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      final result = await inspector.inspect(
        file: file,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        }),
        statusCode: 200,
        expectedFileType: 'pdf',
      );

      expect(result.isValid, isFalse);
      expect(result.looksLikeSessionExpired, isTrue);
    });

    test('allows normal small text payloads for text files', () async {
      final file = await _writeTempFile('hello from learny');

      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      final result = await inspector.inspect(
        file: file,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        }),
        statusCode: 200,
        expectedFileType: 'txt',
      );

      expect(result.isValid, isTrue);
      expect(result.looksLikeSessionExpired, isFalse);
    });
  });

  group('FileDownloadNotifier', () {
    test('stores same-title assets at distinct identity-based paths', () async {
      final fixture = await _DownloadFixture.create();
      addTearDown(fixture.dispose);

      await fixture.notifier.downloadAsset(
        assetKey: 'notification:course-a:asset-1',
        courseId: 'course-a',
        downloadUrl: 'https://example.test/first',
        fileName: 'lecture.pdf',
        fileType: 'pdf',
      );
      await fixture.notifier.downloadAsset(
        assetKey: 'notification:course-a:asset-2',
        courseId: 'course-a',
        downloadUrl: 'https://example.test/second',
        fileName: 'lecture.pdf',
        fileType: 'pdf',
      );

      final first = await fixture.cachedAssets.getAsset(
        'notification:course-a:asset-1',
      );
      final second = await fixture.cachedAssets.getAsset(
        'notification:course-a:asset-2',
      );
      expect(first, isNotNull);
      expect(second, isNotNull);
      expect(first!.localPath, isNot(second!.localPath));
      expect(await File(first.localPath).readAsString(), 'first payload');
      expect(await File(second.localPath).readAsString(), 'second payload');
      expect(
        File(first.localPath).uri.pathSegments.last,
        startsWith('lecture ['),
      );
    });

    test('failed replacement preserves an existing valid download', () async {
      final fixture = await _DownloadFixture.create(
        inspector: const _RejectingPayloadInspector(),
      );
      addTearDown(fixture.dispose);

      final courseDirectory = await fixture.workspace.ensureCourseDirectory(
        courseId: 'course-a',
      );
      final existingFile = File(
        '${courseDirectory.path}${Platform.pathSeparator}lecture [asset-1].pdf',
      );
      await existingFile.writeAsString('existing valid payload');
      await fixture.cachedAssets.saveDownloadedAsset(
        assetKey: 'asset-1',
        courseId: 'course-a',
        title: 'lecture.pdf',
        fileType: 'pdf',
        localPath: existingFile.path,
        fileSizeBytes: await existingFile.length(),
      );

      await fixture.notifier.downloadAsset(
        assetKey: 'asset-1',
        courseId: 'course-a',
        downloadUrl: 'https://example.test/replacement',
        fileName: 'lecture.pdf',
        fileType: 'pdf',
      );

      expect(await existingFile.readAsString(), 'existing valid payload');
      expect(
        fixture.notifier.getFileState('asset-1').status,
        DownloadStatus.downloaded,
      );
      expect(
        (await fixture.cachedAssets.getAsset('asset-1'))?.localPath,
        existingFile.path,
      );
      final stagedFiles = await courseDirectory
          .list()
          .where((entity) => entity.path.contains('.learny-download-'))
          .toList();
      expect(stagedFiles, isEmpty);
    });
  });
}

Future<File> _writeTempFile(String content) async {
  final directory = await Directory.systemTemp.createTemp('learny-download-');
  final file = File('${directory.path}/payload.bin');
  await file.writeAsString(content);
  return file;
}

class _DownloadFixture {
  _DownloadFixture({
    required this.database,
    required this.documentsDirectory,
    required this.api,
    required this.container,
    required this.workspace,
  });

  final AppDatabase database;
  final Directory documentsDirectory;
  final Learn2018Helper api;
  final ProviderContainer container;
  final FileStorageWorkspaceService workspace;

  FileDownloadNotifier get notifier =>
      container.read(fileDownloadProvider.notifier);
  CachedAssetRepository get cachedAssets =>
      container.read(cachedAssetRepositoryProvider);

  static Future<_DownloadFixture> create({
    DownloadedPayloadInspector inspector = const DownloadedPayloadInspector(),
  }) async {
    final database = AppDatabase(NativeDatabase.memory());
    final documentsDirectory = await Directory.systemTemp.createTemp(
      'learny-download-service-',
    );
    await database.upsertCourse(
      CoursesCompanion.insert(
        id: 'course-a',
        name: '高等数学',
        chineseName: '高等数学',
        courseType: 'student',
        semesterId: '2026-spring',
      ),
    );

    final api = Learn2018Helper();
    api.dio.httpClientAdapter = _DownloadAdapter();
    final workspace = FileStorageWorkspaceService(
      database: database,
      getDocumentsDirectory: () async => documentsDirectory,
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        apiClientProvider.overrideWithValue(api),
        fileStorageWorkspaceServiceProvider.overrideWithValue(workspace),
        downloadedPayloadInspectorProvider.overrideWithValue(inspector),
      ],
    );
    return _DownloadFixture(
      database: database,
      documentsDirectory: documentsDirectory,
      api: api,
      container: container,
      workspace: workspace,
    );
  }

  Future<void> dispose() async {
    container.dispose();
    api.dio.close(force: true);
    await database.close();
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  }
}

class _DownloadAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final payload = options.path.endsWith('/first')
        ? 'first payload'
        : options.path.endsWith('/second')
        ? 'second payload'
        : 'replacement payload';
    return ResponseBody.fromBytes(
      Uint8List.fromList(payload.codeUnits),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/pdf'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _RejectingPayloadInspector extends DownloadedPayloadInspector {
  const _RejectingPayloadInspector();

  @override
  Future<DownloadedPayloadValidation> inspect({
    required File file,
    required Headers headers,
    required int? statusCode,
    String? expectedFileType,
  }) async {
    return const DownloadedPayloadValidation.invalid(
      errorMessage: 'invalid replacement',
    );
  }
}
