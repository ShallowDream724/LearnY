import 'package:flutter/material.dart';

/// Placeholder — Courses screen with grid + dashboards.
class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('课程')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('课程总览', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('即将上线', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
