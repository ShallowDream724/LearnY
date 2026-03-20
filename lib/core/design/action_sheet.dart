/// Reusable iOS-style action sheet — used for confirm, discard, destructive actions.
///
/// Usage:
///   final confirmed = await AppActionSheet.show(context,
///     title: '确认提交？',
///     subtitle: '提交后仍可重新提交',
///     confirmLabel: '提交',
///   );
///   if (confirmed == true) doSubmit();
library;

import 'package:flutter/material.dart';

import 'app_theme_colors.dart';
import 'colors.dart';
import 'typography.dart';

abstract final class AppActionSheet {
  /// Show an iOS-style dual-card action sheet.
  ///
  /// Returns `true` if user tapped confirm, `false` or `null` otherwise.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String confirmLabel,
    Color confirmColor = AppColors.primary,
    FontWeight confirmWeight = FontWeight.w600,
    String cancelLabel = '取消',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final c = ctx.colors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top card — title + confirm action
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(title,
                            style: AppTypography.titleSmall
                                .copyWith(color: c.text)),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(subtitle,
                              style: AppTypography.bodySmall
                                  .copyWith(color: c.subtitle)),
                        ),
                      const Divider(height: 1),
                      InkWell(
                        onTap: () => Navigator.of(ctx).pop(true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            confirmLabel,
                            textAlign: TextAlign.center,
                            style: AppTypography.titleSmall.copyWith(
                              color: confirmColor,
                              fontWeight: confirmWeight,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Bottom card — cancel
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: InkWell(
                    onTap: () => Navigator.of(ctx).pop(false),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(cancelLabel,
                          textAlign: TextAlign.center,
                          style: AppTypography.titleSmall
                              .copyWith(color: c.text)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
