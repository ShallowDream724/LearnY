import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/services/file_download_service.dart';

void main() {
  group('DownloadedPayloadInspector', () {
    const inspector = DownloadedPayloadInspector();

    test('rejects session-expired html payloads for non-html files', () async {
      final file = await _writeTempFile(
        'login_timeout<script>location.href="/login"</script>',
      );

      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      final result = await inspector.inspect(
        file: file,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['text/html; charset=utf-8'],
        }),
        statusCode: 200,
        expectedFileType: 'pdf',
      );

      expect(result.isValid, isFalse);
      expect(result.looksLikeSessionExpired, isTrue);
    });

    test('allows normal small text payloads for text files', () async {
      final file = await _writeTempFile('hello from learny');

      addTearDown(() async {
        if (await file.exists()) {
          await file.delete();
        }
      });

      final result = await inspector.inspect(
        file: file,
        headers: Headers.fromMap({
          Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        }),
        statusCode: 200,
        expectedFileType: 'txt',
      );

      expect(result.isValid, isTrue);
      expect(result.looksLikeSessionExpired, isFalse);
    });
  });
}

Future<File> _writeTempFile(String content) async {
  final directory = await Directory.systemTemp.createTemp('learny-download-');
  final file = File('${directory.path}/payload.bin');
  await file.writeAsString(content);
  return file;
}
