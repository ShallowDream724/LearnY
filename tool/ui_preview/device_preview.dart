import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learn_y/app/app.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/demo/demo_api.dart';
import 'package:learn_y/demo/demo_environment.dart';

/// Isolated device rendering, including Impeller effects unavailable in tests.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = DemoHttpOverrides();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final demo = await DemoEnvironment.create(now: DateTime(2026, 9, 12));
  const wallpaper = String.fromEnvironment(
    'LEARNY_PREVIEW_WALLPAPER',
    defaultValue: 'warm_hills',
  );
  await demo.database.setState(AppStateKeys.wallpaper, wallpaper);
  await demo.database.setState(
    AppStateKeys.wallpaperIntensity(wallpaper),
    const String.fromEnvironment(
      'LEARNY_PREVIEW_INTENSITY',
      defaultValue: '65',
    ),
  );
  runApp(ProviderScope(overrides: demo.overrides, child: const LearnYApp()));
}
