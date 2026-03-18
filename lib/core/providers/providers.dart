/// Core Riverpod providers — dependency injection for the app.
///
/// These are the foundational providers that other feature providers
/// depend on: database, API client, auth state.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learn_api.dart';
import '../database/connection.dart';
import '../database/database.dart';

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

/// Global database instance — created once, lives for the app lifetime.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = createDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ---------------------------------------------------------------------------
// Auth State
// ---------------------------------------------------------------------------

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final String? username;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.username,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? username,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      username: username ?? this.username,
      errorMessage: errorMessage,
    );
  }

  bool get isLoggedIn => status == AuthStatus.authenticated;
}

/// Auth state notifier.
class AuthNotifier extends StateNotifier<AuthState> {
  final Ref _ref;
  final AppDatabase _db;

  AuthNotifier(this._ref, this._db) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final username = await _db.getState('username');
    if (username != null && username.isNotEmpty) {
      state = AuthState(
        status: AuthStatus.authenticated,
        username: username,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> onLoginSuccess(String username) async {
    await _db.setState('username', username);
    state = AuthState(
      status: AuthStatus.authenticated,
      username: username,
    );
  }

  Future<void> logout() async {
    // 1. Call API logout (best-effort, don't block on failure)
    try {
      await _ref.read(apiClientProvider).logout();
    } catch (_) {
      // Server logout failure shouldn't block local cleanup
    }

    // 2. Clear all cached data from the database
    await _db.clearAllData();

    // 3. Clear cookies from CookieJar
    try {
      _ref.read(apiClientProvider).cookieJar.deleteAll();
    } catch (_) {}

    // 4. Reset semester state
    _ref.read(currentSemesterIdProvider.notifier).state = null;

    // 5. Update auth state — this triggers router redirect to login
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref, ref.watch(databaseProvider));
});

// ---------------------------------------------------------------------------
// API Client
// ---------------------------------------------------------------------------

/// API client — created with credential provider linked to stored creds.
final apiClientProvider = Provider<Learn2018Helper>((ref) {
  final db = ref.watch(databaseProvider);

  return Learn2018Helper(
    config: HelperConfig(
      provider: () async {
        final username = await db.getState('username');
        final password = await db.getState('password');
        final fingerPrint = await db.getState('fingerPrint');
        return Credential(
          username: username,
          password: password,
          fingerPrint: fingerPrint,
        );
      },
    ),
  );
});

// ---------------------------------------------------------------------------
// Current Semester
// ---------------------------------------------------------------------------

/// Tracks the currently selected semester ID.
final currentSemesterIdProvider = StateProvider<String?>((ref) => null);

// ---------------------------------------------------------------------------
// Theme Mode (persisted)
// ---------------------------------------------------------------------------

/// User's theme preference: system, light, or dark.
/// Persisted in DB so it survives app restarts.
class ThemeModeNotifier extends StateNotifier<String> {
  final AppDatabase _db;

  ThemeModeNotifier(this._db) : super('system') {
    _load();
  }

  Future<void> _load() async {
    final saved = await _db.getState('theme_mode');
    if (saved != null && (saved == 'light' || saved == 'dark' || saved == 'system')) {
      state = saved;
    }
  }

  Future<void> setTheme(String mode) async {
    state = mode;
    await _db.setState('theme_mode', mode);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, String>((ref) {
  return ThemeModeNotifier(ref.watch(databaseProvider));
});
