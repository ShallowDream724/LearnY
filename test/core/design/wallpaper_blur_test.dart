import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/wallpaper_blur.dart';

void main() {
  Future<ui.Image> source(WidgetTester tester, int width, int height) async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xFF7BADCF), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(
      () => picture.toImage(width, height),
    ))!;
    picture.dispose();
    return image;
  }

  testWidgets('shared texture has a bounded size and supersedes stale work', (
    tester,
  ) async {
    final first = await source(tester, 2048, 1024);
    final last = await source(tester, 128, 256);
    final blur = WallpaperBlur();
    var updates = 0;
    blur.addListener(() => updates++);
    blur.request(first, 12);
    blur.request(last, 6);
    await tester.runAsync(() async {
      for (var attempt = 0; attempt < 100 && blur.image == null; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    expect(blur.image!.width, 128);
    expect(blur.image!.height, 256);
    expect(updates, 1);
    final texture = blur.image!;
    blur.request(last, 6);
    expect(identical(texture, blur.image), isTrue);
    expect(updates, 1);
    final large = (await tester.runAsync(() => gaussianWallpaper(first, 12)))!;
    expect(large.width, 1024);
    expect(large.height, 512);
    large.dispose();
    blur.dispose();
    expect(texture.debugDisposed, isTrue);
    first.dispose();
    last.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('resize work merges and retired textures are released', (
    tester,
  ) async {
    final image = await source(tester, 256, 256);
    final blur = WallpaperBlur();
    var updates = 0;
    blur.addListener(() => updates++);
    blur.request(image, 6);
    Future<void> waitFor(int count) async {
      await tester.runAsync(() async {
        for (var attempt = 0; attempt < 100 && updates < count; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      expect(updates, count);
    }

    await waitFor(1);
    final first = blur.image!;
    blur.request(image, 7);
    blur.request(image, 8);
    await tester.pump(const Duration(milliseconds: 119));
    expect(updates, 1);
    await tester.pump(const Duration(milliseconds: 1));
    await waitFor(2);
    final second = blur.image!;
    expect(identical(first, second), isFalse);
    await tester.pump();
    expect(first.debugDisposed, isTrue);
    blur.request(image, 10);
    blur.dispose();
    await tester.pump(const Duration(milliseconds: 200));
    expect(second.debugDisposed, isTrue);
    expect(updates, 2);
    image.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'disposing pending work releases its result without notification',
    (tester) async {
      final image = await source(tester, 256, 256);
      final blur = WallpaperBlur();
      var updates = 0;
      blur.addListener(() => updates++);
      blur.request(image, 6);
      blur.request(image, 8);
      blur.dispose();
      image.dispose();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      expect(updates, 0);
      expect(blur.image, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
