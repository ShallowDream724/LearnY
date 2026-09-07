import 'dart:convert';

import 'package:drift/drift.dart';

import '../api/learning_read_api.dart';
import '../api/models.dart' as api;
import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../sync/sync_operation.dart';

/// One authoritative course roster, shared by learning sync and date browsing.
class CourseCatalogRepository {
  CourseCatalogRepository({required this.database, required this.apiClient});
  final AppDatabase database;
  final LearningReadApi apiClient;
  final _requests = <String, _CourseCatalogRequest>{};

  Future<List<api.CourseInfo>> refresh(
    String semesterId,
    SyncOperation operation,
  ) async {
    operation.ensureActive();
    var request = _requests[semesterId];
    if (request == null ||
        !request.operations.any((operation) => operation.isActive)) {
      final started = _CourseCatalogRequest();
      started.future = apiClient
          .getCourseList(semesterId)
          .timeout(const Duration(seconds: 30))
          .whenComplete(() {
            if (identical(_requests[semesterId], started)) {
              _requests.remove(semesterId);
            }
          });
      _requests[semesterId] = started;
      request = started;
    }
    request.operations.add(operation);
    final courses = await request.future;
    operation.ensureActive();
    final now = DateTime.now();
    await database.transaction(() async {
      final withdrawn = await withdrawnCourseIdsByName(semesterId);
      for (final course in courses) {
        operation.ensureActive();
        await database.upsertCourse(
          CoursesCompanion.insert(
            id: course.id,
            name: course.name,
            chineseName: course.chineseName,
            englishName: Value(course.englishName),
            teacherName: Value(course.teacherName),
            teacherNumber: Value(course.teacherNumber),
            courseNumber: Value(course.courseNumber),
            courseIndex: Value(course.courseIndex),
            courseType: course.courseType.value,
            semesterId: semesterId,
            timeAndLocationJson: course.timeAndLocationLoaded
                ? Value(jsonEncode(course.timeAndLocation))
                : const Value.absent(),
            lastSynced: Value(now),
          ),
        );
      }
      final retained = courses.map((course) => course.id).toSet();
      for (final stored in await database.getCoursesBySemester(semesterId)) {
        if (retained.contains(stored.id)) continue;
        for (final name in [
          stored.name,
          stored.chineseName,
          stored.englishName,
        ]) {
          if (name.trim().isNotEmpty) withdrawn[name.trim()] = stored.id;
        }
        await database.clearCourseDependentData(stored.id);
        await (database.delete(
          database.courses,
        )..where((row) => row.id.equals(stored.id))).go();
      }
      for (final course in courses) {
        for (final name in [
          course.name,
          course.chineseName,
          course.englishName,
        ]) {
          withdrawn.remove(name.trim());
        }
      }
      await database.setState(
        AppStateKeys.courseCatalogWithdrawn(semesterId),
        jsonEncode(withdrawn),
      );
      // An empty successful roster is authoritative too.
      await database.setState(
        AppStateKeys.courseCatalogUpdatedAt(semesterId),
        (courses.every((course) => course.timeAndLocationLoaded)
                ? now
                : now.subtract(const Duration(minutes: 14)))
            .toIso8601String(),
      );
      await database.deleteState(
        AppStateKeys.homeScheduleSemesterCache(semesterId),
      );
      operation.ensureActive();
    });
    return courses;
  }

  Future<Map<String, String>> withdrawnCourseIdsByName(
    String semesterId,
  ) async {
    final raw = await database.getState(
      AppStateKeys.courseCatalogWithdrawn(semesterId),
    );
    if (raw == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }
}

class _CourseCatalogRequest {
  late final Future<List<api.CourseInfo>> future;
  final operations = <SyncOperation>{};
}
