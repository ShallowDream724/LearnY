import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/features/courses/providers/course_color_assignment.dart';
import 'package:learn_y/features/courses/providers/course_color_provider.dart';
import 'package:learn_y/features/courses/providers/course_queries.dart';
import 'package:learn_y/features/courses/providers/course_workbench_controller.dart';
import 'package:learn_y/features/courses/providers/course_workbench_models.dart';
import 'package:learn_y/features/courses/providers/course_workbench_repository.dart';

void main() {
  final ids = List.generate(36, (index) => 'course-$index');

  test('20 courses have distinct colors independent of display order', () {
    final colors = assignCourseColors(courseIds: ids.take(20), savedKeys: {});
    expect(colors.values.toSet(), hasLength(20));
    expect(
      assignCourseColors(
        courseIds: ids.take(20).toList().reversed,
        savedKeys: {},
      ),
      colors,
    );
  });

  test('saved assignments survive additions, removal and ordering changes', () {
    final saved = assignCourseColors(courseIds: ids.take(12), savedKeys: {});
    final expanded = assignCourseColors(
      courseIds: ids.take(20).toList().reversed,
      savedKeys: saved,
    );
    for (final id in saved.keys) {
      expect(expanded[id], saved[id]);
    }
    final reduced = assignCourseColors(
      courseIds: ids.take(12).skip(2),
      savedKeys: expanded,
    );
    for (final id in reduced.keys) {
      expect(reduced[id], saved[id]);
    }
    final whileAbsent = assignCourseColors(
      courseIds: ids.take(18).skip(2),
      savedKeys: saved,
    );
    final returned = assignCourseColors(
      courseIds: ids.take(18),
      savedKeys: {...saved, ...whileAbsent},
    );
    expect(returned.values.toSet(), hasLength(18));
  });

  test('36 automatic courses use every color at most twice', () {
    final colors = assignCourseColors(courseIds: ids, savedKeys: {});
    final counts = <String, int>{};
    for (final key in colors.values) {
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    expect(counts, hasLength(20));
    expect(counts.values.every((count) => count <= 2), isTrue);
  });

  test(
    'manual duplicate colors remain intentional while new courses avoid them',
    () {
      final colors = assignCourseColors(
        courseIds: ids.take(20),
        savedKeys: {ids[0]: 'jade', ids[1]: 'jade'},
      );
      expect(colors[ids[0]], 'jade');
      expect(colors[ids[1]], 'jade');
      expect(colors.values.where((key) => key == 'auto:jade'), isEmpty);
    },
  );

  test(
    'automatic persistence preserves customizations, order, owner and semester scope',
    () async {
      final database = db.AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      for (final id in ids.take(3)) {
        await database.upsertCourse(
          db.CoursesCompanion.insert(
            id: id,
            name: id,
            chineseName: id,
            courseType: 'student',
            semesterId: id == ids[2] ? 'spring' : 'fall',
          ),
        );
      }
      await database
          .into(database.courseDisplayPrefs)
          .insert(
            db.CourseDisplayPrefsCompanion.insert(
              ownerKey: 'alice',
              semesterId: 'fall',
              courseId: ids[0],
              sortOrder: const Value(2),
              alias: const Value('简称'),
              iconKey: const Value('biology'),
              updatedAt: '2026-09-12',
            ),
          );
      final repository = CourseColorRepository(database);
      final initial = await repository.watchOwner('alice').first;
      final stored = await database.select(database.courseDisplayPrefs).get();
      final customized = stored.singleWhere((pref) => pref.courseId == ids[0]);
      expect(customized.alias, '简称');
      expect(customized.iconKey, 'biology');
      expect(customized.sortOrder, 2);
      expect(initial, hasLength(3));
      expect(initial[ids[0]], isNot(initial[ids[1]]));
      expect(await repository.watchOwner('alice').first, initial);

      final courses = await database.getCoursesBySemester('fall');
      final cards = buildResolvedCourseCards(
        stats: courses.map((course) => CourseStats(course: course)).toList(),
        prefs: stored.where((pref) => pref.semesterId == 'fall').toList(),
      );
      expect(cards.first.course.id, ids[0]);
      await CourseDisplayPrefsRepository(database).saveScope(
        scope: const CourseWorkbenchScope(
          ownerKey: 'alice',
          semesterId: 'fall',
        ),
        cards: [
          cards.first.copyWith(
            accentKey: 'coral',
            clearAlias: true,
            clearIconKey: true,
          ),
        ],
      );
      final changed = await repository.watchOwner('alice').first;
      expect(changed[cards.first.course.id], StudyTone.coral);
      final after = await database.select(database.courseDisplayPrefs).get();
      expect(after, hasLength(3));
      expect(
        after
            .singleWhere((pref) => pref.courseId == cards.first.course.id)
            .alias,
        isNull,
      );
      await repository.watchOwner('bob').first;
      expect(await repository.watchOwner('alice').first, changed);
      expect(
        (await database.select(database.courseDisplayPrefs).get()).where(
          (pref) => pref.ownerKey == 'bob',
        ),
        hasLength(3),
      );
    },
  );

  test(
    'color changes remain in the workbench draft and cancel discards them',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        courseWorkbenchControllerProvider.notifier,
      );
      final course = db.Course(
        id: 'a',
        name: '课程',
        chineseName: '课程',
        englishName: '',
        teacherName: '',
        teacherNumber: '',
        courseNumber: '',
        courseIndex: 0,
        courseType: 'student',
        semesterId: 'fall',
        timeAndLocationJson: '[]',
        sortOrder: 0,
      );
      final cards = buildResolvedCourseCards(
        stats: [CourseStats(course: course)],
        prefs: [],
      );
      controller.beginEditing(cards);
      controller.updateColor('a', 'jade');
      expect(
        container
            .read(courseWorkbenchControllerProvider)
            .draftCards
            .single
            .accentKey,
        'jade',
      );
      expect(
        container
            .read(courseWorkbenchControllerProvider)
            .baselineCards
            .single
            .accentKey,
        cards.single.accentKey,
      );
      expect(await controller.cancelEditing(force: false), isFalse);
      expect(await controller.cancelEditing(force: true), isTrue);
      expect(
        container.read(courseWorkbenchControllerProvider).isEditing,
        isFalse,
      );
    },
  );
}
