import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/app_light_scene.dart';
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/core/design/scene_ink_appearance.dart';
import 'package:learn_y/core/design/study_reading_ink.dart';
import 'package:learn_y/core/design/study_sliver_app_bar.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/design/wallpaper.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  test('ink adjusts to light and dark scenes without adding a surface', () {
    for (final background in [
      Colors.white,
      Colors.black,
      const Color(0xFFB6C8DE),
    ]) {
      for (final tone in StudyTone.values) {
        final original = Color(tone.light);
        final result = resolveSceneInk(
          [original],
          (darkest: background, brightest: background),
          preferLight: false,
        );
        expect(
          contrast(result.apply(original), background),
          greaterThanOrEqualTo(4.48),
        );
      }
    }
    final mixed = resolveSceneInk(
      [const Color(0xFF5966A9)],
      (darkest: Colors.black, brightest: Colors.white),
      preferLight: false,
    );
    expect(mixed.contrast, 1);
    expect(
      mixed.amount,
      0,
      reason: 'Do not invent a guaranteed ink for a full luminance interval',
    );
  });

  Future<MemoryImage> image(WidgetTester tester, bool striped) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (var x = 0; x < 256; x++) {
      canvas.drawRect(
        Rect.fromLTWH(x.toDouble(), 0, 1, 160),
        Paint()
          ..color = striped && x % 4 < 2
              ? const Color(0xFF24556F)
              : const Color(0xFF7BADCF),
      );
    }
    final picture = recorder.endRecording();
    final rendered = (await tester.runAsync(() => picture.toImage(256, 160)))!;
    final bytes = (await tester.runAsync(
      () => rendered.toByteData(format: ui.ImageByteFormat.png),
    ))!;
    rendered.dispose();
    picture.dispose();
    return MemoryImage(bytes.buffer.asUint8List());
  }

  Future<ByteData> pixels(
    WidgetTester tester,
    GlobalKey key, {
    double ratio = 1,
  }) async {
    final rendered = (await tester.runAsync(
      () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
          .toImage(pixelRatio: ratio),
    ))!;
    final bytes = (await tester.runAsync(
      () => rendered.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    rendered.dispose();
    return bytes;
  }

  Future<void> settle(WidgetTester tester, MemoryImage provider) async {
    await tester.runAsync(
      () => precacheImage(
        provider,
        tester.element(find.byType(StudyLightBackdrop)),
      ),
    );
    for (var i = 0; i < 15; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }
  }

  Widget app(
    GlobalKey key,
    MemoryImage provider, {
    required bool field,
    bool card = false,
    bool hidden = false,
    Offset fieldOffset = Offset.zero,
  }) => MaterialApp(
    theme: AppTheme.light,
    home: RepaintBoundary(
      key: key,
      child: StudyLightBackdrop(
        wallpaper: StudyWallpaper.custom,
        imageProvider: provider,
        strength: 1,
        child: Stack(
          children: [
            if (field)
              Center(
                child: Transform.translate(
                  offset: fieldOffset,
                  child: Offstage(
                    offstage: hidden,
                    child: SizedBox(
                      width: 120,
                      height: 32,
                      child: StudyReadingInk(
                        colors: const [Color(0xFF5966A9)],
                        builder: (_, _) => const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            if (card)
              const Positioned(
                left: 100,
                top: 90,
                width: 60,
                height: 40,
                child: ColoredBox(color: Colors.red),
              ),
          ],
        ),
      ),
    ),
  );

  testWidgets('flat wallpaper stays colored with no white control rectangle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(256, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = await image(tester, false);
    final key = GlobalKey();
    await tester.pumpWidget(app(key, provider, field: false));
    await settle(tester, provider);
    final before = await pixels(tester, key);
    await tester.pumpWidget(app(key, provider, field: true));
    await settle(tester, provider);
    final after = await pixels(tester, key);
    for (var index = 0; index < before.lengthInBytes; index++) {
      expect(
        (before.getUint8(index) - after.getUint8(index)).abs(),
        lessThanOrEqualTo(1),
      );
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'real blur smooths texture and cannot paint over a content card',
    (tester) async {
      tester.view.physicalSize = const Size(256, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = await image(tester, true);
      final key = GlobalKey();
      await tester.pumpWidget(app(key, provider, field: false, card: true));
      await settle(tester, provider);
      final before = await pixels(tester, key);
      await tester.pumpWidget(app(key, provider, field: true, card: true));
      await settle(tester, provider);
      final after = await pixels(tester, key);
      double variance(ByteData data) {
        final values = [
          for (var x = 100; x < 156; x++) data.getUint8((70 * 256 + x) * 4),
        ];
        final mean = values.reduce((a, b) => a + b) / values.length;
        return values
                .map((v) => math.pow(v - mean, 2))
                .reduce((a, b) => a + b) /
            values.length;
      }

      expect(variance(after), lessThan(variance(before) * .6));
      for (final point in [const Offset(20, 10), const Offset(120, 110)]) {
        final index = (point.dy.toInt() * 256 + point.dx.toInt()) * 4;
        for (var channel = 0; channel < 4; channel++) {
          expect(
            after.getUint8(index + channel),
            before.getUint8(index + channel),
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'reading protection follows ink without shrinking the touch target',
    (tester) async {
      tester.view.physicalSize = const Size(256, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final provider = await image(tester, true);
      final key = GlobalKey();
      Widget scene(bool protect) {
        final button = TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            minimumSize: const Size(220, 96),
            backgroundColor: Colors.transparent,
          ),
          child: const Text('退出'),
        );
        return MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: key,
            child: StudyLightBackdrop(
              imageProvider: provider,
              wallpaper: StudyWallpaper.custom,
              strength: 1,
              child: Center(
                child: protect
                    ? StudyReadingInk(
                        colors: const [Color(0xFF5966A9)],
                        builder: (_, _) => button,
                      )
                    : button,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(scene(false));
      await settle(tester, provider);
      final before = await pixels(tester, key);
      await tester.pumpWidget(scene(true));
      await settle(tester, provider);
      expect(tester.getSize(find.byType(TextButton)), const Size(220, 96));
      final after = await pixels(tester, key);
      for (final x in [30, 220]) {
        for (var channel = 0; channel < 4; channel++) {
          final offset = (80 * 256 + x) * 4 + channel;
          expect(after.getUint8(offset), before.getUint8(offset));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'high density impulse blur has one smooth peak without repeated lobes',
    (tester) async {
      addTearDown(tester.view.reset);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(Colors.black, BlendMode.src);
      canvas.drawRect(
        const Rect.fromLTWH(128, 0, 1, 160),
        Paint()..color = Colors.white,
      );
      final picture = recorder.endRecording();
      final rendered = (await tester.runAsync(
        () => picture.toImage(256, 160),
      ))!;
      final encoded = (await tester.runAsync(
        () => rendered.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      rendered.dispose();
      picture.dispose();
      final provider = MemoryImage(encoded.buffer.asUint8List());
      for (final ratio in [1.0, 2.0, 3.0]) {
        tester.view.physicalSize = Size(256 * ratio, 160 * ratio);
        tester.view.devicePixelRatio = ratio;
        final key = GlobalKey();
        await tester.pumpWidget(app(key, provider, field: true));
        await settle(tester, provider);
        final first = await pixels(tester, key, ratio: ratio);
        int channel(ByteData image, int step) => image.getUint8(
          ((80 * ratio).toInt() * (256 * ratio).toInt() +
                  (128.5 * ratio).floor() +
                  step * ratio.toInt()) *
              4,
        );
        final peak = channel(first, 0);
        expect(peak, inInclusiveRange(8, 50));
        for (var step = 1; step < 25; step++) {
          expect(
            channel(first, step),
            lessThanOrEqualTo(channel(first, step - 1) + 1),
          );
        }
        await tester.pumpWidget(
          app(key, provider, field: true, fieldOffset: const Offset(.37, .61)),
        );
        await tester.pump();
        final moved = await pixels(tester, key, ratio: ratio);
        for (var step = -24; step < 25; step++) {
          expect(
            (channel(moved, step) - channel(first, step)).abs(),
            lessThanOrEqualTo(1),
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets('retained hidden routes leave no blur in the visible scene', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(256, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final provider = await image(tester, true);
    final key = GlobalKey();
    await tester.pumpWidget(app(key, provider, field: false));
    await settle(tester, provider);
    final before = await pixels(tester, key);
    await tester.pumpWidget(app(key, provider, field: true, hidden: true));
    await settle(tester, provider);
    final after = await pixels(tester, key);
    expect(after.buffer.asUint8List(), before.buffer.asUint8List());
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'ink follows a changed wallpaper smoothly and reduced motion snaps',
    (tester) async {
      tester.view.physicalSize = const Size(256, 160);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawColor(Colors.black, BlendMode.src);
      final picture = recorder.endRecording();
      final rendered = (await tester.runAsync(
        () => picture.toImage(256, 160),
      ))!;
      final bytes = (await tester.runAsync(
        () => rendered.toByteData(format: ui.ImageByteFormat.png),
      ))!;
      rendered.dispose();
      picture.dispose();
      final provider = MemoryImage(bytes.buffer.asUint8List());
      final key = GlobalKey();
      Widget scene(double strength, {bool reduced = false}) => MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(256, 160),
            disableAnimations: reduced,
          ),
          child: RepaintBoundary(
            key: key,
            child: StudyLightBackdrop(
              wallpaper: StudyWallpaper.custom,
              imageProvider: provider,
              strength: strength,
              child: Center(
                child: StudyReadingInk(
                  colors: const [Color(0xFF5966A9)],
                  builder: (_, _) => const SizedBox(
                    width: 20,
                    height: 20,
                    child: ColoredBox(color: Color(0xFF5966A9)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      Future<int> inkRed() async =>
          (await pixels(tester, key)).getUint8((80 * 256 + 128) * 4);

      await tester.pumpWidget(scene(0));
      await settle(tester, provider);
      await tester.pump(const Duration(milliseconds: 200));
      final original = await inkRed();
      await tester.pumpWidget(scene(1));
      expect(await inkRed(), original);
      await tester.pump(const Duration(milliseconds: 70));
      final middle = await inkRed();
      await tester.pump(const Duration(milliseconds: 100));
      final end = await inkRed();
      expect(middle, greaterThan(original));
      expect(end, greaterThan(middle));
      await tester.pumpWidget(scene(0, reduced: true));
      expect(await inkRed(), original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets(
    'header buttons have transparent resting material in both themes',
    (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: CustomScrollView(
                slivers: [
                  StudySliverAppBar(
                    title: const Text('课程'),
                    actions: [
                      TextButton(onPressed: () {}, child: const Text('整理课程')),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (final button in [
          find.byType(TextButton),
          find.byType(IconButton),
        ]) {
          final material = tester.widget<Material>(
            find.descendant(of: button, matching: find.byType(Material)).first,
          );
          expect(material.color, Colors.transparent);
        }
      }
    },
  );
}
