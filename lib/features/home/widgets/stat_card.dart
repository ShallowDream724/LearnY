import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/app_materials.dart';
import '../../../core/design/app_light_scene.dart';
import '../../../core/design/material_contrast.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.tone = StudyTone.ink,
    this.onTap,
  });
  final String label;
  final String value;
  final StudyTone tone;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = readingForeground(
      StudyPalette.of(context, tone).accent,
      dark: context.isDark,
    );
    final labelInk = readingForeground(
      context.colors.subtitle,
      dark: context.isDark,
    );
    return StudyReadableContent(
      foregrounds: [accent, labelInk],
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: AppTypography.statMedium.copyWith(
                    fontSize: 22,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(color: labelInk),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
