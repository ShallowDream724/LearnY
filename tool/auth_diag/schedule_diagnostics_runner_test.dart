import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'schedule_diagnostics.dart';

void main() {
  final rawArgs = Platform.environment['LEARNY_SCHEDULE_DIAG_ARGS_JSON'];

  test(
    'runs schedule diagnostics from environment arguments',
    () async {
      final args = (jsonDecode(rawArgs!) as List<dynamic>)
          .map((value) => value.toString())
          .toList();
      final exitCode = await runScheduleDiagnostics(args);
      expect(exitCode, 0);
    },
    skip: rawArgs == null || rawArgs.isEmpty
        ? 'Set LEARNY_SCHEDULE_DIAG_ARGS_JSON to run schedule diagnostics.'
        : false,
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
