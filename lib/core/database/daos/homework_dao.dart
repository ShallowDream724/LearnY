part of '../database.dart';

extension HomeworkDao on AppDatabase {
  Future<List<Homework>> getHomeworksByCourse(String courseId) =>
      (select(homeworks)..where((t) => t.courseId.equals(courseId))).get();

  Future<Homework?> getHomeworkById(String id) =>
      (select(homeworks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Homework>> getUpcomingHomeworks() =>
      (select(homeworks)
            ..where((t) => t.submitted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.deadline)]))
          .get();

  Future<void> upsertHomework(HomeworksCompanion entry) =>
      into(homeworks).insertOnConflictUpdate(entry);

  Stream<List<Homework>> watchHomeworksByCourse(String courseId) =>
      (select(homeworks)..where((t) => t.courseId.equals(courseId))).watch();

  Stream<List<Homework>> watchHomeworksBySemester(String semesterId) {
    final query =
        select(
            homeworks,
          ).join([innerJoin(courses, courses.id.equalsExp(homeworks.courseId))])
          ..where(courses.semesterId.equals(semesterId))
          ..orderBy([OrderingTerm.asc(homeworks.deadline)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(homeworks)).toList(),
    );
  }

  Stream<Homework?> watchHomeworkById(String id) =>
      (select(homeworks)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<List<Homework>> watchAllHomeworks() => (select(
    homeworks,
  )..orderBy([(t) => OrderingTerm.desc(t.deadline)])).watch();

  Stream<List<Homework>> watchUpcomingHomeworks() =>
      (select(homeworks)
            ..where((t) => t.submitted.equals(false))
            ..orderBy([(t) => OrderingTerm.asc(t.deadline)]))
          .watch();
}
