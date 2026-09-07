import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/learning_read_api.dart';
import '../api/models.dart' as api;
import '../database/app_state_keys.dart';
import '../database/database.dart';
import '../providers/api_client_provider.dart';
import '../providers/app_providers.dart';
import 'semester_models.dart';
import 'academic_calendar.dart';

class SemesterRepository {
  const SemesterRepository({required this.apiClient, required this.database});

  final LearningReadApi apiClient;
  final AppDatabase database;

  Future<SemesterCatalogRefresh> refreshCatalog({
    void Function()? ensureActive,
  }) async {
    Object? listError;
    Object? currentError;
    final idsFuture = apiClient.getSemesterIdList().then<List<String>?>(
      (value) => value,
      onError: (Object error) {
        listError = error;
        return null;
      },
    );
    final currentFuture = apiClient
        .getCurrentSemester()
        .then<api.SemesterInfo?>(
          (value) => value,
          onError: (Object error) {
            currentError = error;
            return null;
          },
        );
    final ids = await idsFuture;
    final current = await currentFuture;
    ensureActive?.call();
    if (ids == null && current == null) {
      throw currentError ?? listError ?? StateError('学期列表暂不可用');
    }

    await database.transaction(() async {
      for (final id in {...?ids, if (current != null) current.id}) {
        ensureActive?.call();
        final identity = SemesterIdentity.tryParse(id);
        if (identity == null) continue;
        final existing = await database.getSemesterById(identity.id);
        final details = current?.id == identity.id ? current : null;
        await database.upsertSemester(
          SemestersCompanion.insert(
            id: identity.id,
            startDate: details?.startDate ?? existing?.startDate ?? '',
            endDate: details?.endDate ?? existing?.endDate ?? '',
            startYear: identity.startYear,
            endYear: identity.endYear,
            type: identity.type,
          ),
        );
      }
      if (current != null) {
        await database.setState(
          AppStateKeys.serverCurrentSemesterId,
          current.id,
        );
      }
      ensureActive?.call();
    });
    return SemesterCatalogRefresh(
      currentId:
          current?.id ??
          await database.getState(AppStateKeys.serverCurrentSemesterId),
      warning: listError != null || currentError != null
          ? '部分学期信息未能更新，已保留本地记录'
          : null,
    );
  }

  Future<Semester> ensureSemester(
    String id, {
    void Function()? ensureActive,
  }) async {
    final existing = await database.getSemesterById(id);
    ensureActive?.call();
    if (existing != null) return existing;
    final identity = SemesterIdentity.tryParse(id);
    if (identity == null) throw ArgumentError.value(id, 'id', '学期格式无效');
    await database.transaction(() async {
      ensureActive?.call();
      await database.upsertSemester(
        SemestersCompanion.insert(
          id: identity.id,
          startDate: '',
          endDate: '',
          startYear: identity.startYear,
          endYear: identity.endYear,
          type: identity.type,
        ),
      );
      ensureActive?.call();
    });
    return (await database.getSemesterById(id))!;
  }

  Future<void> saveSelection(String id) =>
      database.setState(AppStateKeys.currentSemesterId, id);
}

final semesterRepositoryProvider = Provider<SemesterRepository>((ref) {
  return SemesterRepository(
    apiClient: ref.watch(learningReadApiProvider),
    database: ref.watch(databaseProvider),
  );
});

final academicCalendarProvider = Provider<AcademicCalendar>(
  (ref) => const AcademicCalendar(),
);

final semesterCatalogProvider = StreamProvider<List<Semester>>((ref) {
  return ref.watch(databaseProvider).watchSemesters();
});

final serverCurrentSemesterIdProvider = StreamProvider<String?>((ref) {
  return ref
      .watch(databaseProvider)
      .watchState(AppStateKeys.serverCurrentSemesterId);
});
