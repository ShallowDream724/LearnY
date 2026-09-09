import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../design/wallpaper.dart';
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
    if (!StudyWallpaper.choices(forMobile: forMobile).contains(wallpaper)) {
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
