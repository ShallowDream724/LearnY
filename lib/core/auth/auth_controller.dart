import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';
import 'auth_session_repository.dart';
import 'auth_session_store.dart';

enum AuthRestoreState { restoring, ready }

enum SessionHealth { unknown, authenticated, expired }

class AuthState {
  final AuthRestoreState restoreState;
  final String? username;
  final SessionHealth sessionHealth;
  final String? errorMessage;

  const AuthState._({
    required this.restoreState,
    required this.username,
    required this.sessionHealth,
    this.errorMessage,
  });

  const AuthState.restoring()
    : this._(
        restoreState: AuthRestoreState.restoring,
        username: null,
        sessionHealth: SessionHealth.unknown,
      );

  const AuthState.signedOut({String? errorMessage})
    : this._(
        restoreState: AuthRestoreState.ready,
        username: null,
        sessionHealth: SessionHealth.unknown,
        errorMessage: errorMessage,
      );

  const AuthState.cached({required String username, String? errorMessage})
    : this._(
        restoreState: AuthRestoreState.ready,
        username: username,
        sessionHealth: SessionHealth.unknown,
        errorMessage: errorMessage,
      );

  const AuthState.authenticated({
    required String username,
    String? errorMessage,
  }) : this._(
         restoreState: AuthRestoreState.ready,
         username: username,
         sessionHealth: SessionHealth.authenticated,
         errorMessage: errorMessage,
       );

  const AuthState.sessionExpired({
    required String username,
    String? errorMessage,
  }) : this._(
         restoreState: AuthRestoreState.ready,
         username: username,
         sessionHealth: SessionHealth.expired,
         errorMessage: errorMessage,
       );

  bool get isRestoring => restoreState == AuthRestoreState.restoring;
  bool get hasPersistedIdentity => username != null && username!.isNotEmpty;
  bool get isSignedOut =>
      restoreState == AuthRestoreState.ready && !hasPersistedIdentity;
  bool get isLoggedIn =>
      hasPersistedIdentity && sessionHealth == SessionHealth.authenticated;
  bool get canAccessCachedData => hasPersistedIdentity;
  bool get requiresReauthentication =>
      hasPersistedIdentity && sessionHealth == SessionHealth.expired;
}

class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthSessionRepository _repository;

  AuthController(this._ref, this._repository)
    : super(const AuthState.restoring()) {
    _restore();
  }

  Future<void> _restore() async {
    final session = await _repository.restore();
    if (session.hasPersistedUser) {
      state = AuthState.cached(username: session.username!);
      return;
    }

    state = const AuthState.signedOut();
  }

  Future<void> onLoginSuccess(String username) async {
    await _repository.persistAuthenticatedUser(username);
    state = AuthState.authenticated(username: username);
  }

  void markSessionHealthy([String? username]) {
    final resolvedUsername = username ?? state.username;
    if (resolvedUsername == null || resolvedUsername.isEmpty) {
      return;
    }

    if (state.isLoggedIn &&
        state.username == resolvedUsername &&
        state.errorMessage == null) {
      return;
    }

    state = AuthState.authenticated(username: resolvedUsername);
  }

  void markSessionExpired([String? message]) {
    final username = state.username;
    if (username == null || username.isEmpty) {
      state = AuthState.signedOut(errorMessage: message);
      return;
    }

    state = AuthState.sessionExpired(
      username: username,
      errorMessage: message ?? '会话已过期，请重新登录',
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    _ref.read(currentSemesterIdProvider.notifier).state = null;
    state = const AuthState.signedOut();
  }
}

final authSessionStoreProvider = Provider<AuthSessionStore>((ref) {
  return AuthSessionStore(ref.watch(databaseProvider));
});

final authSessionRepositoryProvider = Provider<AuthSessionRepository>((ref) {
  return AuthSessionRepository(
    apiClient: ref.watch(apiClientProvider),
    sessionStore: ref.watch(authSessionStoreProvider),
    database: ref.watch(databaseProvider),
    cookieJar: ref.watch(cookieJarProvider),
  );
});

final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref, ref.watch(authSessionRepositoryProvider));
});
