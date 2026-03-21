import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
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

/// Global database instance — created once and kept alive for the app lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = createDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// API client — backed only by the persisted cookie jar.
///
/// Authentication is intentionally owned by the WebView SSO flow. We do not
/// wire an incomplete username/password credential provider here, because the
/// app currently does not persist those values.
final apiClientProvider = Provider<Learn2018Helper>((ref) {
  final jar = ref.watch(cookieJarProvider);
  return Learn2018Helper(config: HelperConfig(cookieJar: jar));
});

/// Seeded from `main.dart` so semester-scoped cached data can render on the
/// first frame after a cold start.
final initialCurrentSemesterIdProvider = Provider<String?>((ref) => null);

/// Tracks the currently selected semester ID.
final currentSemesterIdProvider = StateProvider<String?>((ref) {
  return ref.watch(initialCurrentSemesterIdProvider);
});
