import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/features/courses/courses_screen.dart';
import 'package:learn_y/features/courses/providers/course_workbench_controller.dart';
import 'package:learn_y/features/courses/providers/course_workbench_models.dart';
import 'package:learn_y/features/courses/providers/course_workbench_repository.dart';

void main() {
  Future<ProviderContainer> openEditor(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final database = AppDatabase(NativeDatabase.memory());
    final cards = List.generate(16, _card);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        resolvedCourseCardsProvider.overrideWithValue(AsyncData(cards)),
        courseWorkbenchScopeProvider.overrideWithValue(
          const CourseWorkbenchScope(
            ownerKey: 'preview',
            semesterId: '2026-2027-1',
          ),
        ),
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
    await tester.tap(find.byTooltip('编辑课程'));
    await tester.pumpAndSettle();
    return container;
  }

  Finder card(int index) => find.byKey(ValueKey('course-card-c$index'));

  testWidgets('mouse moves a course directly from first to last and back', (
    tester,
  ) async {
    final container = await openEditor(tester, const Size(1280, 1000));
    final start = tester.getRect(card(0));
    final last = tester.getRect(card(15));
    // Grab near the right edge to expose feedback-origin / pointer confusion.
    final mouse = await tester.startGesture(
      Offset(start.right - 24, start.center.dy),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      container.read(courseWorkbenchControllerProvider).draggingCourseId,
      'c0',
    );
    await mouse.moveTo(Offset(last.right - 16, last.center.dy));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    var state = container.read(courseWorkbenchControllerProvider);
    expect(state.draftCards.last.course.id, 'c0');
    expect(state.draggingCourseId, isNull);
    expect(find.text('向前移动'), findsNothing);

    final first = tester.getRect(card(1));
    final reverse = await tester.startGesture(
      tester.getCenter(card(0)),
      kind: PointerDeviceKind.mouse,
    );
    await reverse.moveBy(const Offset(-24, 0));
    await tester.pump();
    await reverse.moveTo(Offset(first.left + 16, first.center.dy));
    await tester.pump();
    await reverse.up();
    await tester.pumpAndSettle();
    state = container.read(courseWorkbenchControllerProvider);
    expect(
      state.draftCards.map((c) => c.course.id),
      List.generate(16, (i) => 'c$i'),
    );
    expect(state.hoverCourseId, isNull);
  });

  testWidgets(
    'holding a mouse drag at the edge scrolls and updates its destination',
    (tester) async {
      final container = await openEditor(tester, const Size(1100, 480));
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final mouse = await tester.startGesture(
        tester.getCenter(card(0)),
        kind: PointerDeviceKind.mouse,
      );
      await mouse.moveBy(const Offset(24, 0));
      await tester.pump();
      await mouse.moveTo(const Offset(1060, 452));
      for (var frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(scroll.pixels, greaterThan(0));
      expect(
        container
            .read(courseWorkbenchControllerProvider)
            .draftCards
            .indexWhere((c) => c.course.id == 'c0'),
        greaterThan(7),
      );
      await mouse.up();
      await tester.pumpAndSettle();
      final stoppedAt = scroll.pixels;
      await tester.pump(const Duration(milliseconds: 400));
      expect(scroll.pixels, stoppedAt);
      expect(
        container.read(courseWorkbenchControllerProvider).draggingCourseId,
        isNull,
      );
    },
  );

  testWidgets(
    'touch on Windows scrolls normally and uses long press to reorder',
    (tester) async {
      final container = await openEditor(tester, const Size(1100, 480));
      final scroll = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      await tester.drag(card(0), const Offset(0, -120));
      await tester.pumpAndSettle();
      expect(scroll.pixels, greaterThan(0));
      expect(
        container.read(courseWorkbenchControllerProvider).hasChanges,
        isFalse,
      );
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final target = tester.getRect(card(3));
      final touch = await tester.startGesture(tester.getCenter(card(0)));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
      expect(
        container.read(courseWorkbenchControllerProvider).draggingCourseId,
        'c0',
      );
      await touch.moveTo(Offset(target.right - 16, target.center.dy));
      await tester.pump();
      await touch.up();
      await tester.pumpAndSettle();
      expect(
        container
            .read(courseWorkbenchControllerProvider)
            .draftCards[3]
            .course
            .id,
        'c0',
      );
    },
  );
}

ResolvedCourseCardModel _card(int index) => ResolvedCourseCardModel(
  course: Course(
    id: 'c$index',
    name: 'Course $index',
    chineseName: 'Course $index',
    englishName: '',
    teacherName: 'Teacher',
    teacherNumber: '',
    courseNumber: '',
    courseIndex: index,
    courseType: 'student',
    semesterId: '2026-2027-1',
    timeAndLocationJson: '[]',
    sortOrder: index,
  ),
  unreadNotifications: 0,
  pendingHomeworks: 0,
  totalFiles: 0,
  defaultSortOrder: index,
);
