import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_models.dart';
import 'package:learn_y/core/services/file_download_service.dart';
import 'package:learn_y/features/files/providers/file_bookmark_providers.dart';
import 'package:learn_y/features/files/widgets/file_card.dart';

void main() {
  testWidgets('long press exposes the shared common file actions', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    await tester.longPress(find.byType(FileCard));
    await tester.pumpAndSettle();

    expect(find.text('分享'), findsOneWidget);
    expect(find.text('外部打开'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('标为已读'), findsOneWidget);
    expect(find.text('重新下载'), findsNothing);
  });

  testWidgets('share and open are disabled while the file is downloading', (
    tester,
  ) async {
    await tester.pumpWidget(_app(isDownloading: true));

    await tester.longPress(find.byType(FileCard));
    await tester.pumpAndSettle();

    final shareItem = tester.widget<PopupMenuItem>(
      find.ancestor(
        of: find.text('下载完成后可分享'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    final openItem = tester.widget<PopupMenuItem>(
      find.ancestor(
        of: find.text('下载完成后可打开'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuItem),
      ),
    );
    expect(shareItem.enabled, isFalse);
    expect(openItem.enabled, isFalse);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('标为已读'), findsOneWidget);
  });

  testWidgets('secondary click opens the same file action menu', (
    tester,
  ) async {
    await tester.pumpWidget(_app());

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(FileCard)),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text('分享'), findsOneWidget);
    expect(find.text('外部打开'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('标为已读'), findsOneWidget);
  });

  testWidgets('live bookmark state overrides a caller fallback', (
    tester,
  ) async {
    await tester.pumpWidget(_app(isFavorite: true));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(FileCard));
    await tester.pumpAndSettle();

    expect(find.text('取消收藏'), findsOneWidget);
    expect(find.text('收藏'), findsNothing);
  });
}

Widget _app({bool isDownloading = false, bool isFavorite = false}) {
  return ProviderScope(
    overrides: [
      fileBookmarkStateProvider.overrideWith(
        (ref, assetKey) => Stream.value(isFavorite),
      ),
      if (isDownloading)
        fileDownloadProvider.overrideWith((ref) => _DownloadingNotifier(ref)),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 420, child: FileCard(item: _item())),
        ),
      ),
    ),
  );
}

FileDetailItem _item() {
  return const FileDetailItem(
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
  );
}

class _DownloadingNotifier extends FileDownloadNotifier {
  _DownloadingNotifier(super.ref) {
    state = const {
      'file-1': FileDownloadState(
        fileId: 'file-1',
        status: DownloadStatus.downloading,
        progress: 0.5,
      ),
    };
  }
}
