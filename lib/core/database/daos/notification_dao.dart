part of '../database.dart';

extension NotificationDao on AppDatabase {
  Expression<bool> _isUnreadExpr($NotificationsTable t) =>
      t.hasRead.equalsExp(t.hasReadLocal);

  Future<List<Notification>> getNotificationsByCourse(String courseId) =>
      (select(notifications)..where((t) => t.courseId.equals(courseId))).get();

  Future<Notification?> getNotificationById(String id) =>
      (select(notifications)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Notification>> getUnreadNotifications() =>
      (select(notifications)..where(_isUnreadExpr)).get();

  Future<void> upsertNotification(NotificationsCompanion entry) =>
      into(notifications).insertOnConflictUpdate(entry);

  Future<void> markNotificationReadLocal(String id) async {
    final notification = await getNotificationById(id);
    if (notification == null) {
      return;
    }

    await (update(notifications)..where((t) => t.id.equals(id))).write(
      NotificationsCompanion(hasReadLocal: Value(!notification.hasRead)),
    );
  }

  Future<void> markNotificationUnreadLocal(String id) async {
    final notification = await getNotificationById(id);
    if (notification == null) {
      return;
    }

    await (update(notifications)..where((t) => t.id.equals(id))).write(
      NotificationsCompanion(hasReadLocal: Value(notification.hasRead)),
    );
  }

  Stream<List<Notification>> watchNotificationsByCourse(String courseId) =>
      (select(
        notifications,
      )..where((t) => t.courseId.equals(courseId))).watch();

  Stream<List<Notification>> watchNotificationsBySemester(String semesterId) {
    final query =
        select(notifications).join([
            innerJoin(courses, courses.id.equalsExp(notifications.courseId)),
          ])
          ..where(courses.semesterId.equals(semesterId))
          ..orderBy([OrderingTerm.desc(notifications.publishTime)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(notifications)).toList(),
    );
  }

  Stream<Notification?> watchNotificationById(String id) => (select(
    notifications,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();

  Stream<List<Notification>> watchAllNotifications() => (select(
    notifications,
  )..orderBy([(t) => OrderingTerm.desc(t.publishTime)])).watch();

  Stream<List<Notification>> watchUnreadNotifications() =>
      (select(notifications)..where(_isUnreadExpr)).watch();

  Stream<List<Notification>> watchUnreadNotificationsBySemester(
    String semesterId,
  ) {
    final query =
        select(notifications).join([
            innerJoin(courses, courses.id.equalsExp(notifications.courseId)),
          ])
          ..where(
            courses.semesterId.equals(semesterId) &
                _isUnreadExpr(notifications),
          )
          ..orderBy([OrderingTerm.desc(notifications.publishTime)]);

    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(notifications)).toList(),
    );
  }
}
