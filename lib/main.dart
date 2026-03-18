import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/theme.dart';
import 'core/router/router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock orientation to portrait on phones
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: LearnYApp()));
}

class LearnYApp extends StatelessWidget {
  const LearnYApp({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with Riverpod auth state
    final isLoggedIn = false;
    final router = buildRouter(isLoggedIn: isLoggedIn);

    return MaterialApp.router(
      title: 'LearnY',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,

      // Router
      routerConfig: router,
    );
  }
}
