import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/courses/providers/course_workbench_controller.dart';
import 'package:learn_y/features/courses/providers/course_workbench_models.dart';

void main() {
  group('CourseWorkbenchController', () {
    test(
      'completeDragging clears transient drag state but keeps reordered draft',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final controller = container.read(
          courseWorkbenchControllerProvider.notifier,
        );
        final initialCards = [
          _card(courseId: 'course-a', name: '工程项目管理'),
          _card(courseId: 'course-b', name: '计算流体力学基础'),
          _card(courseId: 'course-c', name: '有限元分析基础'),
        ];

        controller.beginEditing(initialCards);
        controller.startDragging('course-c');
        controller.previewReorder(
          draggedCourseId: 'course-c',
          targetCourseId: 'course-b',
          insertIndex: 1,
        );
        controller.completeDragging();

        final state = container.read(courseWorkbenchControllerProvider);
        expect(state.draggingCourseId, isNull);
        expect(state.hoverCourseId, isNull);
        expect(state.draftCards.map((card) => card.course.id).toList(), [
          'course-a',
          'course-c',
          'course-b',
        ]);
      },
    );

    test('previewReorder can switch insertion side around the same target card', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        courseWorkbenchControllerProvider.notifier,
      );
      final initialCards = [
        _card(courseId: 'course-a', name: '工程项目管理'),
        _card(courseId: 'course-b', name: '计算流体力学基础'),
        _card(courseId: 'course-c', name: '有限元分析基础'),
      ];

      controller.beginEditing(initialCards);
      controller.startDragging('course-c');
      controller.previewReorder(
        draggedCourseId: 'course-c',
        targetCourseId: 'course-a',
        insertIndex: 0,
      );
      controller.previewReorder(
        draggedCourseId: 'course-c',
        targetCourseId: 'course-a',
        insertIndex: 2,
      );

      final state = container.read(courseWorkbenchControllerProvider);
      expect(state.hoverCourseId, 'course-a');
      expect(state.hoverInsertIndex, 2);
      expect(state.draftCards.map((card) => card.course.id).toList(), [
        'course-a',
        'course-c',
        'course-b',
      ]);
    });
  });
}

ResolvedCourseCardModel _card({
  required String courseId,
  required String name,
}) {
  return ResolvedCourseCardModel(
    course: db.Course(
      id: courseId,
      name: name,
      chineseName: name,
      englishName: '',
      teacherName: '教师',
      teacherNumber: '',
      courseNumber: '',
      courseIndex: 0,
      courseType: 'student',
      semesterId: '2025-fall',
      timeAndLocationJson: '[]',
      sortOrder: 0,
      lastSynced: null,
    ),
    unreadNotifications: 0,
    pendingHomeworks: 0,
    totalFiles: 0,
    defaultSortOrder: 0,
  );
}
