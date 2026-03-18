import 'package:flutter/material.dart';

/// Placeholder — Profile / Settings screen.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_rounded, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('个人设置', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text('即将上线', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
