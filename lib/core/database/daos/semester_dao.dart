part of '../database.dart';

extension SemesterDao on AppDatabase {
  Future<List<Semester>> getAllSemesters() => select(semesters).get();

  Future<Semester?> getSemesterById(String id) =>
      (select(semesters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Semester?> getMostRecentSemester() {
    return (select(
      semesters,
    )..orderBy([(t) => OrderingTerm.desc(t.endDate)])).getSingleOrNull();
  }

  Future<void> upsertSemester(SemestersCompanion entry) =>
      into(semesters).insertOnConflictUpdate(entry);
}
