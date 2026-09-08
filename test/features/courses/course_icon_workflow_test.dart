import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/design/course_icons/course_icon_catalog.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/features/courses/courses_screen.dart';
import 'package:learn_y/features/courses/providers/course_workbench_controller.dart';
import 'package:learn_y/features/courses/providers/course_workbench_models.dart';
import 'package:learn_y/features/courses/providers/course_workbench_repository.dart';
import 'package:learn_y/features/courses/widgets/course_icon_picker.dart';

void main() {
  test(
    'catalog preserves saved keys and unknown choices have a usable default',
    () {
      const legacy = [
        'general-class',
        'general-seminar',
        'general-lecture',
        'math',
        'physics',
        'statistics',
        'analytics',
        'astronomy',
        'geology',
        'chemistry',
        'biology',
        'medicine',
        'clinical',
        'health',
        'lab',
        'experiment-data',
        'engineering',
        'civil',
        'structure',
        'mechanical',
        'material',
        'electronics',
        'energy',
        'environment',
        'transport',
        'aerospace',
        'computer',
        'code',
        'chip',
        'network',
        'ai',
        'software',
        'data',
        'law',
        'economics',
        'literature',
        'music',
        'language',
        'history',
        'management',
        'art',
        'finance',
        'philosophy',
        'theatre',
        'media',
        'sports',
        'swim',
        'global',
      ];
      expect(courseIconOptions.map((icon) => icon.key).toSet(), hasLength(100));
      expect(courseIconOptions, hasLength(100));
      for (final key in legacy) {
        expect(resolveCourseIconOption(key), isNotNull, reason: key);
      }
      expect(
        courseIconFor(key: 'unavailable', courseName: '有限元分析基础').key,
        'finite-element',
      );
      expect(courseIconFor(key: 'swim', courseName: '有限元分析基础').key, 'swim');
      expect(defaultCourseIcon('没有匹配规则的课程').key, 'general-class');
    },
  );

  testWidgets('pick, cancel, save and restore keep course preferences scoped', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 850);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = AppDatabase(NativeDatabase.memory());
    const scope = CourseWorkbenchScope(ownerKey: 'student', semesterId: 'term');
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        courseWorkbenchScopeProvider.overrideWithValue(scope),
        resolvedCourseCardsProvider.overrideWithValue(AsyncData([_card])),
      ],
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await database.close();
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.windows),
          home: const CoursesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final controller = container.read(
      courseWorkbenchControllerProvider.notifier,
    );
    final repository = container.read(courseDisplayPrefsRepositoryProvider);

    Future<void> pickCompass() async {
      await tester.tap(find.byTooltip('更换图标'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'compass');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('compass')));
      await tester.pumpAndSettle();
      expect(
        container
            .read(courseWorkbenchControllerProvider)
            .draftCards
            .single
            .iconKey,
        'compass',
      );
    }

    await tester.tap(find.byTooltip('编辑课程'));
    await tester.pumpAndSettle();
    await pickCompass();
    expect(
      await tester.runAsync(() => repository.watchScope(scope).first),
      isEmpty,
    );
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('放弃修改'));
    await tester.pumpAndSettle();
    expect(
      container.read(courseWorkbenchControllerProvider).isEditing,
      isFalse,
    );
    expect(
      await tester.runAsync(() => repository.watchScope(scope).first),
      isEmpty,
    );

    await tester.tap(find.byTooltip('编辑课程'));
    await tester.pumpAndSettle();
    await pickCompass();
    await tester.tap(find.text('完成'));
    final saved = await tester.runAsync(
      () => repository
          .watchScope(scope)
          .firstWhere(
            (rows) => rows.isNotEmpty && rows.single.iconKey == 'compass',
          )
          .timeout(const Duration(seconds: 5)),
    );
    await tester.pumpAndSettle();
    expect(saved!.single.courseId, 'course');
    expect(
      container.read(courseWorkbenchControllerProvider).isEditing,
      isFalse,
    );
    expect(
      await tester.runAsync(
        () => repository
            .watchScope(
              const CourseWorkbenchScope(
                ownerKey: 'another',
                semesterId: 'term',
              ),
            )
            .first,
      ),
      isEmpty,
    );

    controller.beginEditing([_card.copyWith(iconKey: 'compass')]);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更换图标'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('default-icon')));
    await tester.pumpAndSettle();
    expect(
      container
          .read(courseWorkbenchControllerProvider)
          .draftCards
          .single
          .iconKey,
      isNull,
    );
    await tester.tap(find.text('完成'));
    final restored = await tester.runAsync(
      () => repository
          .watchScope(scope)
          .firstWhere((rows) => rows.isNotEmpty && rows.single.iconKey == null)
          .timeout(const Duration(seconds: 5)),
    );
    expect(restored!.single.iconKey, isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  test(
    'an edit cannot be saved into a different student or semester',
    () async {
      const original = CourseWorkbenchScope(
        ownerKey: 'student',
        semesterId: 'term',
      );
      for (final changed in [
        const CourseWorkbenchScope(ownerKey: 'another', semesterId: 'term'),
        const CourseWorkbenchScope(
          ownerKey: 'student',
          semesterId: 'next-term',
        ),
      ]) {
        final container = ProviderContainer(
          overrides: [courseWorkbenchScopeProvider.overrideWithValue(changed)],
        );
        addTearDown(container.dispose);
        final controller = container.read(
          courseWorkbenchControllerProvider.notifier,
        );
        controller.beginEditing([_card], scope: original);
        controller.updateIcon('course', 'compass');
        expect(await controller.save(), isFalse);
        expect(
          container
              .read(courseWorkbenchControllerProvider)
              .draftCards
              .single
              .iconKey,
          'compass',
        );
      }
    },
  );

  testWidgets(
    'phone picker supports the keyboard and distinguishes dismiss from default',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);
      CourseIconPickerResult? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await showCourseIconPickerSheet(
                      context,
                      selectedIconKey: 'computer',
                      courseName: '计算机组成原理',
                      courseId: 'course',
                    );
                  },
                  child: const Text('选择'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('选择'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.enterText(find.byType(TextField), 'no-such-icon');
      await tester.pumpAndSettle();
      expect(find.text('没有找到图标'), findsOneWidget);
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await tester.tap(find.text('显示全部'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('default-icon')));
      await tester.pumpAndSettle();
      expect(result?.submitted, isTrue);
      expect(result?.iconKey, isNull);
      result = null;
      await tester.tap(find.text('选择'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      expect(result, isNull);
    },
  );
}

final _card = ResolvedCourseCardModel(
  course: const Course(
    id: 'course',
    name: '计算机组成原理',
    chineseName: '计算机组成原理',
    englishName: '',
    teacherName: '教师',
    teacherNumber: '',
    courseNumber: '',
    courseIndex: 0,
    courseType: 'student',
    semesterId: 'term',
    timeAndLocationJson: '[]',
    sortOrder: 0,
  ),
  unreadNotifications: 0,
  pendingHomeworks: 0,
  totalFiles: 0,
  defaultSortOrder: 0,
);
