import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/courses/providers/course_queries.dart';
import 'package:learn_y/features/courses/providers/course_workbench_models.dart';

void main() {
  group('buildResolvedCourseCards', () {
    test('applies persisted order and customization before default cards', () {
      final cards = buildResolvedCourseCards(
        stats: [
          _stats(courseId: 'course-a', name: '土力学', teacherName: '张老师'),
          _stats(courseId: 'course-b', name: '分子生物学', teacherName: '李老师'),
          _stats(courseId: 'course-c', name: '西方音乐剧'),
        ],
        prefs: [
          _pref(
            courseId: 'course-b',
            sortOrder: 0,
            alias: '分生',
            iconKey: 'biology',
          ),
          _pref(courseId: 'course-a', sortOrder: 1, iconKey: 'engineering'),
        ],
      );

      expect(cards.map((card) => card.course.id).toList(), [
        'course-b',
        'course-a',
        'course-c',
      ]);
      expect(cards[0].displayTitle, '分生');
      expect(cards[0].secondaryLabel, '分子生物学 · 李老师');
      expect(cards[0].iconKey, 'biology');
      expect(cards[1].iconKey, 'engineering');
      expect(cards[2].defaultSortOrder, 2);
    });

    test('ignores stale prefs that do not belong to current course stats', () {
      final cards = buildResolvedCourseCards(
        stats: [
          _stats(courseId: 'course-a', name: '土力学'),
          _stats(courseId: 'course-b', name: '法律与社会'),
        ],
        prefs: [
          _pref(courseId: 'course-x', sortOrder: 0, alias: '旧课程'),
          _pref(courseId: 'course-b', sortOrder: 1, alias: '法律'),
        ],
      );

      expect(cards.map((card) => card.course.id).toList(), [
        'course-b',
        'course-a',
      ]);
      expect(cards.any((card) => card.course.id == 'course-x'), isFalse);
    });
  });
}

CourseStats _stats({
  required String courseId,
  required String name,
  String teacherName = '',
}) {
  return CourseStats(
    course: db.Course(
      id: courseId,
      name: name,
      chineseName: name,
      englishName: '',
      teacherName: teacherName,
      teacherNumber: '',
      courseNumber: '',
      courseIndex: 0,
      courseType: 'student',
      semesterId: '2025-fall',
      timeAndLocationJson: '[]',
      sortOrder: 0,
      lastSynced: null,
    ),
    unreadNotifications: 1,
    pendingHomeworks: 2,
    totalFiles: 3,
  );
}

db.CourseDisplayPref _pref({
  required String courseId,
  required int sortOrder,
  String? alias,
  String? iconKey,
}) {
  return db.CourseDisplayPref(
    ownerKey: 'user-a',
    semesterId: '2025-fall',
    courseId: courseId,
    sortOrder: sortOrder,
    iconKey: iconKey,
    alias: alias,
    accentKey: null,
    updatedAt: '2026-04-03T20:00:00.000',
  );
}
