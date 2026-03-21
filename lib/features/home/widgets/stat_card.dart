import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 92;
        final horizontalPadding = compact ? 10.0 : 12.0;
        final iconBoxSize = compact ? 26.0 : 28.0;
        final iconSize = compact ? 14.0 : 15.0;
        final contentGap = compact ? 6.0 : 8.0;
        final numberFontSize = compact ? 17.0 : 18.0;
        final numberHeight = compact ? 20.0 : 21.0;
        final labelFontSize = compact ? 10.0 : 11.0;
        final labelHeight = compact ? 12.0 : 13.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Ink(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.border, width: 0.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: iconBoxSize,
                    height: iconBoxSize,
                    decoration: BoxDecoration(
                      color: color.withAlpha(25),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                  SizedBox(width: contentGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: numberHeight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              value,
                              maxLines: 1,
                              softWrap: false,
                              style: AppTypography.statMedium.copyWith(
                                color: c.text,
                                fontSize: numberFontSize,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: labelHeight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              style: AppTypography.bodySmall.copyWith(
                                color: c.subtitle,
                                fontSize: labelFontSize,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
