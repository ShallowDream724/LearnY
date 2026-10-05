import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/app_light_scene.dart';
import 'package:learn_y/core/design/material_contrast.dart';
import 'package:learn_y/core/design/reading_feather.dart';
import 'package:learn_y/core/design/study_readable_content.dart';
import 'package:learn_y/core/design/study_sliver_app_bar.dart';
import 'package:learn_y/core/design/theme.dart';

Color pixel(ByteData bytes, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(
    bytes.getUint8(i + 3),
    bytes.getUint8(i),
    bytes.getUint8(i + 1),
    bytes.getUint8(i + 2),
  );
}

final _black = MemoryImage(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  ),
);

void main() {
  testWidgets('protection is flat under content and fades only outside it', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.black, BlendMode.src);
    ReadingFeather(
      Colors.white.withValues(alpha: .8),
    ).paint(canvas, const Rect.fromLTWH(60, 60, 80, 40));
    final picture = recorder.endRecording();
    final image = (await tester.runAsync(() => picture.toImage(200, 160)))!;
    final bytes = (await tester.runAsync(() => image.toByteData()))!;
    for (final position in [
      const Offset(60, 60),
      const Offset(139, 99),
      const Offset(100, 80),
    ]) {
      expect(
        pixel(bytes, 200, position.dx.toInt(), position.dy.toInt()).r,
        closeTo(.8, .01),
      );
    }
    var previous = .81;
    for (var y = 100; y <= 136; y++) {
      final value = pixel(bytes, 200, 100, y).r;
      expect(value, lessThanOrEqualTo(previous + .005));
      expect(previous - value, lessThan(.05));
      previous = value;
    }
    expect(previous, 0);
    image.dispose();
    picture.dispose();
  });

  testWidgets(
    'title feather crosses the toolbar edge without a clipped strip',
    (tester) async {
      tester.view.physicalSize = const Size(390, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RepaintBoundary(
            key: boundary,
            child: StudyLightBackdrop(
              imageProvider: _black,
              strength: 1,
              child: Scaffold(
                backgroundColor: Colors.transparent,
                body: CustomScrollView(
                  slivers: [
                    StudySliverAppBar(
                      title: const SizedBox(width: 120, height: 48),
                      toolbarHeight: 64,
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 400)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
      await tester.pump();
      final image = (await tester.runAsync(
        () =>
            (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(),
      ))!;
      final bytes = (await tester.runAsync(() => image.toByteData()))!;
      final before = pixel(bytes, 390, 60, 63).r;
      final after = pixel(bytes, 390, 60, 64).r;
      expect(after, greaterThan(.05));
      expect((before - after).abs(), lessThan(.05));
      expect(pixel(bytes, 390, 60, 104).r, lessThan(.02));
      image.dispose();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('header feather fades before the system status inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 240);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    final scroll = ScrollController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(top: 24),
            viewPadding: const EdgeInsets.only(top: 24),
          ),
          child: child!,
        ),
        home: RepaintBoundary(
          key: boundary,
          child: StudyLightBackdrop(
            imageProvider: _black,
            strength: 1,
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: CustomScrollView(
                controller: scroll,
                slivers: [
                  StudySliverAppBar(
                    title: const SizedBox(width: 120, height: 48),
                    toolbarHeight: 64,
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 400)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pump();
    for (final position in [0.0, 30.0]) {
      scroll.jumpTo(position);
      await tester.pump();
      final image = (await tester.runAsync(
        () =>
            (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(),
      ))!;
      final bytes = (await tester.runAsync(() => image.toByteData()))!;
      expect(pixel(bytes, 390, 60, 23).r, lessThan(.02));
      if (position == 0) {
        expect(pixel(bytes, 390, 60, 24).r, lessThan(.035));
        expect(pixel(bytes, 390, 60, 33).r, greaterThan(.3));
      }
      image.dispose();
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    scroll.dispose();
  });

  testWidgets('header actions use the protected primary color in both themes', (
    tester,
  ) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: StudyHeaderContent.actions(
              child: Row(
                children: [
                  TextButton(onPressed: () {}, child: const Text('整理课程')),
                  IconButton(onPressed: () {}, icon: const Icon(Icons.refresh)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final protected = tester.widget<StudyReadableContent>(
        find.byType(StudyReadableContent),
      );
      final context = tester.element(find.byType(TextButton));
      final ink = Theme.of(
        context,
      ).textButtonTheme.style!.foregroundColor!.resolve({})!;
      expect(protected.foregrounds, contains(ink));
      expect(
        ink,
        readingForeground(
          theme.colorScheme.primary,
          dark: theme.brightness == Brightness.dark,
        ),
      );
      final iconInk = Theme.of(
        context,
      ).iconButtonTheme.style!.foregroundColor!.resolve({})!;
      expect(protected.foregrounds, contains(iconInk));
    }
  });

  testWidgets(
    'pinned header masks content with an exterior fade at all strengths',
    (tester) async {
      tester.view.physicalSize = const Size(390, 240);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final strength in [.3, 1.0]) {
        final boundary = GlobalKey();
        final scroll = ScrollController(initialScrollOffset: 40);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: RepaintBoundary(
              key: boundary,
              child: StudyLightBackdrop(
                imageProvider: _black,
                strength: strength,
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  body: CustomScrollView(
                    controller: scroll,
                    slivers: [
                      StudySliverAppBar(
                        pinned: true,
                        title: const SizedBox.shrink(),
                        toolbarHeight: 64,
                      ),
                      SliverToBoxAdapter(
                        child: Container(height: 400, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pump();
        final image = (await tester.runAsync(
          () =>
              (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(),
        ))!;
        final bytes = (await tester.runAsync(() => image.toByteData()))!;
        final core = pixel(bytes, 390, 300, 60).r;
        expect((pixel(bytes, 390, 300, 64).r - core).abs(), lessThan(.025));
        expect(pixel(bytes, 390, 300, 82).r, greaterThan(core + .1));
        expect(pixel(bytes, 390, 300, 102).r, closeTo(1, .01));
        image.dispose();
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        scroll.dispose();
      }
    },
  );
}
