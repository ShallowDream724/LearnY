import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/services/file_manager_reveal_service.dart';

void main() {
  group('FileManagerRevealService', () {
    test('uses explorer select on windows', () async {
      final invocations =
          <({String executable, List<String> arguments, bool runInShell})>[];
      final service = FileManagerRevealService(
        platform: const RevealPlatform(
          isWindows: true,
          isMacOS: false,
          isLinux: false,
        ),
        startProcess:
            (
              executable,
              arguments, {
              runInShell = false,
              mode = ProcessStartMode.normal,
            }) async {
              invocations.add((
                executable: executable,
                arguments: arguments,
                runInShell: runInShell,
              ));
              return _FakeProcess();
            },
      );

      final revealed = await service.revealFile(
        r'C:\Users\dell\Documents\LearnY Files\土力学\作业.pdf',
      );

      expect(revealed, isTrue);
      expect(invocations, hasLength(1));
      expect(invocations.single.executable, 'explorer.exe');
      expect(invocations.single.arguments, [
        '/select,',
        r'C:\Users\dell\Documents\LearnY Files\土力学\作业.pdf',
      ]);
      expect(invocations.single.runInShell, isFalse);
    });

    test('uses parent directory on linux', () async {
      final invocations =
          <({String executable, List<String> arguments, bool runInShell})>[];
      final service = FileManagerRevealService(
        platform: const RevealPlatform(
          isWindows: false,
          isMacOS: false,
          isLinux: true,
        ),
        startProcess:
            (
              executable,
              arguments, {
              runInShell = false,
              mode = ProcessStartMode.normal,
            }) async {
              invocations.add((
                executable: executable,
                arguments: arguments,
                runInShell: runInShell,
              ));
              return _FakeProcess();
            },
      );

      final revealed = await service.revealFile(
        '/tmp/learny/course-1/notes.pdf',
      );

      expect(revealed, isTrue);
      expect(invocations, hasLength(1));
      expect(invocations.single.executable, 'xdg-open');
      expect(invocations.single.arguments, ['/tmp/learny/course-1']);
      expect(invocations.single.runInShell, isFalse);
    });

    test('returns false when unsupported', () async {
      final service = FileManagerRevealService(
        platform: const RevealPlatform(
          isWindows: false,
          isMacOS: false,
          isLinux: false,
        ),
      );

      expect(await service.revealFile('/tmp/file.pdf'), isFalse);
    });

    test('returns false when process start throws', () async {
      final service = FileManagerRevealService(
        platform: const RevealPlatform(
          isWindows: true,
          isMacOS: false,
          isLinux: false,
        ),
        startProcess:
            (
              executable,
              arguments, {
              runInShell = false,
              mode = ProcessStartMode.normal,
            }) {
              throw const ProcessException('explorer.exe', []);
            },
      );

      expect(await service.revealFile(r'C:\tmp\file.pdf'), isFalse);
    });
  });
}

class _FakeProcess implements Process {
  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  int get pid => 1;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  IOSink get stdin => IOSink(StreamController<List<int>>().sink);

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();
}
