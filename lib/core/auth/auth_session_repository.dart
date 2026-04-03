import 'package:cookie_jar/cookie_jar.dart';

import '../api/learn_api.dart';
import '../database/database.dart';
import 'auth_session_store.dart';

class AuthSessionRepository {
  final Learn2018Helper _apiClient;
  final AuthSessionStore _sessionStore;
  final AppDatabase _database;
  final CookieJar _cookieJar;

  const AuthSessionRepository({
    required Learn2018Helper apiClient,
    required AuthSessionStore sessionStore,
    required AppDatabase database,
    required CookieJar cookieJar,
  }) : _apiClient = apiClient,
       _sessionStore = sessionStore,
       _database = database,
       _cookieJar = cookieJar;

  Future<AuthSessionRecord> restore() {
    return _sessionStore.read();
  }

  Future<void> persistAuthenticatedUser(String username) async {
    final normalizedUsername = username.trim();
    final existingOwner =
        (await _sessionStore.readLearningDataOwner())?.trim() ?? '';

    if (existingOwner.isNotEmpty && existingOwner != normalizedUsername) {
      await _database.clearUserScopedData();
    }

    await _sessionStore.saveLearningDataOwner(normalizedUsername);
    await _sessionStore.saveAuthenticatedUser(normalizedUsername);
  }

  Future<void> logout() async {
    try {
      await _apiClient.logout();
    } catch (_) {
      // Server logout failure should not block local cleanup.
    }

    await _sessionStore.clear();

    try {
      await _cookieJar.deleteAll();
    } catch (_) {
      // Local cookie cleanup is best-effort.
    }
  }
}
