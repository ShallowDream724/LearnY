import 'dart:ui';

class CustomWallpaper {
  const CustomWallpaper({
    required this.sourcePath,
    required this.imagePath,
    required this.crop,
    required this.name,
  });

  final String sourcePath;
  final String imagePath;
  final Rect crop; // Normalized coordinates in the orientation-correct image.
  final String name;
}
