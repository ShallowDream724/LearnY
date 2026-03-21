part of '../database.dart';

extension MaintenanceDao on AppDatabase {
  Future<void> clearCourseDependentData(String courseId) async {
    await (delete(
      notifications,
    )..where((t) => t.courseId.equals(courseId))).go();
    await (delete(courseFiles)..where((t) => t.courseId.equals(courseId))).go();
    await (delete(homeworks)..where((t) => t.courseId.equals(courseId))).go();
  }

  Future<void> clearAllData() async {
    await delete(semesters).go();
    await delete(courses).go();
    await delete(notifications).go();
    await delete(courseFiles).go();
    await delete(cachedAssets).go();
    await delete(homeworks).go();
    await delete(appState).go();
  }

  Future<void> clearLearningData() async {
    await delete(semesters).go();
    await delete(courses).go();
    await delete(notifications).go();
    await delete(courseFiles).go();
    await delete(cachedAssets).go();
    await delete(homeworks).go();
    await deleteState(AppStateKeys.homeScheduleSnapshot);
  }

  Future<void> clearSessionState() async {
    await deleteState(AppStateKeys.username);
    await deleteState(AppStateKeys.homeScheduleSnapshot);
  }
}
