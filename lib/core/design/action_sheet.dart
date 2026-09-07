import 'package:flutter/material.dart';

import 'responsive.dart';

abstract final class AppActionSheet {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String confirmLabel,
    Color? confirmColor,
    FontWeight confirmWeight = FontWeight.w600,
    String cancelLabel = '取消',
  }) {
    Widget confirm(BuildContext routeContext) => TextButton(
      style: TextButton.styleFrom(
        foregroundColor: confirmColor,
        textStyle: TextStyle(fontWeight: confirmWeight),
      ),
      onPressed: () => Navigator.pop(routeContext, true),
      child: Text(confirmLabel),
    );
    Widget cancel(BuildContext routeContext) => TextButton(
      onPressed: () => Navigator.pop(routeContext, false),
      child: Text(cancelLabel),
    );
    if (usesDesktopControls(context) || shouldShowRail(context)) {
      return showDialog<bool>(
        context: context,
        builder: (routeContext) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: subtitle == null ? null : Text(subtitle),
          actions: [cancel(routeContext), confirm(routeContext)],
        ),
      );
    }
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (routeContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle),
              ],
              const SizedBox(height: 16),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                children: [cancel(routeContext), confirm(routeContext)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
