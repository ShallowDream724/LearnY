import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/design/app_materials.dart';

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
    return Material(
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
                  color: StudyPalette.of(context, tone).accent,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: context.colors.subtitle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
