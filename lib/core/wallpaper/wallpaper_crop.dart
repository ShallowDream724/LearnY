import 'dart:math' as math;
import 'dart:ui';

/// Image-pixel geometry shared by the editor, persisted framing and export.
class WallpaperCrop {
  static Rect centered(Size image, double aspectRatio) {
    final width = math.min(image.width, image.height * aspectRatio);
    return Rect.fromCenter(
      center: image.center(Offset.zero),
      width: width,
      height: width / aspectRatio,
    );
  }

  static Rect constrain(Rect crop, Size image, double ratio) {
    final maxWidth = math.min(image.width, image.height * ratio);
    final width = crop.width
        .clamp(math.min(48.0, maxWidth), maxWidth)
        .toDouble();
    final height = width / ratio;
    final center = Offset(
      crop.center.dx.clamp(width / 2, image.width - width / 2),
      crop.center.dy.clamp(height / 2, image.height - height / 2),
    );
    return Rect.fromCenter(center: center, width: width, height: height);
  }

  static Rect normalize(Rect rect, Size image) => Rect.fromLTRB(
    rect.left / image.width,
    rect.top / image.height,
    rect.right / image.width,
    rect.bottom / image.height,
  );

  static Rect restore(Rect normalized, Size image) => Rect.fromLTRB(
    normalized.left * image.width,
    normalized.top * image.height,
    normalized.right * image.width,
    normalized.bottom * image.height,
  );
}
