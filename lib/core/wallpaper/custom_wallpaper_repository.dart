import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_state_keys.dart';
import '../database/database.dart';
import 'custom_wallpaper.dart';

/// Device appearance files live outside course caches and survive logout.
/// New files are completed before publishing their references to preferences.
class CustomWallpaperRepository {
  CustomWallpaperRepository(
    this.database, {
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? _defaultDirectory;
  final AppDatabase database;
  final Future<Directory> Function() _directory;

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'wallpapers'),
  );

  Future<CustomWallpaper?> load() async {
    final raw = await database.getState(AppStateKeys.customWallpaper);
    if (raw == null) return null;
    try {
      final value = jsonDecode(raw) as Map;
      if (value['version'] != 1) return null;
      final directory = await _directory();
      String resolve(String key) {
        final name = value[key] as String;
        if (!RegExp(r'^custom-[0-9]+\.(source|png)$').hasMatch(name)) {
          throw const FormatException('Invalid wallpaper path');
        }
        return p.join(directory.path, name);
      }

      final source = resolve('source');
      final image = resolve('image');
      final bounds = (value['crop'] as List)
          .map((v) => (v as num).toDouble())
          .toList();
      if (bounds.length != 4 ||
          bounds.any((v) => !v.isFinite || v < 0 || v > 1) ||
          bounds[2] <= bounds[0] ||
          bounds[3] <= bounds[1]) {
        return null;
      }
      if (!await File(source).exists() || !await File(image).exists()) {
        return null;
      }
      return CustomWallpaper(
        sourcePath: source,
        imagePath: image,
        crop: Rect.fromLTRB(bounds[0], bounds[1], bounds[2], bounds[3]),
        name: value['name'] as String? ?? '自定义背景',
      );
    } catch (_) {
      return null;
    }
  }

  Future<CustomWallpaper> save({
    required String sourcePath,
    required String name,
    required Rect crop,
    required Uint8List imageBytes,
    required int intensity,
  }) async {
    final old = await load();
    final directory = await (await _directory()).create(recursive: true);
    final id = DateTime.now().microsecondsSinceEpoch;
    final source = File(p.join(directory.path, 'custom-$id.source'));
    final image = File(p.join(directory.path, 'custom-$id.png'));
    try {
      await File(sourcePath).copy(source.path);
      await image.writeAsBytes(imageBytes, flush: true);
      await database.transaction(() async {
        await database.setState(
          AppStateKeys.customWallpaper,
          jsonEncode({
            'version': 1,
            'source': p.basename(source.path),
            'image': p.basename(image.path),
            'name': name,
            'crop': [crop.left, crop.top, crop.right, crop.bottom],
          }),
        );
        await database.setState(AppStateKeys.wallpaper, 'custom');
        await database.setState(
          AppStateKeys.wallpaperIntensity('custom'),
          intensity.clamp(0, 100).toString(),
        );
      });
    } catch (_) {
      await _removeFiles([source.path, image.path]);
      rethrow;
    }
    if (old != null) await _removeFiles([old.sourcePath, old.imagePath]);
    return CustomWallpaper(
      sourcePath: source.path,
      imagePath: image.path,
      crop: crop,
      name: name,
    );
  }

  Future<void> remove() async {
    final old = await load();
    await database.deleteState(AppStateKeys.customWallpaper);
    if (old != null) await _removeFiles([old.sourcePath, old.imagePath]);
  }

  Future<void> _removeFiles(List<String> paths) async {
    final directory = p.normalize(p.absolute((await _directory()).path));
    for (final path in paths) {
      if (!p.isWithin(directory, p.normalize(p.absolute(path)))) continue;
      try {
        await File(path).delete();
      } on FileSystemException {
        /* best effort */
      }
    }
  }
}
