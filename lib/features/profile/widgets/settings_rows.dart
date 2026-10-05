import 'package:flutter/material.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';

class _SettingsGroupHeading extends StatelessWidget {
  const _SettingsGroupHeading({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        header: true,
        child: Text(
          label,
          style: AppTypography.titleSmall.copyWith(
            color: context.colors.subtitle,
          ),
        ),
      ),
    ),
  );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.children,
    required this.label,
    this.tone = StudyTone.slate,
  });
  final List<Widget> children;
  final String label;
  final StudyTone tone;

  @override
  Widget build(BuildContext context) => StudySurface(
    tone: tone,
    child: Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: _SettingsGroupHeading(label: label),
        ),
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0)
            Divider(
              height: 1,
              thickness: .7,
              indent: 20,
              endIndent: 20,
              color: StudyPalette.of(context, tone).edge.withAlpha(130),
            ),
          children[index],
        ],
      ],
    ),
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.trailingColor,
    this.onTap,
    this.trailing,
    this.onDetails,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final Color? trailingColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: c.subtitle),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppTypography.titleMedium.copyWith(
                              color: c.text,
                            ),
                          ),
                        ),
                        if (onDetails != null) ...[
                          const SizedBox(width: 6),
                          TextButton(
                            onPressed: onDetails,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              minimumSize: const Size(44, 36),
                              foregroundColor: c.infoAccent,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('详情'),
                          ),
                        ],
                      ],
                    ),
                    if (subtitle?.isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: AppTypography.bodySmall.copyWith(
                          color: trailingColor ?? c.subtitle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 16),
                trailing!,
              ] else if (onTap != null) ...[
                const SizedBox(width: 12),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: trailingColor ?? c.tertiary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.onDetails,
  });

  final IconData? icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onDetails: onDetails,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: Switch.adaptive(value: value, onChanged: onChanged),
  );
}
