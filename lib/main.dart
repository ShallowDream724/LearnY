import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/database/app_state_keys.dart';
import 'core/database/connection.dart';
import 'core/database/database.dart';
import 'core/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PersistCookieJar — cookies survive app restarts.
  // This is Layer 1 of our three-layer session defense.
  final appDir = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${appDir.path}/cookies/'),
  );
  final initialCurrentSemesterId = await _resolveInitialCurrentSemesterId();

  runApp(
    ProviderScope(
      overrides: [
        cookieJarProvider.overrideWithValue(cookieJar),
        initialCurrentSemesterIdProvider.overrideWithValue(
          initialCurrentSemesterId,
        ),
      ],
      child: const LearnYApp(),
    ),
  );
}

Future<String?> _resolveInitialCurrentSemesterId() async {
  final db = createDatabase();
  try {
    final persisted = await db.getState(AppStateKeys.currentSemesterId);
    if (persisted != null && persisted.trim().isNotEmpty) {
      return persisted;
    }

    final mostRecentSemester = await db.getMostRecentSemester();
    return mostRecentSemester?.id;
  } finally {
    await db.close();
  }
}
