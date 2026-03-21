import '../database/app_state_keys.dart';
import '../database/database.dart';

class AuthSessionRecord {
  final String? username;

  const AuthSessionRecord({this.username});

  bool get hasPersistedUser => username != null && username!.isNotEmpty;
}

class AuthSessionStore {
  final AppDatabase _db;

  const AuthSessionStore(this._db);

  Future<AuthSessionRecord> read() async {
    final username = await _db.getState(AppStateKeys.username);
    return AuthSessionRecord(username: username);
  }

  Future<void> saveAuthenticatedUser(String username) {
    return _db.setState(AppStateKeys.username, username);
  }

  Future<void> clear() {
    return Future.wait([
      _db.deleteState(AppStateKeys.username),
      _db.deleteState(AppStateKeys.userDepartment),
      _db.deleteState(AppStateKeys.currentSemesterId),
    ]);
  }
}
