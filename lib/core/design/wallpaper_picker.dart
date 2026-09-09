import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wallpaper_provider.dart';
import 'app_surfaces.dart';
import 'app_theme_colors.dart';
import 'app_toast.dart';
import 'typography.dart';
import 'wallpaper.dart';

/// Keep the actual page visible, at its real brightness, while trying images.
/// Selection applies immediately; outside tap, back/Escape and close dismiss.
Future<void> showWallpaperPicker(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: context.colors.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      sheetAnimationStyle: AnimationStyle(
        duration: AppMotion.duration(context),
      ),
      builder: (_) => const _WallpaperPicker(),
    );

class _WallpaperPicker extends ConsumerWidget {
  const _WallpaperPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(wallpaperProvider);
    final intensity = ref.watch(wallpaperIntensityProvider);
    final mobile = ref.watch(mobileWallpapersProvider);
    final choices = StudyWallpaper.choices(forMobile: mobile);
    final c = context.colors;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .65,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '背景',
                      style: AppTypography.titleLarge.copyWith(color: c.text),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(CupertinoIcons.xmark, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '背景强度',
                      style: AppTypography.bodyMedium.copyWith(color: c.text),
                    ),
                  ),
                  Text(
                    '$intensity%',
                    style: AppTypography.bodyMedium.copyWith(color: c.subtitle),
                  ),
                ],
              ),
              Slider(
                value: intensity.toDouble(),
                min: 0,
                max: 100,
                divisions: 100,
                label: '$intensity%',
                semanticFormatterCallback: (value) => '背景强度 ${value.round()}%',
                onChanged: (value) => ref
                    .read(wallpaperIntensitiesProvider.notifier)
                    .preview(selected, value.round()),
                onChangeEnd: (_) async {
                  try {
                    await ref
                        .read(wallpaperIntensitiesProvider.notifier)
                        .save(selected);
                  } catch (_) {
                    if (context.mounted) {
                      AppToast.showWarning(context, message: '背景强度未能保存');
                    }
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '隐藏',
                      style: AppTypography.bodySmall.copyWith(
                        color: c.tertiary,
                      ),
                    ),
                    Text(
                      '原图',
                      style: AppTypography.bodySmall.copyWith(
                        color: c.tertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final textScale =
                      MediaQuery.textScalerOf(context).scale(14) / 14;
                  final minWidth = mobile ? 64 * textScale : 140;
                  final columns =
                      ((constraints.maxWidth + 12) / (minWidth + 12))
                          .floor()
                          .clamp(1, 4);
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final wallpaper in choices)
                        SizedBox(
                          width: width,
                          child: Semantics(
                            button: true,
                            selected: selected == wallpaper,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () async {
                                  try {
                                    await ref
                                        .read(wallpaperProvider.notifier)
                                        .select(wallpaper);
                                  } catch (_) {
                                    if (context.mounted) {
                                      AppToast.showWarning(
                                        context,
                                        message: '背景已切换，但未能保存设置',
                                      );
                                    }
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(5),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: selected == wallpaper
                                                ? c.infoAccent
                                                : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: AspectRatio(
                                            aspectRatio: mobile
                                                ? 9 / 19.5
                                                : 16 / 9,
                                            child: Image.asset(
                                              wallpaper
                                                  .artwork(forMobile: mobile)
                                                  .thumbnail,
                                              fit: BoxFit.cover,
                                              excludeFromSemantics: true,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        wallpaper.label,
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              color: selected == wallpaper
                                                  ? c.infoAccent
                                                  : c.text,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
