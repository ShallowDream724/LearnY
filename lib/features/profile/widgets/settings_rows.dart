import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/typography.dart';

class SettingsSectionLabel extends StatelessWidget {
  const SettingsSectionLabel({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Text(
      label,
      style: AppTypography.labelSmall.copyWith(color: context.colors.subtitle),
    ),
  );
}

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (var index = 0; index < children.length; index++) ...[
        if (index > 0) const SizedBox(height: 6),
        children[index],
      ],
    ],
  );
}

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingColor,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? trailingColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Icon(icon, size: 22, color: c.subtitle),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(color: c.text),
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
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => SettingsRow(
    icon: icon,
    title: title,
    subtitle: subtitle,
    onTap: onChanged == null ? null : () => onChanged!(!value),
    trailing: Switch.adaptive(value: value, onChanged: onChanged),
  );
}
