import 'package:flutter/material.dart';

/// Placeholder — Home screen with smart aggregation.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('首页'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // TODO: global search
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Today's schedule placeholder
          _SectionHeader(title: '今日课程', theme: theme),
          const SizedBox(height: 8),
          _PlaceholderCard(
            icon: Icons.calendar_today_rounded,
            title: '今日课程表',
            subtitle: '暂无数据',
            theme: theme,
          ),
          const SizedBox(height: 24),

          // Urgent assignments placeholder
          _SectionHeader(title: '紧急作业', theme: theme),
          const SizedBox(height: 8),
          _PlaceholderCard(
            icon: Icons.assignment_late_rounded,
            title: '即将截止',
            subtitle: '暂无数据',
            theme: theme,
          ),
          const SizedBox(height: 24),

          // Unread notifications placeholder
          _SectionHeader(title: '未读通知', theme: theme),
          const SizedBox(height: 8),
          _PlaceholderCard(
            icon: Icons.notifications_none_rounded,
            title: '新通知',
            subtitle: '暂无数据',
            theme: theme,
          ),
          const SizedBox(height: 24),

          // New files placeholder
          _SectionHeader(title: '最新文件', theme: theme),
          const SizedBox(height: 8),
          _PlaceholderCard(
            icon: Icons.folder_open_rounded,
            title: '新增文件',
            subtitle: '暂无数据',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(title, style: theme.textTheme.headlineSmall);
  }
}

class _PlaceholderCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ThemeData theme;

  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
