import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/sync_provider.dart';
import 'package:learn_y/demo/demo_api.dart';
import 'package:learn_y/demo/demo_environment.dart';
import 'package:learn_y/demo/demo_secure_storage.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'demo sync retains fixture and keeps selected and official semesters separate',
    () async {
      final environment = await DemoEnvironment.create(
        now: DateTime(2026, 9, 7),
        selectPreviousSemester: true,
      );
      final container = ProviderContainer(overrides: environment.overrides);
      addTearDown(() async {
        container.dispose();
        await environment.dispose();
      });
      final db = environment.database;
      final selected = environment.selectedSemesterId;
      final official = environment.api.data.officialSemesterId;
      expect(selected, isNot(official));
      expect(await db.getState(AppStateKeys.serverCurrentSemesterId), official);
      expect(await db.getAllCourses(), hasLength(9));
      expect(await db.getHomeworksBySemester(official), hasLength(12));
      expect(
        await db.getState(AppStateKeys.homeScheduleSemesterCache(official)),
        isNotNull,
      );

      final sync = await container
          .read(syncStateProvider.notifier)
          .syncAll(force: true);
      expect(sync.status, SyncStatus.success);
      expect(await db.getAllCourses(), hasLength(9));
      expect(await db.getState(AppStateKeys.currentSemesterId), selected);
      expect(await db.getState(AppStateKeys.serverCurrentSemesterId), official);
      await container.read(authProvider.notifier).logout();
      expect(container.read(authProvider).isLoggedIn, isTrue);
      expect(await container.read(appUpdateInfoProvider.future), isNotNull);
    },
  );

  test('offline failure preserves cached courses and homework', () async {
    final environment = await DemoEnvironment.create(
      network: DemoNetwork.offline,
    );
    final container = ProviderContainer(overrides: environment.overrides);
    addTearDown(() async {
      container.dispose();
      await environment.dispose();
    });
    final sync = await container
        .read(syncStateProvider.notifier)
        .syncAll(force: true);
    expect(sync.status, SyncStatus.error);
    expect(await environment.database.getAllCourses(), hasLength(9));
    expect(
      await environment.database.getHomeworksBySemester(
        environment.selectedSemesterId,
      ),
      hasLength(12),
    );
  });

  test('file transport is local and unknown URLs fail closed', () async {
    final environment = await DemoEnvironment.create();
    addTearDown(environment.dispose);
    final file = environment.api.data.files.values.first.first;
    final directory = await environment.workspace.ensureCourseDirectory(
      courseId: environment.api.data.courses.values.first.first.id,
    );
    expect(
      p.isWithin(environment.documentsDirectory.path, directory.path),
      isTrue,
    );
    final target = p.join(directory.path, file.title);
    await environment.api.dio.download(file.downloadUrl, target);
    expect(await File(target).readAsString(), contains('课程学习提纲'));
    await expectLater(
      environment.api.dio.get('https://learn.tsinghua.edu.cn/'),
      throwsA(isA<DioException>()),
    );
    HttpOverrides.runWithHttpOverrides(() {
      expect(() => HttpClient(), throwsA(isA<SocketException>()));
    }, DemoHttpOverrides());
  });

  test('submission stays in fake API and is returned by later sync', () async {
    final environment = await DemoEnvironment.create();
    final container = ProviderContainer(overrides: environment.overrides);
    addTearDown(() async {
      container.dispose();
      await environment.dispose();
    });
    final course = environment.api.data.courses.values.first.first;
    final homework = environment.api.data.homeworks[course.id]!.first;
    expect(homework.submitted, isFalse);
    await environment.api.submitHomework(homework.id, content: '<p>已完成推导。</p>');
    await container
        .read(syncStateProvider.notifier)
        .syncCourse(course.id, force: true);
    final stored = await environment.database.getHomeworksByCourse(course.id);
    expect(
      stored.firstWhere((item) => item.id == homework.id).submitted,
      isTrue,
    );
  });

  test(
    'secure credentials are isolated per instance without platform calls',
    () async {
      final storage = DemoSecureStorage();
      final another = DemoSecureStorage();
      await storage.write(key: 'demo-key', value: 'demo-value');
      expect(await storage.read(key: 'demo-key'), 'demo-value');
      expect(await another.readAll(), isEmpty);
      await storage.deleteAll();
      expect(await storage.containsKey(key: 'demo-key'), isFalse);
    },
  );
}
