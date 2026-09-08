import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/app_materials.dart';
import '../../../core/design/app_surfaces.dart';
import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/course_icons/course_icon.dart';
import '../../../core/design/course_icons/course_icon_catalog.dart';
import '../../../core/design/responsive.dart';
import '../../../core/design/typography.dart';

@immutable
class CourseIconPickerResult {
  const CourseIconPickerResult({
    required this.submitted,
    required this.iconKey,
  });
  final bool submitted;
  final String? iconKey;
}

Future<CourseIconPickerResult?> showCourseIconPickerSheet(
  BuildContext context, {
  required String? selectedIconKey,
  String courseName = '',
  String courseId = '',
}) {
  Widget content(BuildContext context) => CourseIconPicker(
    selectedIconKey: selectedIconKey,
    courseName: courseName,
    courseId: courseId,
  );
  if (MediaQuery.sizeOf(context).width >= 600) {
    return showDialog<CourseIconPickerResult>(
      context: context,
      builder: (context) => Dialog(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: 680,
          height: math.min(700, MediaQuery.sizeOf(context).height * .84),
          child: content(context),
        ),
      ),
    );
  }
  return showModalBottomSheet<CourseIconPickerResult>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    clipBehavior: Clip.antiAlias,
    sheetAnimationStyle: AnimationStyle(duration: AppMotion.duration(context)),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: math.min(
          MediaQuery.sizeOf(context).height * .84,
          MediaQuery.sizeOf(context).height -
              MediaQuery.viewInsetsOf(context).bottom -
              64,
        ),
        child: content(context),
      ),
    ),
  );
}

class CourseIconPicker extends StatefulWidget {
  const CourseIconPicker({
    super.key,
    required this.selectedIconKey,
    required this.courseName,
    required this.courseId,
  });
  final String? selectedIconKey;
  final String courseName;
  final String courseId;

  @override
  State<CourseIconPicker> createState() => _CourseIconPickerState();
}

class _CourseIconPickerState extends State<CourseIconPicker> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _group;

  @override
  void dispose() {
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _filterChanged() {
    setState(() {});
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _select(String? key) => Navigator.of(
    context,
  ).pop(CourseIconPickerResult(submitted: true, iconKey: key));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = StudyPalette.of(
      context,
      StudyPalette.course(widget.courseId),
    ).accent;
    final selected = courseIconFor(
      key: widget.selectedIconKey,
      courseName: widget.courseName,
    );
    final query = _search.text.trim();
    final visible = courseIconOptions
        .where(
          (icon) =>
              (_group == null || icon.group == _group) && icon.matches(query),
        )
        .toList(growable: false);
    final showDefault = query.isEmpty && _group == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
          child: Row(
            children: [
              CourseIcon(option: selected, color: accent, size: 40),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '课程图标',
                      style: AppTypography.titleLarge.copyWith(color: c.text),
                    ),
                    if (widget.courseName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.courseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: c.subtitle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            controller: _search,
            onChanged: (_) => _filterChanged(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索图标',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: '清空搜索',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _search.clear();
                        _filterChanged();
                      },
                    ),
            ),
          ),
        ),
        _buildGroups(context, accent),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '没有找到图标',
                        style: AppTypography.bodyMedium.copyWith(
                          color: c.subtitle,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          _search.clear();
                          _group = null;
                          _filterChanged();
                        },
                        child: const Text('显示全部'),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context);
                    final columns =
                        ((constraints.maxWidth - 48) / textScale.scale(86))
                            .floor()
                            .clamp(2, 7);
                    final cellHeight = 64 + textScale.scale(13) * 1.4;
                    return Scrollbar(
                      controller: _scroll,
                      thumbVisibility: usesDesktopControls(context),
                      child: GridView.builder(
                        controller: _scroll,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          20 + MediaQuery.paddingOf(context).bottom,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisExtent: cellHeight,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: visible.length + (showDefault ? 1 : 0),
                        itemBuilder: (context, index) {
                          final isDefault = showDefault && index == 0;
                          final option = isDefault
                              ? defaultCourseIcon(widget.courseName)
                              : visible[index - (showDefault ? 1 : 0)];
                          final label = isDefault ? '默认' : option.label;
                          final active = isDefault
                              ? widget.selectedIconKey == null
                              : widget.selectedIconKey == option.key;
                          return _IconChoice(
                            key: ValueKey(
                              isDefault ? 'default-icon' : option.key,
                            ),
                            label: label,
                            option: option,
                            accent: accent,
                            selected: active,
                            onTap: () => _select(isDefault ? null : option.key),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGroups(BuildContext context, Color accent) {
    final choices = [
      for (final group in [null, ...courseIconGroups])
        ChoiceChip(
          label: Text(group ?? '全部'),
          labelStyle: AppTypography.labelMedium.copyWith(
            color: group == _group ? accent : context.colors.subtitle,
          ),
          selected: group == _group,
          selectedColor: accent.withAlpha(context.isDark ? 40 : 20),
          side: BorderSide(
            color: group == _group ? accent.withAlpha(95) : Colors.transparent,
            width: .7,
          ),
          showCheckmark: false,
          onSelected: (_) {
            _group = group;
            _filterChanged();
          },
        ),
    ];
    const padding = EdgeInsets.fromLTRB(24, 4, 24, 12);
    if (usesDesktopControls(context)) {
      return Padding(
        padding: padding,
        child: Wrap(spacing: 8, runSpacing: 4, children: choices),
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final choice in choices)
            Padding(padding: const EdgeInsets.only(right: 8), child: choice),
        ],
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  const _IconChoice({
    super.key,
    required this.label,
    required this.option,
    required this.accent,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final CourseIconOption option;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = BorderRadius.circular(14);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: selected
              ? accent.withAlpha(context.isDark ? 28 : 15)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: border,
            side: BorderSide(
              color: selected ? accent.withAlpha(140) : Colors.transparent,
              width: .8,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: border,
            child: ExcludeSemantics(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CourseIcon(option: option, color: accent),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      color: selected ? accent : context.colors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
