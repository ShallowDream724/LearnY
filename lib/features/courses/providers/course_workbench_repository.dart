import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/providers/providers.dart';
import 'course_queries.dart';
import 'course_color_assignment.dart';
import 'course_workbench_models.dart';

class CourseDisplayPrefsRepository {
  const CourseDisplayPrefsRepository(this._db);

  final db.AppDatabase _db;

  Stream<List<db.CourseDisplayPref>> watchScope(CourseWorkbenchScope scope) {
    return _db.watchCourseDisplayPrefsByScope(
      ownerKey: scope.ownerKey,
      semesterId: scope.semesterId,
    );
  }

  Future<void> saveScope({
    required CourseWorkbenchScope scope,
    required List<ResolvedCourseCardModel> cards,
  }) {
    final now = DateTime.now().toIso8601String();
    final colors = assignCourseColors(
      courseIds: cards.map((card) => card.course.id),
      savedKeys: {for (final card in cards) card.course.id: card.accentKey},
    );
    // Keep preferences for temporarily absent courses so their identity survives
    // a partial sync or a later return to the roster.
    return _db.batch(
      (batch) => batch.insertAllOnConflictUpdate(_db.courseDisplayPrefs, [
        for (var index = 0; index < cards.length; index += 1)
          db.CourseDisplayPrefsCompanion.insert(
            ownerKey: scope.ownerKey,
            semesterId: scope.semesterId,
            courseId: cards[index].course.id,
            sortOrder: Value(index),
            updatedAt: now,
            iconKey: Value(cards[index].iconKey),
            alias: Value(cards[index].alias),
            accentKey: Value(
              cards[index].accentKey ?? colors[cards[index].course.id],
            ),
          ),
      ]),
    );
  }
}

final courseDisplayPrefsRepositoryProvider =
    Provider<CourseDisplayPrefsRepository>((ref) {
      return CourseDisplayPrefsRepository(ref.watch(databaseProvider));
    });

final courseWorkbenchScopeProvider = Provider<CourseWorkbenchScope?>((ref) {
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null || semesterId.trim().isEmpty) {
    return null;
  }

  final owner =
      ref.watch(authProvider).username ??
      ref.watch(learningDataOwnerProvider).valueOrNull ??
      '';

  return CourseWorkbenchScope(
    ownerKey: CourseWorkbenchScope.normalizeOwner(owner),
    semesterId: semesterId,
  );
});

final courseDisplayPrefsProvider = StreamProvider<List<db.CourseDisplayPref>>((
  ref,
) {
  final scope = ref.watch(courseWorkbenchScopeProvider);
  if (scope == null) {
    return Stream.value(const <db.CourseDisplayPref>[]);
  }

  return ref.watch(courseDisplayPrefsRepositoryProvider).watchScope(scope);
});

final resolvedCourseCardsProvider =
    Provider<AsyncValue<List<ResolvedCourseCardModel>>>((ref) {
      final statsAsync = ref.watch(courseStatsProvider);
      final prefsAsync = ref.watch(courseDisplayPrefsProvider);

      if (statsAsync.hasError) {
        return AsyncValue.error(
          statsAsync.error!,
          statsAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (prefsAsync.hasError) {
        return AsyncValue.error(
          prefsAsync.error!,
          prefsAsync.stackTrace ?? StackTrace.current,
        );
      }

      final stats = statsAsync.valueOrNull;
      final prefs = prefsAsync.valueOrNull;
      if (stats == null || prefs == null) {
        return const AsyncValue.loading();
      }

      return AsyncValue.data(
        buildResolvedCourseCards(stats: stats, prefs: prefs),
      );
    });
