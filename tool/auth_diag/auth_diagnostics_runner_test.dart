import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'auth_diagnostics.dart';

void main() {
  final rawArgs = Platform.environment['LEARNY_AUTH_DIAG_ARGS_JSON'];

  test(
    'runs auth diagnostics from environment arguments',
    () async {
      final args = (jsonDecode(rawArgs!) as List<dynamic>)
          .map((value) => value.toString())
          .toList();
      final exitCode = await runAuthDiagnostics(args);
      expect(exitCode, 0);
    },
    skip: rawArgs == null || rawArgs.isEmpty
        ? 'Set LEARNY_AUTH_DIAG_ARGS_JSON to run auth diagnostics.'
        : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
