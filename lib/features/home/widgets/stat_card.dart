import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/app_materials.dart';
import '../../../core/design/study_control_surface.dart';

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
    return StudyControlSurface(
      radius: 14,
      colors: [StudyPalette.of(context, tone).accent, context.colors.subtitle],
      builder: (_, inks) => Material(
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
                    color: inks[0],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTypography.bodySmall.copyWith(color: inks[1]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
