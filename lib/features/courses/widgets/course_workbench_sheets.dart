import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../providers/course_workbench_models.dart';

enum CourseWorkbenchMenuAction { chooseIcon, editAlias, restoreDefault }

@immutable
class CourseIconPickerResult {
  const CourseIconPickerResult({
    required this.submitted,
    required this.iconKey,
  });

  final bool submitted;
  final String? iconKey;
}

@immutable
class CourseAliasEditorResult {
  const CourseAliasEditorResult({required this.submitted, required this.alias});

  final bool submitted;
  final String? alias;
}

Future<CourseWorkbenchMenuAction?> showCourseWorkbenchMenu(
  BuildContext context, {
  required ResolvedCourseCardModel card,
}) {
  return _showWorkbenchSheet<CourseWorkbenchMenuAction>(
    context,
    child: Builder(
      builder: (context) {
        final c = context.colors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.displayTitle,
              style: AppTypography.titleLarge.copyWith(color: c.text),
            ),
            const SizedBox(height: 6),
            Text(
              card.course.name,
              style: AppTypography.bodySmall.copyWith(color: c.subtitle),
            ),
            const SizedBox(height: 16),
            _WorkbenchCardGroup(
              children: [
                _WorkbenchActionTile(
                  icon: Icons.grid_view_rounded,
                  title: '更换图标',
                  subtitle:
                      resolveCourseIconOption(card.iconKey)?.label ??
                      '当前使用默认图标',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(CourseWorkbenchMenuAction.chooseIcon),
                ),
                _WorkbenchActionTile(
                  icon: Icons.short_text_rounded,
                  title: '设置简称',
                  subtitle: card.alias?.trim().isNotEmpty == true
                      ? card.alias!.trim()
                      : '当前未设置简称',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(CourseWorkbenchMenuAction.editAlias),
                ),
                _WorkbenchActionTile(
                  icon: Icons.restart_alt_rounded,
                  title: '恢复默认',
                  subtitle: '清除图标与简称自定义',
                  onTap: () => Navigator.of(
                    context,
                  ).pop(CourseWorkbenchMenuAction.restoreDefault),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Future<CourseIconPickerResult?> showCourseIconPickerSheet(
  BuildContext context, {
  required String? selectedIconKey,
}) {
  return _showWorkbenchSheet<CourseIconPickerResult>(
    context,
    maxHeightFactor: 0.84,
    scrollable: true,
    child: Builder(
      builder: (context) {
        final c = context.colors;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '课程图标',
              style: AppTypography.titleLarge.copyWith(color: c.text),
            ),
            const SizedBox(height: 6),
            Text(
              '受控图标库会继续扩展，但不会开放成杂乱的应用图标墙。',
              style: AppTypography.bodySmall.copyWith(color: c.subtitle),
            ),
            const SizedBox(height: 16),
            _WorkbenchCardGroup(
              children: [
                _WorkbenchActionTile(
                  icon: Icons.refresh_rounded,
                  title: '恢复默认图标',
                  subtitle: '回到首字与默认图标位',
                  selected: selectedIconKey == null,
                  onTap: () => Navigator.of(context).pop(
                    const CourseIconPickerResult(
                      submitted: true,
                      iconKey: null,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final group in courseIconGroups) ...[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Text(
                  group,
                  style: AppTypography.labelMedium.copyWith(color: c.tertiary),
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final option in courseIconOptions.where(
                    (item) => item.group == group,
                  ))
                    _CourseIconOptionTile(
                      option: option,
                      selected: option.key == selectedIconKey,
                      onTap: () => Navigator.of(context).pop(
                        CourseIconPickerResult(
                          submitted: true,
                          iconKey: option.key,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        );
      },
    ),
  );
}

Future<CourseAliasEditorResult?> showCourseAliasEditorSheet(
  BuildContext context, {
  required ResolvedCourseCardModel card,
}) {
  final controller = TextEditingController(text: card.alias ?? '');
  return _showWorkbenchSheet<CourseAliasEditorResult>(
    context,
    respectKeyboard: true,
    child: Builder(
      builder: (context) {
        final c = context.colors;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置简称',
              style: AppTypography.titleLarge.copyWith(color: c.text),
            ),
            const SizedBox(height: 6),
            Text(
              '建议 2 到 4 个字，最多 6 个中文字符。留空会恢复默认课程名。',
              style: AppTypography.bodySmall.copyWith(color: c.subtitle),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              maxLength: 10,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: card.course.name,
                counterText: '',
                filled: true,
                fillColor: c.surfaceHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.border, width: 0.5),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: c.border, width: 0.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1,
                  ),
                ),
              ),
              onSubmitted: (value) {
                Navigator.of(context).pop(
                  CourseAliasEditorResult(
                    submitted: true,
                    alias: _normalizeAlias(value),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        CourseAliasEditorResult(
                          submitted: true,
                          alias: _normalizeAlias(controller.text),
                        ),
                      );
                    },
                    child: const Text('完成'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  ).whenComplete(controller.dispose);
}

Future<T?> _showWorkbenchSheet<T>(
  BuildContext context, {
  required Widget child,
  double maxHeightFactor = 0.62,
  bool scrollable = false,
  bool respectKeyboard = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: Colors.black.withAlpha(68),
    barrierDismissible: true,
    barrierLabel: '关闭',
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (sheetContext, animation, secondaryAnimation) {
      final bottomInset = respectKeyboard
          ? MediaQuery.viewInsetsOf(sheetContext).bottom
          : 0.0;
      final maxHeight =
          MediaQuery.sizeOf(sheetContext).height * maxHeightFactor;

      return Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(sheetContext).maybePop(),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.deferToChild,
                  onTap: () {},
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: _WorkbenchSheetSurface(
                      child: scrollable
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                              child: child,
                            )
                          : Padding(
                              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
                              child: child,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (sheetContext, animation, secondaryAnimation, dialog) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.08),
            end: Offset.zero,
          ).animate(curved),
          child: dialog,
        ),
      );
    },
  );
}

String? _normalizeAlias(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

class _WorkbenchSheetSurface extends StatelessWidget {
  const _WorkbenchSheetSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? c.surface.withAlpha(238)
                : Colors.white.withAlpha(238),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(14)
                  : c.border.withAlpha(140),
              width: 0.6,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(isDark ? 36 : 18),
                blurRadius: 30,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 8),
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.tertiary.withAlpha(isDark ? 86 : 70),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkbenchCardGroup extends StatelessWidget {
  const _WorkbenchCardGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceHigh.withAlpha(context.isDark ? 204 : 232),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border.withAlpha(120), width: 0.5),
      ),
      child: Column(children: children),
    );
  }
}

class _WorkbenchActionTile extends StatelessWidget {
  const _WorkbenchActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(context.isDark ? 34 : 16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: c.text),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall.copyWith(color: c.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.bodySmall.copyWith(
                        color: c.subtitle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                size: selected ? 20 : 18,
                color: selected ? AppColors.primary : c.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseIconOptionTile extends StatelessWidget {
  const _CourseIconOptionTile({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final CourseIconOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: selected
          ? AppColors.primary.withAlpha(context.isDark ? 34 : 14)
          : c.surfaceHigh.withAlpha(context.isDark ? 180 : 216),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : c.border,
              width: selected ? 1 : 0.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withAlpha(context.isDark ? 48 : 18)
                      : c.surface,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  option.icon,
                  size: 18,
                  color: selected ? AppColors.primary : c.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                option.label,
                textAlign: TextAlign.center,
                style: AppTypography.labelSmall.copyWith(
                  color: selected ? AppColors.primary : c.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
