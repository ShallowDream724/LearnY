import 'package:flutter/material.dart';

/// Placeholder — Assignments screen with dashboard + list.
class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('作业')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('作业面板', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('即将上线', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
