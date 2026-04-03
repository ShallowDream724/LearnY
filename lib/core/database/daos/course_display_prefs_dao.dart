part of '../database.dart';

extension CourseDisplayPrefsDao on AppDatabase {
  Stream<List<CourseDisplayPref>> watchCourseDisplayPrefsByScope({
    required String ownerKey,
    required String semesterId,
  }) {
    return (select(courseDisplayPrefs)
          ..where(
            (t) =>
                t.ownerKey.equals(ownerKey) & t.semesterId.equals(semesterId),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.updatedAt),
            (t) => OrderingTerm.asc(t.courseId),
          ]))
        .watch();
  }

  Future<void> replaceCourseDisplayPrefs({
    required String ownerKey,
    required String semesterId,
    required List<CourseDisplayPrefsCompanion> entries,
  }) async {
    await transaction(() async {
      await (delete(courseDisplayPrefs)..where(
            (t) =>
                t.ownerKey.equals(ownerKey) & t.semesterId.equals(semesterId),
          ))
          .go();
      if (entries.isEmpty) {
        return;
      }
      await batch((batch) {
        batch.insertAll(
          courseDisplayPrefs,
          entries,
          mode: InsertMode.insertOrReplace,
        );
      });
    });
  }
}
