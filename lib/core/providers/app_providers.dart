import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/connection.dart';
import '../database/database.dart';

// ---------------------------------------------------------------------------
// App infrastructure
// ---------------------------------------------------------------------------

/// PersistCookieJar — initialized in `main.dart`, overridden via ProviderScope.
/// Cookies survive app restarts and back the SSO session.
final cookieJarProvider = Provider<CookieJar>((ref) {
  return CookieJar();
});

/// System secure storage for sensitive auth material.
final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Global database instance — created once and kept alive for the app lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = createDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Seeded from `main.dart` so semester-scoped cached data can render on the
/// first frame after a cold start.
final initialCurrentSemesterIdProvider = Provider<String?>((ref) => null);

/// Tracks the currently selected semester ID.
final currentSemesterIdProvider = StateProvider<String?>((ref) {
  return ref.watch(initialCurrentSemesterIdProvider);
});
