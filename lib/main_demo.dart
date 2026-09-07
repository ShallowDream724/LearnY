import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'demo/demo_api.dart';
import 'demo/demo_environment.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = DemoHttpOverrides();
  const networkName = String.fromEnvironment(
    'LEARNY_DEMO_NETWORK',
    defaultValue: 'normal',
  );
  final network = DemoNetwork.values.byName(networkName);
  final environment = await DemoEnvironment.create(
    network: network,
    selectPreviousSemester: const bool.fromEnvironment(
      'LEARNY_DEMO_PREVIOUS_SEMESTER',
    ),
  );
  runApp(
    ProviderScope(overrides: environment.overrides, child: const LearnYApp()),
  );
}
