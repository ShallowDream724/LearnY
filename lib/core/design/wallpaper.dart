import 'package:flutter/material.dart';

/// An authored composition, with its own assets and camera framing.
class WallpaperArtwork {
  const WallpaperArtwork(
    this.name, {
    this.zoom = 1,
    this.wideAlignment = Alignment.center,
    this.tallAlignment = Alignment.center,
  });

  final String name;
  final double zoom;
  final Alignment wideAlignment;
  final Alignment tallAlignment;

  String assetFor(Brightness brightness) =>
      'assets/artwork/${name}_${brightness == Brightness.dark ? 'dark' : 'light'}.webp';
  String get thumbnail => 'assets/artwork/${name}_thumbnail.webp';
}

/// Stable identity and device-specific artwork are independent of preferences.
/// A mobile composition is supplied explicitly; it is never a desktop crop.
enum StudyWallpaper {
  dunes(
    'dunes',
    '晴岚',
    desktop: WallpaperArtwork('dunes', tallAlignment: Alignment(.15, 0)),
  ),
  prism(
    'prism',
    '澄光',
    desktop: WallpaperArtwork('prism', tallAlignment: Alignment(.45, 0)),
    mobile: WallpaperArtwork('prism_mobile'),
  ),
  alpine(
    'alpine',
    '远山',
    desktop: WallpaperArtwork('alpine', tallAlignment: Alignment(-.25, 0)),
    mobile: WallpaperArtwork('alpine_mobile'),
    paneOpacity: .62,
  ),
  glow(
    'glow',
    '微光',
    desktop: WallpaperArtwork(
      'landscape',
      zoom: 1.16,
      wideAlignment: Alignment(-.76, -.84),
      tallAlignment: Alignment(.08, -.84),
    ),
  ),
  warmHills('warm_hills', '暖丘', mobile: WallpaperArtwork('warm_hills_mobile')),
  cove('cove', '碧潭', mobile: WallpaperArtwork('cove_mobile'), paneOpacity: .62);

  const StudyWallpaper(
    this.id,
    this.label, {
    this.desktop,
    this.mobile,
    this.paneOpacity = .44,
  });

  final String id;
  final String label;
  final WallpaperArtwork? desktop;
  final WallpaperArtwork? mobile;
  final double paneOpacity;

  static const desktopChoices = [dunes, prism, alpine, glow];
  static const mobileChoices = [warmHills, prism, alpine, cove];
  static List<StudyWallpaper> choices({required bool forMobile}) =>
      forMobile ? mobileChoices : desktopChoices;

  static StudyWallpaper defaultFor({required bool forMobile}) =>
      forMobile ? prism : dunes;

  WallpaperArtwork artwork({bool forMobile = false}) {
    final result = forMobile ? mobile : desktop;
    if (result == null) {
      throw StateError(
        'No ${forMobile ? 'mobile' : 'desktop'} artwork for $id',
      );
    }
    return result;
  }

  String assetFor(Brightness brightness, {bool forMobile = false}) =>
      artwork(forMobile: forMobile).assetFor(brightness);

  static StudyWallpaper fromId(String? id, {bool forMobile = false}) {
    final available = choices(forMobile: forMobile);
    return available.firstWhere(
      (wallpaper) => wallpaper.id == id,
      orElse: () => defaultFor(forMobile: forMobile),
    );
  }
}
