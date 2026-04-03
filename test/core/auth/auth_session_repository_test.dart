import 'package:cookie_jar/cookie_jar.dart';
import 'package:drift/drift.dart' show Table, TableInfo, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/auth/auth_session_repository.dart';
import 'package:learn_y/core/auth/auth_session_store.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';

void main() {
  group('AuthSessionRepository', () {
    test(
      'logout clears session only and preserves same-user local data',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final cookieJar = CookieJar();
        final repo = AuthSessionRepository(
          apiClient: _RecordingLearnHelper(),
          sessionStore: AuthSessionStore(db),
          database: db,
          cookieJar: cookieJar,
        );

        await repo.persistAuthenticatedUser('user-a');
        await _seedLearningData(db);
        await _seedCourseWorkbenchPref(db, ownerKey: 'user-a');
        await db.setState(AppStateKeys.currentSemesterId, '2025-fall');
        await cookieJar.saveFromResponse(
          Uri.parse('https://learn.tsinghua.edu.cn'),
          [Cookie('SESSION', 'abc')],
        );

        await repo.logout();

        expect(await db.getState(AppStateKeys.username), isNull);
        expect(await db.getState(AppStateKeys.learningDataOwner), 'user-a');
        expect(await db.getState(AppStateKeys.currentSemesterId), '2025-fall');
        expect(await _tableCount(db, db.semesters), 1);
        expect(await _tableCount(db, db.courses), 1);
        expect(await _tableCount(db, db.notifications), 1);
        expect(await _tableCount(db, db.courseFiles), 1);
        expect(await _tableCount(db, db.cachedAssets), 1);
        expect(await _tableCount(db, db.fileBookmarks), 1);
        expect(await _tableCount(db, db.homeworks), 1);
        expect(await _tableCount(db, db.courseDisplayPrefs), 1);
        expect(
          await cookieJar.loadForRequest(
            Uri.parse('https://learn.tsinghua.edu.cn'),
          ),
          isEmpty,
        );
      },
    );

    test('same owner relogin keeps user-scoped data intact', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final repo = AuthSessionRepository(
        apiClient: _RecordingLearnHelper(),
        sessionStore: AuthSessionStore(db),
        database: db,
        cookieJar: CookieJar(),
      );

      await repo.persistAuthenticatedUser('user-a');
      await _seedLearningData(db);
      await _seedCourseWorkbenchPref(db, ownerKey: 'user-a');
      await db.setState(AppStateKeys.currentSemesterId, '2025-fall');
      await db.setState(AppStateKeys.userDepartment, '行健书院');

      await repo.persistAuthenticatedUser('user-a');

      expect(await db.getState(AppStateKeys.learningDataOwner), 'user-a');
      expect(await db.getState(AppStateKeys.currentSemesterId), '2025-fall');
      expect(await db.getState(AppStateKeys.userDepartment), '行健书院');
      expect(await _tableCount(db, db.cachedAssets), 1);
      expect(await _tableCount(db, db.fileBookmarks), 1);
      expect(await _tableCount(db, db.notifications), 1);
      expect(await _tableCount(db, db.courseDisplayPrefs), 1);
    });

    test(
      'account switch clears previous user-scoped data before claiming owner',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final repo = AuthSessionRepository(
          apiClient: _RecordingLearnHelper(),
          sessionStore: AuthSessionStore(db),
          database: db,
          cookieJar: CookieJar(),
        );

        await repo.persistAuthenticatedUser('user-a');
        await _seedLearningData(db);
        await _seedCourseWorkbenchPref(db, ownerKey: 'user-a');
        await db.setState(AppStateKeys.currentSemesterId, '2025-fall');
        await db.setState(AppStateKeys.userDepartment, '行健书院');

        await repo.persistAuthenticatedUser('user-b');

        expect(await db.getState(AppStateKeys.username), 'user-b');
        expect(await db.getState(AppStateKeys.learningDataOwner), 'user-b');
        expect(await db.getState(AppStateKeys.currentSemesterId), isNull);
        expect(await db.getState(AppStateKeys.userDepartment), isNull);
        expect(await _tableCount(db, db.semesters), 0);
        expect(await _tableCount(db, db.courses), 0);
        expect(await _tableCount(db, db.notifications), 0);
        expect(await _tableCount(db, db.courseFiles), 0);
        expect(await _tableCount(db, db.cachedAssets), 0);
        expect(await _tableCount(db, db.fileBookmarks), 0);
        expect(await _tableCount(db, db.homeworks), 0);
        expect(await _tableCount(db, db.courseDisplayPrefs), 0);
      },
    );
  });
}

Future<void> _seedLearningData(AppDatabase db) async {
  await db.upsertSemester(
    SemestersCompanion.insert(
      id: '2025-fall',
      startDate: '2025-09-01',
      endDate: '2026-01-15',
      startYear: 2025,
      endYear: 2026,
      type: 'fall',
    ),
  );
  await db.upsertCourse(
    CoursesCompanion.insert(
      id: 'course-1',
      name: '土力学',
      chineseName: '土力学',
      courseType: 'student',
      semesterId: '2025-fall',
    ),
  );
  await db.upsertNotification(
    NotificationsCompanion.insert(
      id: 'notification-1',
      courseId: 'course-1',
      title: '课程通知',
      publishTime: '2026-04-01 10:00:00',
      hasRead: const Value(false),
      hasReadLocal: const Value(true),
    ),
  );
  await db.upsertFile(
    CourseFilesCompanion.insert(
      id: 'file-1',
      courseId: 'course-1',
      fileId: 'remote-file-1',
      title: '课件.pdf',
      uploadTime: '2026-04-01 10:00:00',
      downloadUrl: 'https://example.com/file-1',
      previewUrl: 'https://example.com/file-1/preview',
      isNew: const Value(true),
      localDownloadState: const Value('downloaded'),
      localFilePath: const Value('/tmp/file-1.pdf'),
    ),
  );
  await db.upsertCachedAsset(
    CachedAssetsCompanion.insert(
      assetKey: 'asset-1',
      courseId: 'course-1',
      title: '课件.pdf',
      localPath: '/tmp/file-1.pdf',
      updatedAt: '2026-04-01T10:00:00.000',
    ),
  );
  await db.upsertFileBookmark(
    FileBookmarksCompanion.insert(
      assetKey: 'asset-1',
      courseName: const Value('土力学'),
      createdAt: '2026-04-01T10:00:00.000',
    ),
  );
  await db.upsertHomework(
    HomeworksCompanion.insert(
      id: 'homework-1',
      courseId: 'course-1',
      baseId: 'base-1',
      title: '作业 1',
      deadline: '2026-04-02 23:59:59',
    ),
  );
}

Future<void> _seedCourseWorkbenchPref(
  AppDatabase db, {
  required String ownerKey,
}) async {
  await db
      .into(db.courseDisplayPrefs)
      .insert(
        CourseDisplayPrefsCompanion.insert(
          ownerKey: ownerKey,
          semesterId: '2025-fall',
          courseId: 'course-1',
          sortOrder: const Value(0),
          iconKey: const Value('engineering'),
          alias: const Value('土力'),
          updatedAt: '2026-04-01T10:00:00.000',
        ),
      );
}

Future<int> _tableCount<T extends Table, D>(
  AppDatabase db,
  TableInfo<T, D> table,
) async {
  return (await db.select(table).get()).length;
}

class _RecordingLearnHelper extends Learn2018Helper {
  bool didLogout = false;

  @override
  Future<void> logout() async {
    didLogout = true;
  }
}
