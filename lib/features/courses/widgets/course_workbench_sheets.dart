import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/app_surfaces.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../providers/course_workbench_models.dart';

enum CourseWorkbenchMenuAction {
  chooseIcon,
  editAlias,
  restoreDefault,
  moveEarlier,
  moveLater,
}

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
  bool canMoveEarlier = false,
  bool canMoveLater = false,
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
            if (card.displayTitle != card.course.name)
              Text(
                card.course.name,
                style: AppTypography.bodySmall.copyWith(color: c.subtitle),
              ),
            const SizedBox(height: 16),
            _WorkbenchCardGroup(
              children: [
                if (canMoveEarlier)
                  _WorkbenchActionTile(
                    icon: Icons.arrow_upward_rounded,
                    title: '向前移动',
                    subtitle: '',
                    onTap: () => Navigator.of(
                      context,
                    ).pop(CourseWorkbenchMenuAction.moveEarlier),
                  ),
                if (canMoveLater)
                  _WorkbenchActionTile(
                    icon: Icons.arrow_downward_rounded,
                    title: '向后移动',
                    subtitle: '',
                    onTap: () => Navigator.of(
                      context,
                    ).pop(CourseWorkbenchMenuAction.moveLater),
                  ),
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
            const SizedBox(height: 16),
            _WorkbenchCardGroup(
              children: [
                _WorkbenchActionTile(
                  icon: Icons.refresh_rounded,
                  title: '恢复默认图标',
                  subtitle: '',
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
  return _showWorkbenchSheet<CourseAliasEditorResult>(
    context,
    respectKeyboard: true,
    child: _CourseAliasEditor(card: card),
  );
}

class _CourseAliasEditor extends StatefulWidget {
  const _CourseAliasEditor({required this.card});
  final ResolvedCourseCardModel card;

  @override
  State<_CourseAliasEditor> createState() => _CourseAliasEditorState();
}

class _CourseAliasEditorState extends State<_CourseAliasEditor> {
  late final controller = TextEditingController(text: widget.card.alias ?? '');

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('设置简称', style: AppTypography.titleLarge.copyWith(color: c.text)),
        const SizedBox(height: 6),
        Text(
          card.course.name,
          style: AppTypography.bodySmall.copyWith(color: c.subtitle),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: controller,
          maxLength: 10,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: '课程简称',
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
              borderSide: const BorderSide(color: AppColors.primary, width: 1),
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
  }
}

Future<T?> _showWorkbenchSheet<T>(
  BuildContext context, {
  required Widget child,
  double maxHeightFactor = 0.62,
  bool scrollable = false,
  bool respectKeyboard = false,
}) {
  Widget content(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxWidth: 560,
      maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: '关闭',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: child,
          ),
        ),
      ],
    ),
  );
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(child: content(context)),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    sheetAnimationStyle: AnimationStyle(duration: AppMotion.duration(context)),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: respectKeyboard ? MediaQuery.viewInsetsOf(context).bottom : 0,
      ),
      child: content(context),
    ),
  );
}

String? _normalizeAlias(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return null;
  }
  return normalized;
}

class _WorkbenchCardGroup extends StatelessWidget {
  const _WorkbenchCardGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(children: children);
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
        borderRadius: BorderRadius.circular(8),
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
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTypography.bodySmall.copyWith(
                          color: c.subtitle,
                        ),
                      ),
                    ],
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
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
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
