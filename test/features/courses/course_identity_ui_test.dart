import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/core/design/course_icons/course_icon.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/features/courses/providers/course_identity_provider.dart';
import 'package:learn_y/features/files/unread_files_screen.dart';
import 'package:learn_y/features/search/providers/search_result_factory.dart';
import 'package:learn_y/features/search/widgets/search_result_sections.dart';

void main() {
  testWidgets(
    'selected semester unread groups and search share live course identity',
    (tester) async {
      final database = db.AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final course = await tester.runAsync(() async {
        await database.upsertCourse(
          db.CoursesCompanion.insert(
            id: 'spring-course',
            name: '大学物理',
            chineseName: '大学物理',
            courseType: 'student',
            semesterId: 'spring',
          ),
        );
        await database
            .into(database.courseFiles)
            .insert(
              db.CourseFilesCompanion.insert(
                id: 'spring-file',
                courseId: 'spring-course',
                fileId: 'file',
                title: '历史讲义.pdf',
                uploadTime: '2026-03-01',
                downloadUrl: '',
                previewUrl: '',
                isNew: const Value(true),
              ),
            );
        await database
            .into(database.courseDisplayPrefs)
            .insert(
              db.CourseDisplayPrefsCompanion.insert(
                ownerKey: 'alice',
                semesterId: 'spring',
                courseId: 'spring-course',
                alias: const Value('物理简称'),
                iconKey: const Value('biology'),
                accentKey: const Value('coral'),
                updatedAt: '2026-09-12',
              ),
            );
        return (await database.getCoursesBySemester('spring')).single;
      });
      final result = buildCourseSearchDocument(course!).result;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            initialCurrentSemesterIdProvider.overrideWithValue('spring'),
            courseIdentitiesProvider.overrideWith(
              (ref) => CourseIdentityRepository(database).watchOwner('alice'),
            ),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp(
              home: CourseIdentityScope(
                identities:
                    ref.watch(courseIdentitiesProvider).valueOrNull ?? {},
                child: Scaffold(
                  body: Column(
                    children: [
                      const Expanded(child: UnreadFilesScreen()),
                      SearchResultTile(result: result, onTap: () {}),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('课程'));
      await tester.pumpAndSettle();
      expect(find.text('未知课程'), findsNothing);
      expect(find.text('物理简称'), findsNWidgets(2));
      final icons = tester
          .widgetList<CourseIcon>(find.byType(CourseIcon))
          .toList();
      expect(icons, hasLength(2));
      expect(icons.map((icon) => icon.option.key), everyElement('biology'));
      expect(icons[0].color, icons[1].color);

      await tester.runAsync(
        () =>
            (database.update(
              database.courseDisplayPrefs,
            )..where((table) => table.ownerKey.equals('alice'))).write(
              const db.CourseDisplayPrefsCompanion(iconKey: Value('optics')),
            ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<CourseIcon>(find.byType(CourseIcon))
            .map((icon) => icon.option.key),
        everyElement('optics'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
