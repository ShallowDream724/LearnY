import 'package:flutter/material.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';

class LoginAutoReloginCard extends StatelessWidget {
  const LoginAutoReloginCard({
    super.key,
    required this.enabled,
    required this.showGuideBody,
    required this.onChanged,
    required this.onLearnMore,
    required this.onDismissGuide,
  });

  final bool enabled;
  final bool showGuideBody;
  final ValueChanged<bool> onChanged;
  final VoidCallback onLearnMore;
  final VoidCallback onDismissGuide;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return StudySurface(
      tone: StudyTone.jade,
      radius: 14,
      padding: const EdgeInsets.fromLTRB(18, 16, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自动重新登录',
                      style: AppTypography.titleMedium.copyWith(color: c.text),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '会话过期后自动尝试恢复登录',
                      style: AppTypography.bodySmall.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(value: enabled, onChanged: onChanged),
            ],
          ),
          if (showGuideBody) ...[
            const SizedBox(height: 10),
            Text(
              '账号密码只保存在系统安全存储中',
              style: AppTypography.bodySmall.copyWith(color: c.subtitle),
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: onLearnMore,
                style: TextButton.styleFrom(
                  foregroundColor: c.infoAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text('了解详情'),
              ),
              const Spacer(),
              if (showGuideBody)
                IconButton(
                  onPressed: onDismissGuide,
                  icon: Icon(Icons.close_rounded, size: 18, color: c.subtitle),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 18,
                  tooltip: '收起说明',
                ),
            ],
          ),
        ],
      ),
    );
  }
}
