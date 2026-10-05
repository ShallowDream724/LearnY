import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/colors.dart';
import 'package:learn_y/core/design/material_contrast.dart';

void main() {
  test('small metadata stays readable over bright, dark and saturated wallpaper', () {
    for (final dark in [false, true]) {
      final ink = dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
      for (final backdrop in [Colors.black, Colors.white, Colors.red, Colors.blue, Colors.yellow, Colors.grey]) {
        final alpha = contrastOpacity(backdrop, ink, dark: dark, minimum: .25);
        final surface = Color.alphaBlend((dark ? const Color(0xFF20242D) : Colors.white).withValues(alpha: alpha), backdrop);
        final a = surface.computeLuminance();
        final b = ink.computeLuminance();
        final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
        expect(ratio, greaterThanOrEqualTo(4.48));
      }
    }
  });
}
