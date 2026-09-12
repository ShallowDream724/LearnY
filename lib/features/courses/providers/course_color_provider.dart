import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/design/app_materials.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/stream_combiner.dart';
import 'course_color_assignment.dart';
import 'course_workbench_models.dart';

/// Covers every cached semester, including the independently browsed timetable.
final courseColorsProvider = StreamProvider<Map<String, StudyTone>>((ref) {
  final database = ref.watch(databaseProvider);
  final owner = CourseWorkbenchScope.normalizeOwner(
    ref.watch(authProvider).username ??
        ref.watch(learningDataOwnerProvider).valueOrNull ??
        '',
  );
  return CourseColorRepository(database).watchOwner(owner);
});

class CourseColorRepository {
  const CourseColorRepository(this.database);
  final db.AppDatabase database;

  Stream<Map<String, StudyTone>> watchOwner(String owner) =>
      combineLatest2(
        database.select(database.courses).watch(),
        (database.select(
          database.courseDisplayPrefs,
        )..where((table) => table.ownerKey.equals(owner))).watch(),
        (courses, prefs) => courses,
      ).asyncMap(
        (courses) => database.transaction(() async {
          // Read inside the transaction so a concurrent manual save always wins.
          final prefs = await (database.select(
            database.courseDisplayPrefs,
          )..where((table) => table.ownerKey.equals(owner))).get();
          final result = <String, StudyTone>{};
          final bySemester = <String, List<db.Course>>{};
          for (final course in courses) {
            bySemester.putIfAbsent(course.semesterId, () => []).add(course);
          }
          for (final entry in bySemester.entries) {
            final saved = {
              for (final pref in prefs)
                if (pref.semesterId == entry.key) pref.courseId: pref.accentKey,
            };
            final assigned = assignCourseColors(
              courseIds: entry.value.map((course) => course.id),
              savedKeys: saved,
            );
            for (final course in entry.value) {
              final key = assigned[course.id]!;
              result[course.id] = StudyTone.fromKey(key)!;
              if (saved[course.id] != null) continue;
              await database
                  .into(database.courseDisplayPrefs)
                  .insert(
                    db.CourseDisplayPrefsCompanion.insert(
                      ownerKey: owner,
                      semesterId: entry.key,
                      courseId: course.id,
                      sortOrder: const Value(-1),
                      accentKey: Value(key),
                      updatedAt: DateTime.now().toIso8601String(),
                    ),
                    onConflict: DoUpdate(
                      (_) =>
                          db.CourseDisplayPrefsCompanion(accentKey: Value(key)),
                    ),
                  );
            }
          }
          return Map<String, StudyTone>.unmodifiable(result);
        }),
      );
}
