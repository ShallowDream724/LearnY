import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class RevealPlatform {
  const RevealPlatform({
    required this.isWindows,
    required this.isMacOS,
    required this.isLinux,
  });

  factory RevealPlatform.current() {
    return RevealPlatform(
      isWindows: Platform.isWindows,
      isMacOS: Platform.isMacOS,
      isLinux: Platform.isLinux,
    );
  }

  final bool isWindows;
  final bool isMacOS;
  final bool isLinux;

  bool get isSupported => isWindows || isMacOS || isLinux;
}

typedef RevealProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      bool runInShell,
      ProcessStartMode mode,
    });

class FileManagerRevealService {
  FileManagerRevealService({
    RevealPlatform? platform,
    RevealProcessStarter? startProcess,
  }) : _platform = platform ?? RevealPlatform.current(),
       _startProcess = startProcess ?? _defaultStartProcess;

  final RevealPlatform _platform;
  final RevealProcessStarter _startProcess;

  bool get isSupported => _platform.isSupported;

  Future<bool> revealFile(String localPath) async {
    if (!isSupported) {
      return false;
    }

    if (_platform.isWindows) {
      return _startDetached('explorer.exe', [
        '/select,',
        p.windows.normalize(localPath),
      ]);
    }

    if (_platform.isMacOS) {
      return _startDetached('open', ['-R', localPath]);
    }

    if (_platform.isLinux) {
      return _startDetached('xdg-open', [File(localPath).parent.path]);
    }

    return false;
  }

  Future<bool> _startDetached(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
  }) async {
    try {
      final process = await _startProcess(
        executable,
        arguments,
        runInShell: runInShell,
        mode: ProcessStartMode.normal,
      );
      unawaited(process.exitCode.catchError((_) => -1));
      return true;
    } on ProcessException {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  static Future<Process> _defaultStartProcess(
    String executable,
    List<String> arguments, {
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.normal,
  }) {
    return Process.start(
      executable,
      arguments,
      runInShell: runInShell,
      mode: mode,
    );
  }
}

bool get supportsRevealInFileManager => RevealPlatform.current().isSupported;

final fileManagerRevealServiceProvider = Provider<FileManagerRevealService>((
  ref,
) {
  return FileManagerRevealService();
});
