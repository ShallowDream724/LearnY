import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';

class _VersionSixDatabase extends AppDatabase {
  _VersionSixDatabase(super.executor);
  @override
  int get schemaVersion => 6;
}

void main() {
  test(
    'repairs cached homework titles once without changing grade or submission',
    () async {
      final directory = await Directory.systemTemp.createTemp('learny-title-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/cache.sqlite');
      final legacy = _VersionSixDatabase(NativeDatabase(file));
      await legacy.upsertHomework(
        HomeworksCompanion.insert(
          id: 'old-homework',
          courseId: 'old-course',
          baseId: 'base',
          title: 'PDE&mdash;&mdash; &amp;lt;T&amp;gt;',
          deadline: '1',
          graded: const Value(true),
          submitted: const Value(true),
          grade: const Value(9.7),
          submittedContent: const Value('<p>已交内容</p>'),
        ),
      );
      await legacy.close();
      for (var open = 0; open < 2; open++) {
        final database = AppDatabase(NativeDatabase(file));
        try {
          final homework = (await database.getHomeworkById('old-homework'))!;
          expect(homework.title, 'PDE—— &lt;T&gt;');
          expect(homework.grade, 9.7);
          expect(homework.submitted, isTrue);
          expect(homework.submittedContent, '<p>已交内容</p>');
        } finally {
          await database.close();
        }
      }
    },
  );
}
