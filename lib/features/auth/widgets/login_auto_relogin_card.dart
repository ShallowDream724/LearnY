import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
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
            _GuideLine(
              icon: Icons.security_rounded,
              text: '账号密码只保存在系统安全存储中',
              color: c.subtitle,
            ),
            const SizedBox(height: 10),
          ] else
            const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: onLearnMore,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
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

class _GuideLine extends StatelessWidget {
  const _GuideLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.bodySmall.copyWith(color: color, height: 1.35),
          ),
        ),
      ],
    );
  }
}
