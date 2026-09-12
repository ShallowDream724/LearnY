import 'dart:io';
import 'dart:typed_data';

import 'package:gal/gal.dart';
import 'package:mime/mime.dart';
import 'package:path_provider/path_provider.dart';

/// Exports the original image; viewing/saving never makes another web request.
abstract final class ImageGalleryService {
  static Future<void> saveFile(String path) => Gal.putImage(path);

  static Future<void> saveBytes(Uint8List bytes) async {
    final extension = switch (lookupMimeType('', headerBytes: bytes)) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/bmp' => 'bmp',
      'image/heic' => 'heic',
      'image/heif' => 'heif',
      'image/avif' => 'avif',
      _ => throw const FormatException('Unsupported image format'),
    };
    final temporary = await getTemporaryDirectory();
    final directory = await temporary.createTemp('learny-image-');
    try {
      final name = 'LearnY_${DateTime.now().microsecondsSinceEpoch}.$extension';
      final file = File('${directory.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await saveFile(file.path);
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
