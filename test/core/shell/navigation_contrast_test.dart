import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/glass_surface.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/shell/app_bottom_navigation.dart';
import 'package:learn_y/core/shell/navigation_glass_appearance.dart';
import 'package:learn_y/core/shell/shell_navigation_progress.dart';

const _destinations = [
  ShellNavDestinationData(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: '首页',
  ),
  ShellNavDestinationData(
    icon: Icons.description_outlined,
    selectedIcon: Icons.description,
    label: '作业',
  ),
  ShellNavDestinationData(
    icon: Icons.grid_view_outlined,
    selectedIcon: Icons.grid_view,
    label: '课程',
  ),
  ShellNavDestinationData(
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    label: '我的',
  ),
];

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  testWidgets(
    'selected glass remains distinct over live light, dark and colored content',
    (tester) async {
      tester.view.physicalSize = const Size(390, 180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final progress = ShellNavigationProgress(3);
      addTearDown(progress.dispose);
      final capture = GlobalKey();
      final observed = <Color>[];

      for (final dark in [false, true]) {
        final appearance = dark
            ? NavigationGlassAppearance.dark
            : NavigationGlassAppearance.light;
        for (final background in [
          Colors.white,
          Colors.black,
          const Color(0xFF3261B5),
          const Color(0xFFEADCBF),
          const Color(0xFF952A4D),
        ]) {
          await tester.pumpWidget(
            RepaintBoundary(
              key: capture,
              child: MaterialApp(
                theme: dark ? AppTheme.dark : AppTheme.light,
                home: Scaffold(
                  backgroundColor: background,
                  extendBody: true,
                  bottomNavigationBar: AppBottomNavigation(
                    destinations: _destinations,
                    selectedIndex: 3,
                    progress: progress,
                    onTap: (_) {},
                  ),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
          final bar = tester.getRect(find.byType(GlassSurface).first);
          final lens = tester.getRect(find.byType(GlassSurface).last);
          final selectedPoint = lens.center + const Offset(22, 0);
          final ordinaryPoint =
              selectedPoint - Offset((bar.width - 8) / 4 * 3, 0);
          final pixels = await tester.runAsync(() async {
            final boundary =
                capture.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final data = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!;
            Color at(Offset p) {
              final i = (p.dy.round() * image.width + p.dx.round()) * 4;
              return Color.fromARGB(
                data.getUint8(i + 3),
                data.getUint8(i),
                data.getUint8(i + 1),
                data.getUint8(i + 2),
              );
            }

            final result = (at(selectedPoint), at(ordinaryPoint));
            image.dispose();
            return result;
          });
          final selected = pixels!.$1;
          final ordinary = pixels.$2;
          final scene = '${dark ? 'dark' : 'light'} on $background';
          expect(
            _contrast(selected, ordinary),
            greaterThanOrEqualTo(1.2),
            reason: 'selection must retain a visible shape: $scene',
          );
          expect(
            _contrast(appearance.selectedForeground, selected),
            greaterThanOrEqualTo(3),
            reason: 'selected symbol: $scene',
          );
          expect(
            _contrast(appearance.foreground, ordinary),
            greaterThanOrEqualTo(3),
            reason: 'ordinary symbols: $scene',
          );
          observed.add(selected);
        }
      }
      // The material must continue reflecting background colors, not become an
      // opaque painted pill. Updating only the backdrop changes its rendered tone.
      expect(observed.toSet(), hasLength(10));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('high contrast retains an opaque selected destination', (
    tester,
  ) async {
    final progress = ShellNavigationProgress(3);
    addTearDown(progress.dispose);
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(highContrast: true),
            child: Scaffold(
              bottomNavigationBar: AppBottomNavigation(
                destinations: _destinations,
                selectedIndex: 3,
                progress: progress,
                onTap: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selectedSurface = find.byType(GlassSurface).last;
      final fill = tester
          .widget<ColoredBox>(
            find
                .descendant(
                  of: selectedSurface,
                  matching: find.byType(ColoredBox),
                )
                .first,
          )
          .color;
      expect(fill.a, 1);
      expect(
        _contrast(fill, theme.colorScheme.onPrimary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        find.descendant(
          of: selectedSurface,
          matching: find.byWidgetPredicate(
            (widget) => widget is GlassBackdrop && widget.enabled,
          ),
        ),
        findsNothing,
      );
    }
    await tester.pumpWidget(const SizedBox());
  });
}
