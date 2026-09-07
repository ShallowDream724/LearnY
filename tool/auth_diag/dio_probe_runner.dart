import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'dio_probe.dart' as probe;

void main() {
  test(
    'manual Dio transport diagnostic (inspect console output)',
    probe.main,
    skip: Platform.environment['LEARNY_DIO_PROBE'] == '1'
        ? false
        : 'Set LEARNY_DIO_PROBE=1 to run the manual network diagnostic.',
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
