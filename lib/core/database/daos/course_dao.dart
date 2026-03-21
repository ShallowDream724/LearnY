part of '../database.dart';

extension CourseDao on AppDatabase {
  Future<List<Course>> getCoursesBySemester(String semesterId) =>
      (select(courses)..where((t) => t.semesterId.equals(semesterId))).get();

  Future<void> upsertCourse(CoursesCompanion entry) =>
      into(courses).insertOnConflictUpdate(entry);

  Stream<List<Course>> watchCoursesBySemester(String semesterId) =>
      (select(courses)..where((t) => t.semesterId.equals(semesterId))).watch();
}
