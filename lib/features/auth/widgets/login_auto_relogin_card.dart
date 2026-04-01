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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enabled ? AppColors.primary.withAlpha(70) : c.border,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(context.isDark ? 20 : 8),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                      showGuideBody ? '建议在首次登录时一并完成授权' : '会话过期后可尝试静默恢复',
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
              icon: Icons.task_alt_rounded,
              text: '首次登录时即可完成静默恢复能力校验',
              color: c.subtitle,
            ),
            const SizedBox(height: 6),
            _GuideLine(
              icon: Icons.verified_user_outlined,
              text: '若出现“信任当前设备 / 180天”，建议勾选',
              color: c.subtitle,
            ),
            const SizedBox(height: 6),
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
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
