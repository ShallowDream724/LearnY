import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/theme.dart';
import '../core/providers/providers.dart';
import '../core/router/router.dart';
import 'app_orientation.dart';

class LearnYApp extends ConsumerStatefulWidget {
  const LearnYApp({super.key});

  @override
  ConsumerState<LearnYApp> createState() => _LearnYAppState();
}

class _LearnYAppState extends ConsumerState<LearnYApp>
    with WidgetsBindingObserver {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(appSessionCoordinatorProvider);
    unawaited(ref.read(appUpdateInfoProvider.future));
    unawaited(AppOrientation.restoreDefault());
    _router = buildRouter(ref: ref);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appSessionCoordinatorProvider).handleLifecycleStateChanged(state);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'LearnY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      routerConfig: _router,
    );
  }
}
