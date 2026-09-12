import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_asset_actions.dart';
import 'package:learn_y/core/files/file_models.dart';
import 'package:learn_y/core/providers/app_providers.dart';
import 'package:learn_y/core/services/file_download_service.dart';

void main() {
  late Directory temporaryDirectory;
  late ProviderContainer container;
  late _ControlledDownloadNotifier notifier;
  late FileAssetActions actions;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'learn-y-file-actions-',
    );
    container = ProviderContainer(
      overrides: [
        fileDownloadProvider.overrideWith((ref) {
          notifier = _ControlledDownloadNotifier(ref);
          return notifier;
        }),
      ],
    );
    container.read(fileDownloadProvider);
    actions = container.read(fileAssetActionsProvider);
  });

  tearDown(() async {
    container.dispose();
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'deduplicates availability requests and returns the published path',
    () async {
      final publishedFile = File('${temporaryDirectory.path}/published.pdf');
      await publishedFile.writeAsString('published');
      notifier.nextPublishedPath = publishedFile.path;

      final first = actions.ensureAvailable(_item());
      await notifier.downloadStarted.future;
      final second = actions.ensureAvailable(_item());

      notifier.finishDownload.complete();

      expect(await first, publishedFile.path);
      expect(await second, publishedFile.path);
      expect(notifier.downloadCalls, 1);
    },
  );

  test(
    'waits for an active replacement instead of using its old path',
    () async {
      final oldFile = File('${temporaryDirectory.path}/old.pdf');
      final newFile = File('${temporaryDirectory.path}/new.pdf');
      await oldFile.writeAsString('old');
      await newFile.writeAsString('new');
      notifier.beginExternalDownload(oldFile.path);

      var completed = false;
      final request = actions
          .ensureAvailable(
            _item(
              localDownloadState: 'downloaded',
              localFilePath: oldFile.path,
            ),
          )
          .whenComplete(() => completed = true);
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse);
      notifier.finishExternalDownload(newFile.path);
      expect(await request, newFile.path);
      expect(notifier.downloadCalls, 0);
    },
  );

  test(
    'reports a failed download instead of sharing an unpublished path',
    () async {
      notifier.failureMessage = '服务器未返回文件';

      final request = actions.ensureAvailable(_item());
      await notifier.downloadStarted.future;
      notifier.finishDownload.complete();

      await expectLater(
        request,
        throwsA(
          isA<FileAssetActionException>().having(
            (error) => error.message,
            'message',
            '服务器未返回文件',
          ),
        ),
      );
    },
  );

  test(
    'does not treat a preserved old file as a completed replacement',
    () async {
      final oldFile = File('${temporaryDirectory.path}/old.pdf');
      await oldFile.writeAsString('old');
      notifier.beginExternalDownload(oldFile.path);

      final request = actions.ensureAvailable(
        _item(localDownloadState: 'downloaded', localFilePath: oldFile.path),
      );
      notifier.finishExternalDownload(oldFile.path, errorMessage: '替换下载失败');

      await expectLater(
        request,
        throwsA(
          isA<FileAssetActionException>().having(
            (error) => error.message,
            'message',
            '替换下载失败',
          ),
        ),
      );
    },
  );

  test(
    'account session changes cancel a pending share before publication',
    () async {
      final oldFile = File('${temporaryDirectory.path}/old.pdf');
      final newFile = File('${temporaryDirectory.path}/new.pdf');
      await oldFile.writeAsString('old');
      await newFile.writeAsString('new');
      notifier.beginExternalDownload(oldFile.path);

      final request = actions.share(
        _item(localDownloadState: 'downloaded', localFilePath: oldFile.path),
      );
      container.read(dataSessionEpochProvider.notifier).state++;

      await expectLater(
        request.timeout(const Duration(seconds: 1)),
        throwsA(
          isA<FileAssetActionException>().having(
            (error) => error.message,
            'message',
            '账户已切换，文件操作已取消',
          ),
        ),
      );
      expect(container.read(fileAssetActionsProvider), isNot(same(actions)));

      notifier.finishExternalDownload(newFile.path);
    },
  );

  test('account session changes cancel a share-owned download wait', () async {
    final publishedFile = File('${temporaryDirectory.path}/published.pdf');
    await publishedFile.writeAsString('published');
    notifier.nextPublishedPath = publishedFile.path;

    final request = actions.share(_item());
    await notifier.downloadStarted.future;
    container.read(dataSessionEpochProvider.notifier).state++;

    await expectLater(
      request.timeout(const Duration(seconds: 1)),
      throwsA(
        isA<FileAssetActionException>().having(
          (error) => error.message,
          'message',
          '账户已切换，文件操作已取消',
        ),
      ),
    );

    notifier.finishDownload.complete();
  });
}

FileDetailItem _item({
  String localDownloadState = 'none',
  String? localFilePath,
}) {
  return FileDetailItem(
    cacheKey: 'file-1',
    sourceKind: 'courseFile',
    persistedFileId: 'file-1',
    courseId: 'course-1',
    courseName: 'Course',
    title: 'notes.pdf',
    description: '',
    rawSize: 0,
    size: '12 KB',
    uploadTime: '',
    fileType: 'pdf',
    downloadUrl: 'https://example.com/file',
    previewUrl: 'https://example.com/preview',
    markedImportant: false,
    isNew: true,
    supportsReadState: true,
    localDownloadState: localDownloadState,
    localFilePath: localFilePath,
  );
}

class _ControlledDownloadNotifier extends FileDownloadNotifier {
  _ControlledDownloadNotifier(super.ref);

  final downloadStarted = Completer<void>();
  final finishDownload = Completer<void>();
  String? nextPublishedPath;
  String? failureMessage;
  int downloadCalls = 0;

  @override
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
    downloadCalls++;
    state = {
      assetKey: FileDownloadState(
        fileId: assetKey,
        status: DownloadStatus.downloading,
      ),
    };
    if (!downloadStarted.isCompleted) downloadStarted.complete();
    await finishDownload.future;
    final error = failureMessage;
    state = {
      assetKey: error == null
          ? FileDownloadState(
              fileId: assetKey,
              status: DownloadStatus.downloaded,
              progress: 1,
              localPath: nextPublishedPath,
            )
          : FileDownloadState(
              fileId: assetKey,
              status: DownloadStatus.failed,
              errorMessage: error,
            ),
    };
  }

  void beginExternalDownload(String oldPath) {
    state = {
      'file-1': FileDownloadState(
        fileId: 'file-1',
        status: DownloadStatus.downloading,
        progress: 1,
        localPath: oldPath,
      ),
    };
  }

  void finishExternalDownload(String publishedPath, {String? errorMessage}) {
    state = {
      'file-1': FileDownloadState(
        fileId: 'file-1',
        status: DownloadStatus.downloaded,
        progress: 1,
        localPath: publishedPath,
        errorMessage: errorMessage,
      ),
    };
  }
}
