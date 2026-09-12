import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../design/wallpaper.dart';
import '../wallpaper/custom_wallpaper.dart';
import '../wallpaper/custom_wallpaper_repository.dart';
import 'app_providers.dart';

/// Device collection stays stable when a phone rotates or a desktop resizes.
final mobileWallpapersProvider = Provider<bool>(
  (ref) =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS,
);

class WallpaperNotifier extends StateNotifier<StudyWallpaper> {
  WallpaperNotifier(this._database, {this.forMobile = false})
    : super(StudyWallpaper.defaultFor(forMobile: forMobile)) {
    _load();
  }

  final AppDatabase _database;
  final bool forMobile;
  bool _userSelected = false;
  Future<void> _pendingWrite = Future.value();

  Future<void> _load() async {
    final saved = await _database.getState(AppStateKeys.wallpaper);
    if (mounted && !_userSelected) {
      state = StudyWallpaper.fromId(saved, forMobile: forMobile);
    }
  }

  Future<void> select(StudyWallpaper wallpaper) {
    if (wallpaper != StudyWallpaper.custom &&
        !StudyWallpaper.choices(forMobile: forMobile).contains(wallpaper)) {
      throw ArgumentError.value(
        wallpaper,
        'wallpaper',
        'Unavailable on this device',
      );
    }
    _userSelected = true;
    state = wallpaper;
    // Preserve the user's final choice when rapidly comparing several images.
    final write = _pendingWrite.then(
      (_) => _database.setState(AppStateKeys.wallpaper, wallpaper.id),
    );
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }

  Future<void> applyCustom(Future<void> Function() save) {
    _userSelected = true;
    final write = _pendingWrite.then((_) async {
      await save();
      if (mounted) state = StudyWallpaper.custom;
    });
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }
}

final wallpaperProvider =
    StateNotifierProvider<WallpaperNotifier, StudyWallpaper>(
      (ref) => WallpaperNotifier(
        ref.watch(databaseProvider),
        forMobile: ref.watch(mobileWallpapersProvider),
      ),
    );

class WallpaperIntensityNotifier
    extends StateNotifier<Map<StudyWallpaper, int>> {
  WallpaperIntensityNotifier(this._database) : super(const {}) {
    _load();
  }

  static const defaultIntensity = 30;
  final AppDatabase _database;
  final _edited = <StudyWallpaper>{};
  Future<void> _pendingWrite = Future.value();

  Future<void> _load() async {
    final saved = await Future.wait([
      for (final wallpaper in StudyWallpaper.values)
        _database.getState(AppStateKeys.wallpaperIntensity(wallpaper.id)),
    ]);
    if (!mounted) return;
    final values = {...state};
    for (var i = 0; i < saved.length; i++) {
      final wallpaper = StudyWallpaper.values[i];
      final value = int.tryParse(saved[i] ?? '');
      if (!_edited.contains(wallpaper) && value != null) {
        values[wallpaper] = value.clamp(0, 100);
      }
    }
    state = values;
  }

  void preview(StudyWallpaper wallpaper, int value) {
    _edited.add(wallpaper);
    state = {...state, wallpaper: value.clamp(0, 100)};
  }

  Future<void> save(StudyWallpaper wallpaper) {
    final value = state[wallpaper] ?? defaultIntensity;
    final write = _pendingWrite.then(
      (_) => _database.setState(
        AppStateKeys.wallpaperIntensity(wallpaper.id),
        value.toString(),
      ),
    );
    _pendingWrite = write.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return write;
  }
}

final wallpaperIntensitiesProvider =
    StateNotifierProvider<WallpaperIntensityNotifier, Map<StudyWallpaper, int>>(
      (ref) => WallpaperIntensityNotifier(ref.watch(databaseProvider)),
    );

final wallpaperIntensityProvider = Provider<int>((ref) {
  final wallpaper = ref.watch(wallpaperProvider);
  return ref.watch(
    wallpaperIntensitiesProvider.select(
      (values) =>
          values[wallpaper] ?? WallpaperIntensityNotifier.defaultIntensity,
    ),
  );
});

final customWallpaperRepositoryProvider = Provider(
  (ref) => CustomWallpaperRepository(ref.watch(databaseProvider)),
);

class CustomWallpaperNotifier
    extends StateNotifier<AsyncValue<CustomWallpaper?>> {
  CustomWallpaperNotifier(this.repository) : super(const AsyncLoading()) {
    _load();
  }
  final CustomWallpaperRepository repository;
  bool _changed = false;

  Future<void> _load() async {
    try {
      final wallpaper = await repository.load();
      if (mounted && !_changed) state = AsyncData(wallpaper);
    } catch (error, stack) {
      if (mounted && !_changed) state = AsyncError(error, stack);
    }
  }

  Future<void> save({
    required String sourcePath,
    required String name,
    required Rect crop,
    required Uint8List imageBytes,
    required int intensity,
  }) async {
    _changed = true;
    final old = state.valueOrNull;
    final saved = await repository.save(
      sourcePath: sourcePath,
      name: name,
      crop: crop,
      imageBytes: imageBytes,
      intensity: intensity,
    );
    if (mounted) state = AsyncData(saved);
    if (old != null) await FileImage(File(old.imagePath)).evict();
  }

  Future<void> remove() async {
    _changed = true;
    final old = state.valueOrNull;
    await repository.remove();
    if (mounted) state = const AsyncData(null);
    if (old != null) await FileImage(File(old.imagePath)).evict();
  }
}

final customWallpaperProvider =
    StateNotifierProvider<
      CustomWallpaperNotifier,
      AsyncValue<CustomWallpaper?>
    >(
      (ref) =>
          CustomWallpaperNotifier(ref.watch(customWallpaperRepositoryProvider)),
    );

/// Missing/deleted custom files fall back while the persisted choice loads.
final effectiveWallpaperProvider = Provider<StudyWallpaper>((ref) {
  final selected = ref.watch(wallpaperProvider);
  if (selected == StudyWallpaper.custom &&
      ref.watch(customWallpaperProvider).valueOrNull == null) {
    return StudyWallpaper.defaultFor(
      forMobile: ref.watch(mobileWallpapersProvider),
    );
  }
  return selected;
});

final wallpaperImageProvider = Provider.family<ImageProvider, Brightness>((
  ref,
  brightness,
) {
  final wallpaper = ref.watch(effectiveWallpaperProvider);
  if (wallpaper == StudyWallpaper.custom) {
    return FileImage(
      File(ref.watch(customWallpaperProvider).requireValue!.imagePath),
    );
  }
  return AssetImage(
    wallpaper.assetFor(
      brightness,
      forMobile: ref.watch(mobileWallpapersProvider),
    ),
  );
});

final wallpaperThumbnailProvider = Provider<ImageProvider>((ref) {
  final wallpaper = ref.watch(effectiveWallpaperProvider);
  if (wallpaper == StudyWallpaper.custom) {
    return ResizeImage(
      FileImage(
        File(ref.watch(customWallpaperProvider).requireValue!.imagePath),
      ),
      width: 192,
    );
  }
  return AssetImage(
    wallpaper.artwork(forMobile: ref.watch(mobileWallpapersProvider)).thumbnail,
  );
});
