part of '../database.dart';

extension SearchDao on AppDatabase {
  Future<List<Course>> searchCoursesBySemester(
    String semesterId,
    String query,
  ) {
    final pattern = _searchPattern(query);
    return (select(courses)..where(
          (t) =>
              t.semesterId.equals(semesterId) &
              (t.name.like(pattern) | t.teacherName.like(pattern)),
        ))
        .get();
  }

  Future<List<Notification>> searchNotificationsByCourseIds(
    Iterable<String> courseIds,
    String query,
  ) {
    final ids = courseIds.toList(growable: false);
    if (ids.isEmpty) {
      return Future.value(const <Notification>[]);
    }

    final pattern = _searchPattern(query);
    return (select(notifications)..where(
          (t) =>
              t.courseId.isIn(ids) &
              (t.title.like(pattern) | t.content.like(pattern)),
        ))
        .get();
  }

  Future<List<Notification>> searchNotificationsBySemester(
    String semesterId,
    String query,
  ) {
    final pattern = _searchPattern(query);
    final searchQuery =
        select(notifications).join([
          innerJoin(courses, courses.id.equalsExp(notifications.courseId)),
        ])..where(
          courses.semesterId.equals(semesterId) &
              (notifications.title.like(pattern) |
                  notifications.content.like(pattern)),
        );

    return searchQuery.map((row) => row.readTable(notifications)).get();
  }

  Future<List<Homework>> searchHomeworksByCourseIds(
    Iterable<String> courseIds,
    String query,
  ) {
    final ids = courseIds.toList(growable: false);
    if (ids.isEmpty) {
      return Future.value(const <Homework>[]);
    }

    final pattern = _searchPattern(query);
    return (select(homeworks)..where(
          (t) =>
              t.courseId.isIn(ids) &
              (t.title.like(pattern) | t.description.like(pattern)),
        ))
        .get();
  }

  Future<List<Homework>> searchHomeworksBySemester(
    String semesterId,
    String query,
  ) {
    final pattern = _searchPattern(query);
    final searchQuery =
        select(homeworks).join([
          innerJoin(courses, courses.id.equalsExp(homeworks.courseId)),
        ])..where(
          courses.semesterId.equals(semesterId) &
              (homeworks.title.like(pattern) |
                  homeworks.description.like(pattern)),
        );

    return searchQuery.map((row) => row.readTable(homeworks)).get();
  }

  Future<List<CourseFile>> searchFilesByCourseIds(
    Iterable<String> courseIds,
    String query,
  ) {
    final ids = courseIds.toList(growable: false);
    if (ids.isEmpty) {
      return Future.value(const <CourseFile>[]);
    }

    final pattern = _searchPattern(query);
    return (select(courseFiles)..where(
          (t) =>
              t.courseId.isIn(ids) &
              (t.title.like(pattern) | t.description.like(pattern)),
        ))
        .get();
  }

  Future<List<CourseFile>> searchFilesBySemester(
    String semesterId,
    String query,
  ) {
    final pattern = _searchPattern(query);
    final searchQuery =
        select(courseFiles).join([
          innerJoin(courses, courses.id.equalsExp(courseFiles.courseId)),
        ])..where(
          courses.semesterId.equals(semesterId) &
              (courseFiles.title.like(pattern) |
                  courseFiles.description.like(pattern)),
        );

    return searchQuery.map((row) => row.readTable(courseFiles)).get();
  }

  String _searchPattern(String query) => '%${query.trim()}%';
}
