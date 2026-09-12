import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/wallpaper_provider.dart';
import 'app_surfaces.dart';
import 'app_theme_colors.dart';
import 'app_toast.dart';
import 'typography.dart';
import 'wallpaper.dart';
import 'wallpaper_crop_editor.dart';
import '../wallpaper/custom_wallpaper.dart';

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

class _WallpaperPicker extends ConsumerStatefulWidget {
  const _WallpaperPicker();

  @override
  ConsumerState<_WallpaperPicker> createState() => _WallpaperPickerState();
}

class _WallpaperPickerState extends ConsumerState<_WallpaperPicker> {
  bool _busy = false;

  Future<void> _import([CustomWallpaper? existing]) async {
    setState(() => _busy = true);
    try {
      String path;
      String name;
      if (existing != null) {
        path = existing.sourcePath;
        name = existing.name;
      } else {
        final picked = await FilePicker.platform.pickFiles(
          type: FileType.image,
          dialogTitle: '选择背景图片',
          allowMultiple: false,
        );
        if (picked == null) return;
        final file = picked.files.single;
        if (file.path == null) {
          throw const FileSystemException('Image has no local path');
        }
        path = file.path!;
        name = file.name;
      }
      if (!mounted) return;
      final intensity =
          ref.read(wallpaperIntensitiesProvider)[StudyWallpaper.custom] ?? 30;
      await showWallpaperCropEditor(
        context,
        sourcePath: path,
        initialCrop: existing?.crop,
        initialIntensity: intensity,
        onApply: (bytes, crop, value) async {
          await ref.read(wallpaperProvider.notifier).applyCustom(() async {
            await ref
                .read(customWallpaperProvider.notifier)
                .save(
                  sourcePath: path,
                  name: name,
                  crop: crop,
                  imageBytes: bytes,
                  intensity: value,
                );
            ref
                .read(wallpaperIntensitiesProvider.notifier)
                .preview(StudyWallpaper.custom, value);
          });
        },
      );
    } catch (_) {
      if (mounted) AppToast.showWarning(context, message: '图片未能打开，请重新选择');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      if (ref.read(wallpaperProvider) == StudyWallpaper.custom) {
        await ref
            .read(wallpaperProvider.notifier)
            .select(
              StudyWallpaper.defaultFor(
                forMobile: ref.read(mobileWallpapersProvider),
              ),
            );
      }
      await ref.read(customWallpaperProvider.notifier).remove();
    } catch (_) {
      if (mounted) AppToast.showWarning(context, message: '自定义背景未能移除');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(effectiveWallpaperProvider);
    final custom = ref.watch(customWallpaperProvider).valueOrNull;
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
                    onPressed: _busy ? null : () => Navigator.of(context).pop(),
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
              const SizedBox(height: 16),
              if (custom != null) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  selected: selected == StudyWallpaper.custom,
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(custom.imagePath),
                      width: 48,
                      height: 56,
                      fit: BoxFit.cover,
                      cacheWidth: 144,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_not_supported_outlined),
                    ),
                  ),
                  title: const Text('自定义背景'),
                  subtitle: Text(
                    custom.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: selected == StudyWallpaper.custom
                      ? Icon(Icons.check_circle, color: c.infoAccent)
                      : null,
                  onTap: _busy
                      ? null
                      : () async {
                          try {
                            await ref
                                .read(wallpaperProvider.notifier)
                                .select(StudyWallpaper.custom);
                          } catch (_) {
                            if (context.mounted) {
                              AppToast.showWarning(
                                context,
                                message: '背景设置未能保存',
                              );
                            }
                          }
                        },
                ),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : () => _import(custom),
                      icon: const Icon(Icons.crop, size: 18),
                      label: const Text('重新裁剪'),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '移除自定义背景',
                      onPressed: _busy ? null : _remove,
                      icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    ),
                  ],
                ),
              ],
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _import(),
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                label: Text(custom == null ? '上传自定义背景' : '更换自定义图片'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
