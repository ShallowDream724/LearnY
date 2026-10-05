import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/app_light_scene.dart';
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/core/design/colors.dart';
import 'package:learn_y/core/design/material_contrast.dart';
import 'package:learn_y/core/design/wallpaper.dart';
import 'package:learn_y/core/design/wallpaper_contrast_grid.dart';

Uint8List _pixels(int width, int height, Color Function(int x, int y) colorAt) {
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final color = colorAt(x, y);
      final i = (y * width + x) * 4;
      bytes[i] = (color.r * 255).round();
      bytes[i + 1] = (color.g * 255).round();
      bytes[i + 2] = (color.b * 255).round();
      bytes[i + 3] = (color.a * 255).round();
    }
  }
  return bytes;
}

WallpaperContrastGrid _analyse(
  Uint8List bytes,
  int width,
  int height, {
  bool dark = false,
  bool customDark = false,
}) => analyseWallpaperContrast(
  WallpaperContrastRequest(
    width: width,
    height: height,
    pixels: TransferableTypedData.fromList([bytes]),
    dark: dark,
    customDark: customDark,
  ),
);

Future<ui.Image> _image(Uint8List pixels, int width, int height) {
  final result = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    pixels,
    width,
    height,
    ui.PixelFormat.rgba8888,
    result.complete,
  );
  return result.future;
}

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return first > second
      ? (first + .05) / (second + .05)
      : (second + .05) / (first + .05);
}

void main() {
  test(
    'small contrasting details survive reduction to bounded source tiles',
    () {
      final bytes = _pixels(
        256,
        256,
        (x, y) => x == 5 && y == 2 ? Colors.black : Colors.white,
      );
      final grid = _analyse(bytes, 256, 256);
      expect(grid.extreme(0, 0, brightest: false), Colors.black);
      expect(grid.extreme(0, 0, brightest: true), Colors.white);
      expect(grid.extreme(1, 0, brightest: false).r, greaterThan(.99));
      // A mostly-white image is not treated as uniformly white: one dark pixel
      // under a small metadata label still contributes to the protection bound.
    },
  );

  test(
    'transparent pixels and custom dark treatment match the painted source',
    () {
      final transparent = _analyse(
        _pixels(2, 2, (_, _) => Colors.transparent),
        2,
        2,
      );
      expect(
        transparent.extreme(0, 0, brightest: false).r * 255,
        closeTo(246, 1),
      );
      final dark = _analyse(
        _pixels(2, 2, (_, _) => Colors.white),
        2,
        2,
        dark: true,
        customDark: true,
      );
      expect(dark.extreme(0, 0, brightest: false).r * 255, closeTo(116, 1));
      expect(dark.extreme(0, 0, brightest: true).b * 255, closeTo(139, 1));
    },
  );

  testWidgets(
    'regional protection uses the same crop and strength as the image',
    (tester) async {
      final bytes = _pixels(
        64,
        64,
        (x, _) => x < 32 ? Colors.white : Colors.black,
      );
      final image = (await tester.runAsync(() => _image(bytes, 64, 64)))!;
      addTearDown(image.dispose);
      for (final dark in [false, true]) {
        final grid = _analyse(bytes, 64, 64, dark: dark, customDark: dark);
        final ink = readingForeground(
          dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          dark: dark,
        );
        final scene = StudyLightScene(
          dark: dark,
          image: image,
          wallpaper: StudyWallpaper.custom,
          strength: 1,
          contrastGrid: grid,
        );
        const viewport = Size(390, 220);
        final onWhite = scene.readingOpacity(
          const Rect.fromLTWH(20, 90, 40, 30),
          viewport,
          minimum: 0,
          foreground: ink,
        );
        final onBlack = scene.readingOpacity(
          const Rect.fromLTWH(320, 90, 40, 30),
          viewport,
          minimum: 0,
          foreground: ink,
        );
        expect(dark ? onBlack : onWhite, 0);
        expect(dark ? onWhite : onBlack, greaterThan(.2));
        final hidden = scene.withStrength(0);
        expect(
          hidden.readingOpacity(
            const Rect.fromLTWH(320, 90, 40, 30),
            viewport,
            minimum: 0,
            foreground: ink,
          ),
          0,
        );
      }
    },
  );

  testWidgets(
    'colored counts and labels stay legible across mixed-detail wallpaper',
    (tester) async {
      const sourceColors = [
        Colors.white,
        Colors.black,
        Color(0xFF4973B2),
        Color(0xFFDDD2AA),
      ];
      final bytes = _pixels(
        64,
        64,
        (x, y) => sourceColors[(x + y) % sourceColors.length],
      );
      final image = (await tester.runAsync(() => _image(bytes, 64, 64)))!;
      addTearDown(image.dispose);
      for (final dark in [false, true]) {
        final grid = _analyse(bytes, 64, 64, dark: dark, customDark: dark);
        final inks = [
          readingForeground(AppColors.error, dark: dark),
          for (final tone in [StudyTone.ink, StudyTone.ochre, StudyTone.jade])
            readingForeground(Color(dark ? tone.dark : tone.light), dark: dark),
          readingForeground(
            dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            dark: dark,
          ),
        ];
        final base = dark ? const Color(0xFF1B1D20) : const Color(0xFFF7F8FB);
        final protection = dark ? const Color(0xFF20242D) : Colors.white;
        for (final strength in [.3, 1.0]) {
          final scene = StudyLightScene(
            dark: dark,
            image: image,
            wallpaper: StudyWallpaper.custom,
            strength: strength,
            contrastGrid: grid,
          );
          for (final ink in inks) {
            final alpha = scene.readingOpacity(
              const Rect.fromLTWH(12, 80, 350, 48),
              const Size(390, 220),
              minimum: 0,
              foreground: ink,
            );
            for (final color in sourceColors) {
              final treated = dark
                  ? Color.fromRGBO(
                      (color.r * 255 * .46).round(),
                      (color.g * 255 * .49).round(),
                      (color.b * 255 * .54).round(),
                      1,
                    )
                  : color;
              final background = Color.alphaBlend(
                treated.withValues(alpha: wallpaperTransmission(strength)),
                base,
              );
              final surface = Color.alphaBlend(
                protection.withValues(alpha: alpha),
                background,
              );
              expect(_contrast(ink, surface), greaterThanOrEqualTo(4.48));
            }
          }
        }
      }
    },
  );
}
