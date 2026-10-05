import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/app_light_scene.dart';
import 'package:learn_y/core/design/study_readable_content.dart';
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/core/design/course_glass.dart';
import 'package:learn_y/core/design/wallpaper.dart';

void main() {
  testWidgets(
    'swiped cached header samples the same pixels as explicit navigation',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 100, 100),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.red, Colors.green, Colors.blue],
          ).createShader(const Rect.fromLTWH(0, 0, 100, 100)),
      );
      final picture = recorder.endRecording();
      final source = (await tester.runAsync(() => picture.toImage(100, 100)))!;
      final data = await tester.runAsync(
        () => source.toByteData(format: ui.ImageByteFormat.png),
      );
      final provider = MemoryImage(data!.buffer.asUint8List());
      source.dispose();
      picture.dispose();
      final controller = PageController();
      addTearDown(controller.dispose);
      final header = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: StudyLightBackdrop(
            imageProvider: provider,
            strength: 1,
            child: PageView(
              controller: controller,
              children: [
                const SizedBox.expand(),
                Align(
                  alignment: Alignment.topCenter,
                  child: RepaintBoundary(
                    key: header,
                    child: const SizedBox(
                      height: 90,
                      width: double.infinity,
                      child: StudyLightSurface(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => precacheImage(provider, tester.element(find.byType(PageView))),
      );
      await tester.pumpAndSettle();
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      // Contrast sampling includes an asynchronous GPU readback. Wait for the
      // scene to finish loading before comparing two navigation methods.
      for (var attempt = 0; attempt < 50; attempt++) {
        if (StudyLightBackdrop.sceneOf(
          tester.element(find.byType(StudyLightSurface)),
        )!.samples.isNotEmpty) {
          break;
        }
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(
        StudyLightBackdrop.sceneOf(
          tester.element(find.byType(StudyLightSurface)),
        )!.samples,
        isNotEmpty,
      );
      Future<List<int>> pixels() async {
        final image =
            await (header.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage();
        final bytes = await image.toByteData();
        image.dispose();
        return bytes!.buffer.asUint8List();
      }

      final expected = await tester.runAsync(pixels);
      controller.jumpToPage(0);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(-340, 0));
      await tester.pumpAndSettle();
      expect(controller.page, 1);
      expect(await tester.runAsync(pixels), expected);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('cached course glass survives background changes and returns', (
    tester,
  ) async {
    final controller = PageController();
    final cardKey = GlobalKey();
    addTearDown(controller.dispose);

    Widget app({required double strength, required Brightness brightness}) =>
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: StudyLightBackdrop(
            strength: strength,
            child: PageView(
              controller: controller,
              children: [
                _RetainedCourse(cardKey: cardKey),
                const ColoredBox(color: Colors.white),
              ],
            ),
          ),
        );

    await tester.pumpWidget(app(strength: .3, brightness: Brightness.light));
    final firstContext = cardKey.currentContext!;
    await tester.runAsync(
      () => precacheImage(
        AssetImage(StudyWallpaper.dunes.assetFor(Brightness.light)),
        firstContext,
      ),
    );
    await tester.pumpAndSettle();
    final card = cardKey.currentContext!.findRenderObject()! as RenderBox;
    final original = StudyLightBackdrop.locate(card, dark: false).origin;
    expect(original.isFinite, isTrue);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      controller.jumpToPage(1);
      await tester.pumpAndSettle();
      // The retained page still owns a repaint boundary, but the viewport
      // deliberately cannot map it to the screen while it is in its cache.
      final hidden = MatrixUtils.transformPoint(
        card.getTransformTo(null),
        Offset.zero,
      );
      expect(hidden.isFinite, isFalse);

      await tester.pumpWidget(app(strength: .65, brightness: brightness));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      controller.jumpToPage(0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('课程卡片'), findsOneWidget);
      expect(StudyLightBackdrop.locate(card, dark: false).origin, original);
    }
    await tester.pumpWidget(const SizedBox());
  });
}

class _RetainedCourse extends StatefulWidget {
  const _RetainedCourse({required this.cardKey});
  final GlobalKey cardKey;

  @override
  State<_RetainedCourse> createState() => _RetainedCourseState();
}

class _RetainedCourseState extends State<_RetainedCourse>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(
          child: SizedBox(
            width: 220,
            height: 140,
            child: CourseGlassSurface(
              key: widget.cardKey,
              tone: StudyTone.ink,
              child: const Center(child: Text('课程卡片')),
            ),
          ),
        ),
      ),
    );
  }
}
