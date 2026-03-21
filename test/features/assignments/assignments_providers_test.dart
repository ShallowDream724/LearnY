import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/assignments/providers/assignments_providers.dart';

void main() {
  group('buildAssignmentsPresentation', () {
    test('computes stats while applying the selected filter', () {
      final now = DateTime(2026, 3, 18, 10);
      final presentation = buildAssignmentsPresentation(
        homeworks: [
          _homework(
            id: 'overdue',
            courseId: 'course-1',
            deadline: now.subtract(const Duration(days: 1)),
          ),
          _homework(
            id: 'soon',
            courseId: 'course-1',
            deadline: now.add(const Duration(days: 1)),
          ),
          _homework(
            id: 'submitted',
            courseId: 'course-1',
            deadline: now.add(const Duration(days: 2)),
            submitted: true,
          ),
          _homework(
            id: 'graded',
            courseId: 'course-1',
            deadline: now.add(const Duration(days: 3)),
            graded: true,
            grade: 96,
          ),
        ],
        filter: HomeworkFilter.pending,
        now: now,
      );

      expect(presentation.stats.pending, 2);
      expect(presentation.stats.submitted, 1);
      expect(presentation.stats.graded, 1);
      expect(presentation.stats.overdue, 1);
      expect(
        presentation.filteredHomeworks.map((homework) => homework.id).toList(),
        ['overdue', 'soon'],
      );
      expect(presentation.sections.map((section) => section.group).toList(), [
        AssignmentTimelineGroup.thisWeek,
      ]);
    });

    test('orders sections by urgency and sorts each section by deadline', () {
      final now = DateTime(2026, 3, 18, 10);
      final presentation = buildAssignmentsPresentation(
        homeworks: [
          _homework(
            id: 'this-week-2',
            courseId: 'course-1',
            deadline: now.add(const Duration(days: 2)),
          ),
          _homework(
            id: 'next-week',
            courseId: 'course-1',
            deadline: now.add(const Duration(days: 7)),
          ),
          _homework(
            id: 'later',
            courseId: 'course-1',
            deadline: now.add(const Duration(days: 21)),
          ),
          _homework(
            id: 'done',
            courseId: 'course-1',
            deadline: now.add(const Duration(days: 4)),
            submitted: true,
          ),
          _homework(
            id: 'this-week-1',
            courseId: 'course-1',
            deadline: now.add(const Duration(hours: 2)),
          ),
        ],
        filter: HomeworkFilter.all,
        now: now,
      );

      expect(presentation.sections.map((section) => section.group).toList(), [
        AssignmentTimelineGroup.thisWeek,
        AssignmentTimelineGroup.nextWeek,
        AssignmentTimelineGroup.later,
        AssignmentTimelineGroup.done,
      ]);
      expect(
        presentation.sections.first.homeworks
            .map((homework) => homework.id)
            .toList(),
        ['this-week-1', 'this-week-2'],
      );
    });

    test('keeps a Monday deadline in next week even on Saturday afternoon', () {
      final now = DateTime(2026, 3, 21, 12, 50);
      final presentation = buildAssignmentsPresentation(
        homeworks: [
          _homework(
            id: 'monday-deadline',
            courseId: 'course-1',
            deadline: DateTime(2026, 3, 23, 18),
          ),
        ],
        filter: HomeworkFilter.all,
        now: now,
      );

      expect(presentation.sections, hasLength(1));
      expect(
        presentation.sections.single.group,
        AssignmentTimelineGroup.nextWeek,
      );
      expect(
        presentation.sections.single.homeworks.single.id,
        'monday-deadline',
      );
    });
  });
}

db.Homework _homework({
  required String id,
  required String courseId,
  required DateTime deadline,
  bool submitted = false,
  bool graded = false,
  double? grade,
}) {
  return db.Homework(
    id: id,
    courseId: courseId,
    baseId: id,
    title: 'Homework $id',
    description: null,
    deadline: deadline.millisecondsSinceEpoch.toString(),
    lateSubmissionDeadline: null,
    submitTime: null,
    submitted: submitted,
    graded: graded,
    grade: grade,
    gradeLevel: null,
    graderName: null,
    gradeContent: null,
    gradeTime: null,
    isLateSubmission: false,
    completionType: null,
    submissionType: null,
    isFavorite: false,
    comment: null,
    attachmentJson: null,
    answerContent: null,
    answerAttachmentJson: null,
    submittedContent: null,
    submittedAttachmentJson: null,
    gradeAttachmentJson: null,
  );
}
