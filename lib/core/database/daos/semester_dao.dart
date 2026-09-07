part of '../database.dart';

extension SemesterDao on AppDatabase {
  Future<List<Semester>> getAllSemesters() => select(semesters).get();

  Stream<List<Semester>> watchSemesters() =>
      (select(semesters)..orderBy([(t) => OrderingTerm.desc(t.id)])).watch();

  Future<Semester?> getSemesterById(String id) =>
      (select(semesters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Semester?> getMostRecentSemester() {
    return (select(semesters)
          ..orderBy([(t) => OrderingTerm.desc(t.id)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> upsertSemester(SemestersCompanion entry) =>
      into(semesters).insertOnConflictUpdate(entry);
}
