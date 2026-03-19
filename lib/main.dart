import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'core/design/responsive.dart';
import 'core/design/theme.dart';
import 'core/providers/providers.dart';
import 'core/router/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PersistCookieJar — cookies survive app restarts.
  // This is Layer 1 of our three-layer session defense.
  final appDir = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(storage: FileStorage('${appDir.path}/cookies/'));

  runApp(ProviderScope(
    overrides: [cookieJarProvider.overrideWithValue(cookieJar)],
    child: const LearnYApp(),
  ));
}

class LearnYApp extends ConsumerStatefulWidget {
  const LearnYApp({super.key});

  @override
  ConsumerState<LearnYApp> createState() => _LearnYAppState();
}

class _LearnYAppState extends ConsumerState<LearnYApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    // Build router ONCE. Auth changes are handled via redirect + refresh.
    _router = buildRouter(ref: ref);
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
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
      builder: (context, child) {
        // Lock orientation based on device type:
        // - Phones: portrait only (better UX for content-heavy app)
        // - Tablets: allow landscape for wider layouts
        final deviceType = layoutTypeOf(context);
        if (deviceType == LayoutType.compact) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        }
        return child!;
      },
    );
  }
}

