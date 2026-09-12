import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/features/files/providers/file_queries.dart';
import 'package:learn_y/features/home/providers/home_providers.dart';

void main() {
  test(
    'home and expanded unread files follow the same semester across switches',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(database),
          initialCurrentSemesterIdProvider.overrideWithValue('fall'),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      for (final semester in ['fall', 'spring']) {
        await database.upsertCourse(
          CoursesCompanion.insert(
            id: semester,
            name: semester,
            chineseName: semester,
            courseType: 'student',
            semesterId: semester,
          ),
        );
        for (final unread in [true, false]) {
          await database
              .into(database.courseFiles)
              .insert(
                CourseFilesCompanion.insert(
                  id: '$semester-$unread',
                  courseId: semester,
                  fileId: '$semester-$unread',
                  title: 'lecture.pdf',
                  uploadTime: '2026-09-12',
                  downloadUrl: '',
                  previewUrl: '',
                  isNew: Value(unread),
                ),
              );
        }
      }
      container.listen(unreadFilesProvider, (_, _) {});
      container.listen(homeDataProvider, (_, _) {});
      for (final semester in ['fall', 'spring', 'fall']) {
        container.read(currentSemesterIdProvider.notifier).state = semester;
        final files = await container.read(unreadFilesProvider.future);
        final home = await container.read(homeDataProvider.future);
        expect(files.map((f) => f.id), ['$semester-true']);
        expect(home.newFiles.map((f) => f.id), files.map((f) => f.id));
      }
      container.read(currentSemesterIdProvider.notifier).state = null;
      expect(await container.read(unreadFilesProvider.future), isEmpty);
    },
  );
}
