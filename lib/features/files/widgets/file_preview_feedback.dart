import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';

class PreparingPreviewView extends StatelessWidget {
  const PreparingPreviewView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator.adaptive(strokeWidth: 3),
          ),
          const SizedBox(height: 14),
          Text(
            '正在准备预览',
            style: AppTypography.bodyMedium.copyWith(color: c.subtitle),
          ),
        ],
      ),
    );
  }
}

class PreviewUnavailable extends StatelessWidget {
  const PreviewUnavailable({
    super.key,
    required this.message,
    required this.onOpenExternal,
  });

  final String message;
  final VoidCallback onOpenExternal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: c.subtitle, size: 36),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: c.subtitle,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onOpenExternal,
              child: const Text('用其他应用打开'),
            ),
          ],
        ),
      ),
    );
  }
}
