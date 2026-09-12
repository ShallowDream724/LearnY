import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/assignments/widgets/assignment_list_item.dart';

void main() {
  testWidgets('numeric grade keeps an explicit score unit on a phone row', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AssignmentListItem(
          homework: _homework(grade: 99.5),
          courseName: '算法设计',
          now: DateTime(2026, 3, 18, 10),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('99.5 分'), findsOneWidget);
    expect(find.text('已批改'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('symbolic grade is shown directly without a redundant state', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        AssignmentListItem(
          homework: _homework(grade: -100),
          courseName: '',
          now: DateTime(2026, 3, 18, 10),
          onTap: () {},
        ),
      ),
    );

    expect(find.text('已阅'), findsOneWidget);
    expect(find.text('已批改'), findsNothing);
  });
}

Widget _testApp(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(width: 328, child: child),
    ),
  ),
);

db.Homework _homework({required double grade}) => db.Homework(
  id: 'homework',
  courseId: 'course',
  baseId: 'homework',
  title: '第一章习题',
  description: null,
  deadline: DateTime(2026, 3, 20, 18).millisecondsSinceEpoch.toString(),
  lateSubmissionDeadline: null,
  submitTime: null,
  submitted: true,
  graded: true,
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
