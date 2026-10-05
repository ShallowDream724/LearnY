import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/core/design/colors.dart';
import 'package:learn_y/core/design/material_contrast.dart';
import 'package:learn_y/core/design/study_control_surface.dart';
import 'package:learn_y/core/design/study_sliver_app_bar.dart';
import 'package:learn_y/core/design/theme.dart';

double contrast(Color a, Color b) {
  final x = a.computeLuminance();
  final y = b.computeLuminance();
  return (math.max(x, y) + .05) / (math.min(x, y) + .05);
}

void main() {
  test('bounded controls preserve semantic contrast on extreme backdrops', () {
    for (final dark in [false, true]) {
      final fill = controlSurfaceColor(dark: dark);
      for (final color in [
        AppColors.error,
        for (final tone in StudyTone.values)
          Color(dark ? tone.dark : tone.light),
      ]) {
        final ink = readingForeground(color, dark: dark);
        for (final backdrop in [Colors.black, Colors.white]) {
          expect(
            contrast(ink, Color.alphaBlend(fill, backdrop)),
            greaterThanOrEqualTo(4.5),
          );
        }
      }
    }
  });

  testWidgets('controls leave pixels beyond their bounds untouched', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(240, 160);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: RepaintBoundary(
            key: boundary,
            child: ColoredBox(
              color: Colors.blue,
              child: Center(
                child: SizedBox(
                  width: 100,
                  height: 40,
                  child: StudyControlSurface(
                    colors: [theme.colorScheme.primary],
                    builder: (_, inks) => const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = (await tester.runAsync(
        () =>
            (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(),
      ))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      for (final point in [
        const Offset(120, 59),
        const Offset(120, 100),
        const Offset(69, 80),
        const Offset(170, 80),
      ]) {
        final index = (point.dy.toInt() * 240 + point.dx.toInt()) * 4;
        expect(bytes.getUint8(index), Colors.blue.r * 255);
        expect(bytes.getUint8(index + 1), Colors.blue.g * 255);
        expect(bytes.getUint8(index + 2), Colors.blue.b * 255);
      }
      image.dispose();
    }
  });

  testWidgets('scrolling headings never mask the content below the toolbar', (
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
        home: RepaintBoundary(
          key: boundary,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: CustomScrollView(
              controller: scroll,
              slivers: [
                StudySliverAppBar(
                  toolbarHeight: 64,
                  title: const SizedBox(width: 120, height: 48),
                ),
                const SliverToBoxAdapter(
                  child: ColoredBox(
                    color: Colors.green,
                    child: SizedBox(height: 400),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    for (final position in [0.0, 20.0, 100.0]) {
      scroll.jumpTo(position);
      await tester.pump();
      final image = (await tester.runAsync(
        () =>
            (boundary.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(),
      ))!;
      final bytes = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      final y = math.max(64 - position, 0).toInt() + 2;
      final index = (y * 390 + 60) * 4;
      expect(bytes.getUint8(index), Colors.green.r * 255);
      expect(bytes.getUint8(index + 1), Colors.green.g * 255);
      expect(bytes.getUint8(index + 2), Colors.green.b * 255);
      image.dispose();
    }
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });

  testWidgets('header actions have bounded readable materials in both themes', (
    tester,
  ) async {
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
      final context = tester.element(find.byType(TextButton));
      final buttons = Theme.of(context);
      final dark = theme.brightness == Brightness.dark;
      for (final style in [
        buttons.textButtonTheme.style!,
        buttons.iconButtonTheme.style!,
      ]) {
        final fill = style.backgroundColor!.resolve({})!;
        final ink = style.foregroundColor!.resolve({})!;
        for (final backdrop in [Colors.black, Colors.white]) {
          expect(
            contrast(ink, Color.alphaBlend(fill, backdrop)),
            greaterThanOrEqualTo(4.5),
          );
        }
        expect(fill, controlSurfaceColor(dark: dark));
      }
      for (final button in [find.byType(TextButton), find.byType(IconButton)]) {
        final material = tester.widget<Material>(
          find.descendant(of: button, matching: find.byType(Material)).first,
        );
        expect(material.color, controlSurfaceColor(dark: dark));
      }
    }
  });
}
