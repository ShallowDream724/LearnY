import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/design/colors.dart';

class FileTypeFilterButton extends StatefulWidget {
  const FileTypeFilterButton({
    super.key,
    required this.currentFilter,
    required this.typeCounts,
    required this.onChanged,
  });

  final String? currentFilter;
  final Map<String, int> typeCounts;
  final ValueChanged<String?> onChanged;

  @override
  State<FileTypeFilterButton> createState() => _FileTypeFilterButtonState();
}

class _FileTypeFilterButtonState extends State<FileTypeFilterButton> {
  final _buttonKey = GlobalKey();

  void _showMenu() {
    final renderBox =
        _buttonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final sortedTypes = widget.typeCounts.keys.toList()
      ..sort(
        (a, b) =>
            (widget.typeCounts[b] ?? 0).compareTo(widget.typeCounts[a] ?? 0),
      );

    Navigator.of(context).push(
      _TypeFilterPopupRoute(
        buttonRect: Rect.fromLTWH(
          offset.dx,
          offset.dy + size.height + 8,
          size.width,
          size.height,
        ),
        types: sortedTypes,
        counts: widget.typeCounts,
        currentFilter: widget.currentFilter,
        isDark: context.isDark,
        totalCount: widget.typeCounts.values.fold(
          0,
          (sum, count) => sum + count,
        ),
        onSelected: (type) {
          widget.onChanged(type);
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isFiltered = widget.currentFilter != null;
    final label = isFiltered ? widget.currentFilter!.toUpperCase() : '全部类型';

    return GestureDetector(
      key: _buttonKey,
      onTap: widget.typeCounts.isEmpty ? null : _showMenu,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isFiltered
              ? AppColors.primary.withAlpha(context.isDark ? 40 : 25)
              : c.surfaceHigh,
          borderRadius: BorderRadius.circular(20),
          border: isFiltered
              ? Border.all(color: AppColors.primary.withAlpha(80), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFiltered ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              size: 14,
              color: isFiltered ? AppColors.primary : c.subtitle,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isFiltered ? FontWeight.w600 : FontWeight.w500,
                color: isFiltered ? AppColors.primary : c.subtitle,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: isFiltered ? AppColors.primary : c.tertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeFilterPopupRoute extends PopupRoute<void> {
  _TypeFilterPopupRoute({
    required this.buttonRect,
    required this.types,
    required this.counts,
    required this.currentFilter,
    required this.isDark,
    required this.totalCount,
    required this.onSelected,
  });

  final Rect buttonRect;
  final List<String> types;
  final Map<String, int> counts;
  final String? currentFilter;
  final bool isDark;
  final int totalCount;
  final ValueChanged<String?> onSelected;

  @override
  Color? get barrierColor => Colors.black.withAlpha(isDark ? 80 : 50);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final c = context.colors;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(onTap: () => Navigator.of(context).pop()),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: buttonRect.bottom,
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, -0.04),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color:
                          (isDark
                                  ? AppColors.darkSurface
                                  : AppColors.lightSurface)
                              .withAlpha(isDark ? 235 : 245),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: c.border.withAlpha(isDark ? 120 : 160),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 35 : 12),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '按文件类型筛选',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '共 $totalCount 个文件',
                          style: TextStyle(fontSize: 12, color: c.tertiary),
                        ),
                        const SizedBox(height: 14),
                        _TypeOption(
                          label: '全部类型',
                          count: totalCount,
                          isSelected: currentFilter == null,
                          onTap: () => onSelected(null),
                        ).animate().fadeIn(duration: 160.ms),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: types.asMap().entries.map((entry) {
                            final index = entry.key;
                            final type = entry.value;
                            return _TypeOption(
                                  label: type.toUpperCase(),
                                  count: counts[type] ?? 0,
                                  isSelected: currentFilter == type,
                                  onTap: () => onSelected(type),
                                )
                                .animate(delay: (index * 18).ms)
                                .fadeIn(duration: 150.ms)
                                .slideY(begin: 0.12, end: 0);
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withAlpha(context.isDark ? 36 : 16)
                : c.surfaceHigh.withAlpha(context.isDark ? 180 : 255),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withAlpha(90)
                  : c.border.withAlpha(120),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? AppColors.primary : c.text,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.primary : c.tertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
