import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/services/file_storage_workspace_service.dart';

void main() {
  group('FileStorageWorkspaceService', () {
    test('creates the LearnY workspace directly for fresh installs', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final documentsDirectory = await Directory.systemTemp.createTemp(
        'learny-fresh-workspace-',
      );
      addTearDown(() async {
        if (await documentsDirectory.exists()) {
          await documentsDirectory.delete(recursive: true);
        }
      });

      await db.upsertCourse(
        CoursesCompanion.insert(
          id: 'course-1',
          name: '软件工程',
          chineseName: '软件工程',
          courseType: 'student',
          semesterId: '2026-spring',
        ),
      );

      final service = FileStorageWorkspaceService(
        database: db,
        getDocumentsDirectory: () async => documentsDirectory,
      );

      final root = await service.ensureFilesRootDirectory();
      final courseDir = await service.ensureCourseDirectory(
        courseId: 'course-1',
      );

      expect(root.path, endsWith('LearnY Files'));
      expect(await root.exists(), isTrue);
      expect(courseDir.path, endsWith('软件工程'));
      expect(await courseDir.exists(), isTrue);
      expect(
        await Directory(
          '${documentsDirectory.path}${Platform.pathSeparator}learnx_files',
        ).exists(),
        isFalse,
      );
    });

    test(
      'migrates legacy LearnX storage into the LearnY workspace and rewrites persisted paths',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final documentsDirectory = await Directory.systemTemp.createTemp(
          'learny-file-workspace-',
        );
        addTearDown(() async {
          if (await documentsDirectory.exists()) {
            await documentsDirectory.delete(recursive: true);
          }
        });

        final legacyRoot = Directory(
          '${documentsDirectory.path}${Platform.pathSeparator}learnx_files',
        );
        final legacyCourseDir = Directory(
          '${legacyRoot.path}${Platform.pathSeparator}course-1',
        );
        await legacyCourseDir.create(recursive: true);

        final legacyFile = File(
          '${legacyCourseDir.path}${Platform.pathSeparator}notes.pdf',
        );
        await legacyFile.writeAsString('hello');

        await db.upsertFile(
          CourseFilesCompanion.insert(
            id: 'file-1',
            courseId: 'course-1',
            fileId: 'remote-1',
            title: 'notes.pdf',
            uploadTime: '2026-04-12 10:00:00',
            downloadUrl: 'https://example.com/notes.pdf',
            previewUrl: 'https://example.com/notes.pdf/preview',
            localDownloadState: const Value('downloaded'),
            localFilePath: Value(legacyFile.path),
          ),
        );
        await db.upsertCachedAsset(
          CachedAssetsCompanion.insert(
            assetKey: 'file-1',
            courseId: 'course-1',
            title: 'notes.pdf',
            localPath: legacyFile.path,
            updatedAt: '2026-04-12T10:00:00.000',
          ),
        );

        final service = FileStorageWorkspaceService(
          database: db,
          getDocumentsDirectory: () async => documentsDirectory,
        );

        final root = await service.ensureFilesRootDirectory();

        expect(root.path, endsWith('LearnY Files'));
        expect(await legacyRoot.exists(), isFalse);

        final migratedFile = File(
          '${root.path}${Platform.pathSeparator}course-1${Platform.pathSeparator}notes.pdf',
        );
        expect(await migratedFile.exists(), isTrue);

        final persistedFile = await db.getFileById('file-1');
        final cachedAsset = await db.getCachedAsset('file-1');
        expect(persistedFile?.localFilePath, migratedFile.path);
        expect(cachedAsset?.localPath, migratedFile.path);
      },
    );

    test(
      'renames course-id subdirectories into human-readable course names',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final documentsDirectory = await Directory.systemTemp.createTemp(
          'learny-course-workspace-',
        );
        addTearDown(() async {
          if (await documentsDirectory.exists()) {
            await documentsDirectory.delete(recursive: true);
          }
        });

        await db.upsertCourse(
          CoursesCompanion.insert(
            id: '2025-2026-2151368409',
            name: '土力学',
            chineseName: '土力学',
            courseType: 'student',
            semesterId: '2025-fall',
          ),
        );

        final legacyRoot = Directory(
          '${documentsDirectory.path}${Platform.pathSeparator}learnx_files',
        );
        final legacyCourseDir = Directory(
          '${legacyRoot.path}${Platform.pathSeparator}2025-2026-2151368409',
        );
        await legacyCourseDir.create(recursive: true);

        final legacyFile = File(
          '${legacyCourseDir.path}${Platform.pathSeparator}week1.pdf',
        );
        await legacyFile.writeAsString('slides');

        await db.upsertFile(
          CourseFilesCompanion.insert(
            id: 'file-1',
            courseId: '2025-2026-2151368409',
            fileId: 'remote-1',
            title: 'week1.pdf',
            uploadTime: '2026-04-12 10:00:00',
            downloadUrl: 'https://example.com/week1.pdf',
            previewUrl: 'https://example.com/week1.pdf/preview',
            localDownloadState: const Value('downloaded'),
            localFilePath: Value(legacyFile.path),
          ),
        );
        await db.upsertCachedAsset(
          CachedAssetsCompanion.insert(
            assetKey: 'file-1',
            courseId: '2025-2026-2151368409',
            title: 'week1.pdf',
            localPath: legacyFile.path,
            updatedAt: '2026-04-12T10:00:00.000',
          ),
        );

        final service = FileStorageWorkspaceService(
          database: db,
          getDocumentsDirectory: () async => documentsDirectory,
        );

        final root = await service.ensureFilesRootDirectory();
        final renamedCourseDir = Directory(
          '${root.path}${Platform.pathSeparator}土力学',
        );
        final renamedFile = File(
          '${renamedCourseDir.path}${Platform.pathSeparator}week1.pdf',
        );

        expect(await renamedCourseDir.exists(), isTrue);
        expect(await renamedFile.exists(), isTrue);
        expect(
          await Directory(
            '${root.path}${Platform.pathSeparator}2025-2026-2151368409',
          ).exists(),
          isFalse,
        );

        final persistedFile = await db.getFileById('file-1');
        final cachedAsset = await db.getCachedAsset('file-1');
        expect(persistedFile?.localFilePath, renamedFile.path);
        expect(cachedAsset?.localPath, renamedFile.path);
      },
    );

    test(
      'rewrites mixed-separator persisted paths and stays idempotent across repeated prepare calls',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final documentsDirectory = await Directory.systemTemp.createTemp(
          'learny-idempotent-workspace-',
        );
        addTearDown(() async {
          if (await documentsDirectory.exists()) {
            await documentsDirectory.delete(recursive: true);
          }
        });

        await db.upsertCourse(
          CoursesCompanion.insert(
            id: '2025-2026-2151368409',
            name: '土力学',
            chineseName: '土力学',
            courseType: 'student',
            semesterId: '2025-fall',
          ),
        );

        final legacyRoot = Directory(
          '${documentsDirectory.path}${Platform.pathSeparator}learnx_files',
        );
        final legacyCourseDir = Directory(
          '${legacyRoot.path}${Platform.pathSeparator}2025-2026-2151368409',
        );
        await legacyCourseDir.create(recursive: true);

        final legacyFile = File(
          '${legacyCourseDir.path}${Platform.pathSeparator}notes.pdf',
        );
        await legacyFile.writeAsString('hello');

        final mixedSeparatorPath =
            '${documentsDirectory.path.replaceAll('\\', '/')}/learnx_files/2025-2026-2151368409/notes.pdf';
        await db.upsertFile(
          CourseFilesCompanion.insert(
            id: 'file-1',
            courseId: '2025-2026-2151368409',
            fileId: 'remote-1',
            title: 'notes.pdf',
            uploadTime: '2026-04-12 10:00:00',
            downloadUrl: 'https://example.com/notes.pdf',
            previewUrl: 'https://example.com/notes.pdf/preview',
            localDownloadState: const Value('downloaded'),
            localFilePath: Value(mixedSeparatorPath),
          ),
        );
        await db.upsertCachedAsset(
          CachedAssetsCompanion.insert(
            assetKey: 'file-1',
            courseId: '2025-2026-2151368409',
            title: 'notes.pdf',
            localPath: mixedSeparatorPath,
            updatedAt: '2026-04-12T10:00:00.000',
          ),
        );

        final service = FileStorageWorkspaceService(
          database: db,
          getDocumentsDirectory: () async => documentsDirectory,
        );

        await service.prepare();
        await service.prepare();

        final root = await service.ensureFilesRootDirectory();
        final migratedFile = File(
          '${root.path}${Platform.pathSeparator}土力学${Platform.pathSeparator}notes.pdf',
        );

        expect(await migratedFile.exists(), isTrue);
        expect(await legacyRoot.exists(), isFalse);
        expect(
          (await db.getFileById('file-1'))?.localFilePath,
          migratedFile.path,
        );
        expect(
          (await db.getCachedAsset('file-1'))?.localPath,
          migratedFile.path,
        );
      },
    );

    test('reuses the same course-name directory for duplicate names', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final documentsDirectory = await Directory.systemTemp.createTemp(
        'learny-duplicate-course-names-',
      );
      addTearDown(() async {
        if (await documentsDirectory.exists()) {
          await documentsDirectory.delete(recursive: true);
        }
      });

      await db.upsertCourse(
        CoursesCompanion.insert(
          id: 'course-a',
          name: '高等数学',
          chineseName: '高等数学',
          courseType: 'student',
          semesterId: '2025-fall',
        ),
      );
      await db.upsertCourse(
        CoursesCompanion.insert(
          id: 'course-b',
          name: '高等数学',
          chineseName: '高等数学',
          courseType: 'student',
          semesterId: '2026-spring',
        ),
      );

      final service = FileStorageWorkspaceService(
        database: db,
        getDocumentsDirectory: () async => documentsDirectory,
      );

      final dirA = await service.ensureCourseDirectory(courseId: 'course-a');
      final dirB = await service.ensureCourseDirectory(courseId: 'course-b');

      expect(dirA.path, endsWith('高等数学'));
      expect(dirB.path, dirA.path);
    });

    test('keeps downloading into the existing course-name directory', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final documentsDirectory = await Directory.systemTemp.createTemp(
        'learny-course-alias-merge-',
      );
      addTearDown(() async {
        if (await documentsDirectory.exists()) {
          await documentsDirectory.delete(recursive: true);
        }
      });

      await db.upsertCourse(
        CoursesCompanion.insert(
          id: 'course-a',
          name: '生物化学基础实验',
          chineseName: '生物化学基础实验',
          courseType: 'student',
          semesterId: '2025-2026-1',
        ),
      );
      await db.upsertCourse(
        CoursesCompanion.insert(
          id: 'course-b',
          name: '生物化学基础实验',
          chineseName: '生物化学基础实验',
          courseType: 'student',
          semesterId: '2025-2026-2',
        ),
      );

      final primaryRoot = Directory(
        '${documentsDirectory.path}${Platform.pathSeparator}LearnY Files',
      );
      final legacyNamedDir = Directory(
        '${primaryRoot.path}${Platform.pathSeparator}生物化学基础实验',
      );
      await legacyNamedDir.create(recursive: true);
      final legacyFile = File(
        '${legacyNamedDir.path}${Platform.pathSeparator}report.pdf',
      );
      await legacyFile.writeAsString('report');

      await db.upsertFile(
        CourseFilesCompanion.insert(
          id: 'file-1',
          courseId: 'course-b',
          fileId: 'remote-1',
          title: 'report.pdf',
          uploadTime: '2026-04-12 10:00:00',
          downloadUrl: 'https://example.com/report.pdf',
          previewUrl: 'https://example.com/report.pdf/preview',
          localDownloadState: const Value('downloaded'),
          localFilePath: Value(legacyFile.path),
        ),
      );

      final service = FileStorageWorkspaceService(
        database: db,
        getDocumentsDirectory: () async => documentsDirectory,
      );

      final targetDir = await service.ensureCourseDirectory(
        courseId: 'course-b',
      );

      expect(targetDir.path, legacyNamedDir.path);
      expect(await legacyFile.exists(), isTrue);
      expect((await db.getFileById('file-1'))?.localFilePath, legacyFile.path);
    });

    test(
      'merges legacy files into an existing LearnY workspace without blocking old users',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final documentsDirectory = await Directory.systemTemp.createTemp(
          'learny-existing-root-workspace-',
        );
        addTearDown(() async {
          if (await documentsDirectory.exists()) {
            await documentsDirectory.delete(recursive: true);
          }
        });

        await db.upsertCourse(
          CoursesCompanion.insert(
            id: 'course-1',
            name: '土力学',
            chineseName: '土力学',
            courseType: 'student',
            semesterId: '2026-spring',
          ),
        );

        final legacyRoot = Directory(
          '${documentsDirectory.path}${Platform.pathSeparator}learnx_files',
        );
        final legacyCourseDir = Directory(
          '${legacyRoot.path}${Platform.pathSeparator}course-1',
        );
        await legacyCourseDir.create(recursive: true);
        final legacyFile = File(
          '${legacyCourseDir.path}${Platform.pathSeparator}legacy.pdf',
        );
        await legacyFile.writeAsString('legacy');

        final primaryRoot = Directory(
          '${documentsDirectory.path}${Platform.pathSeparator}LearnY Files',
        );
        final primaryCourseDir = Directory(
          '${primaryRoot.path}${Platform.pathSeparator}土力学',
        );
        await primaryCourseDir.create(recursive: true);
        final primaryFile = File(
          '${primaryCourseDir.path}${Platform.pathSeparator}fresh.pdf',
        );
        await primaryFile.writeAsString('fresh');

        await db.upsertFile(
          CourseFilesCompanion.insert(
            id: 'file-1',
            courseId: 'course-1',
            fileId: 'remote-1',
            title: 'legacy.pdf',
            uploadTime: '2026-04-12 10:00:00',
            downloadUrl: 'https://example.com/legacy.pdf',
            previewUrl: 'https://example.com/legacy.pdf/preview',
            localDownloadState: const Value('downloaded'),
            localFilePath: Value(legacyFile.path),
          ),
        );

        final service = FileStorageWorkspaceService(
          database: db,
          getDocumentsDirectory: () async => documentsDirectory,
        );

        final root = await service.ensureFilesRootDirectory();
        final migratedLegacyFile = File(
          '${root.path}${Platform.pathSeparator}土力学${Platform.pathSeparator}legacy.pdf',
        );

        expect(await migratedLegacyFile.exists(), isTrue);
        expect(await primaryFile.exists(), isTrue);
        expect(await legacyRoot.exists(), isFalse);
        expect(
          (await db.getFileById('file-1'))?.localFilePath,
          migratedLegacyFile.path,
        );
      },
    );
  });
}
