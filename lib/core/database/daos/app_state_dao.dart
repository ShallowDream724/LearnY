part of '../database.dart';

extension AppStateDao on AppDatabase {
  Future<String?> getState(String key) async {
    final row = await (select(
      appState,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setState(String key, String value) async {
    await into(appState).insertOnConflictUpdate(
      AppStateCompanion(key: Value(key), value: Value(value)),
    );
  }

  Future<void> deleteState(String key) {
    return (delete(appState)..where((t) => t.key.equals(key))).go();
  }
}
