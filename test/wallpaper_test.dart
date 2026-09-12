import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/design/wallpaper_crop_editor.dart';
import 'package:learn_y/core/design/app_font.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/wallpaper/custom_wallpaper_repository.dart';
import 'package:learn_y/core/wallpaper/wallpaper_crop.dart';
import 'package:learn_y/core/wallpaper/wallpaper_image_service.dart';

void main() {
  test('framing preserves aspect ratio and stays within the image', () {
    const image = Size(1600, 900);
    final crop = WallpaperCrop.centered(image, 9 / 19.5);
    expect(crop.height, 900);
    final moved = WallpaperCrop.constrain(
      crop.shift(const Offset(-4000, 4000)),
      image,
      9 / 19.5,
    );
    expect(moved.left, 0);
    expect(moved.bottom, 900);
    expect(moved.width / moved.height, closeTo(9 / 19.5, .0001));
    expect(
      WallpaperCrop.restore(WallpaperCrop.normalize(moved, image), image),
      moved,
    );
  });

  testWidgets(
    'crop editor exports selected framing and repository persists independent files',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      final semantics = tester.ensureSemantics();
      await tester.runAsync(() async {
        await (FontLoader(
          AppFont.family,
        )..addFont(rootBundle.load(AppFont.asset))).load();
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final database = AppDatabase(NativeDatabase.memory());
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('learny-wallpaper-test-'),
      ))!;
      addTearDown(() async {
        await database.close();
        await directory.delete(recursive: true);
      });
      final repository = CustomWallpaperRepository(
        database,
        directory: () async => directory,
      );
      final shot = GlobalKey();
      var applied = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: shot,
            child: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showWallpaperCropEditor(
                      context,
                      sourcePath: 'assets/artwork/alpine_mobile_light.webp',
                      onApply: (bytes, crop, intensity) async {
                        await repository.save(
                          sourcePath: 'assets/artwork/alpine_mobile_light.webp',
                          name: 'Mountain.webp',
                          imageBytes: bytes,
                          crop: crop,
                          intensity: intensity,
                        );
                        applied = true;
                      },
                    ),
                    child: const Text('编辑'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('编辑'));
      await tester.pump();
      for (var i = 0; i < 30 && find.text('应用背景').evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
      expect(find.text('应用背景'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(applied, isFalse);
      expect(await tester.runAsync(repository.load), isNull);
      await tester.tap(find.text('方形'));
      await tester.pumpAndSettle();
      await tester.drag(find.bySemanticsLabel('裁剪区域'), const Offset(0, -40));
      await tester.pumpAndSettle();
      if (Platform.environment['LEARNY_WALLPAPER_PREVIEW'] == '1') {
        // Capture the actual Flutter dialog, including its crop handles.
        // The overlay belongs to MaterialApp; use its nearest repaint boundary.
        final render = tester
            .element(find.byType(WallpaperCropEditor))
            .findAncestorRenderObjectOfType<RenderRepaintBoundary>();
        if (render != null) {
          await tester.runAsync(() async {
            final image = await render.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              'output/wallpaper-crop-mobile.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
      await tester.tap(find.text('应用背景'));
      for (var i = 0; i < 60 && !applied; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(applied, isTrue);
      final saved = (await tester.runAsync(repository.load))!;
      expect(saved.crop.center.dy, lessThan(.5));
      expect(
        saved.sourcePath,
        isNot('assets/artwork/alpine_mobile_light.webp'),
      );
      expect(await database.getState(AppStateKeys.wallpaper), 'custom');
      final decoded = await tester.runAsync(
        () => WallpaperImageService().decode(saved.imagePath),
      );
      expect(decoded!.width, decoded.height);
      decoded.dispose();
      await tester.runAsync(repository.remove);
      expect(
        await tester.runAsync(() => File(saved.sourcePath).exists()),
        isFalse,
      );
      expect(
        await tester.runAsync(
          () => File('assets/artwork/alpine_mobile_light.webp').exists(),
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );
}
