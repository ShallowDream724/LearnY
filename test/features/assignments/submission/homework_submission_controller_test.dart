import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/assignments/submission/homework_submission_controller.dart';
import 'package:learn_y/features/assignments/submission/homework_submission_models.dart';
import 'package:learn_y/features/assignments/submission/homework_submission_repository.dart';

void main() {
  group('HomeworkSubmissionSeed', () {
    test('hydrates stripped initial content and existing attachment state', () {
      final seed = HomeworkSubmissionSeed.fromHomework(
        _homework(
          submittedContent: '<p>Hello&nbsp;World</p>',
          submittedAttachmentJson: '{"id":"a"}',
        ),
      );

      expect(seed.initialContent, 'Hello World');
      expect(seed.hasExistingAttachment, isTrue);
    });
  });

  group('HomeworkSubmissionController', () {
    test('tracks attachment replacement and removal through state', () {
      final controller = HomeworkSubmissionController(
        seed: const HomeworkSubmissionSeed(
          homeworkId: 'hw-1',
          initialContent: '',
          hasExistingAttachment: true,
        ),
        coordinator: HomeworkSubmissionCoordinator(
          repository: _RecordingRepository(),
          refreshHomeworks: () async {},
        ),
      );

      controller.selectAttachment(
        const HomeworkSubmissionAttachment(
          path: '/tmp/report.pdf',
          name: 'report.pdf',
          sizeBytes: 1024,
        ),
      );

      expect(controller.state.hasSelectedAttachment, isTrue);
      expect(controller.state.hasExistingAttachment, isFalse);
      expect(controller.state.hasUnsavedChanges, isTrue);

      controller.removeAttachment();

      expect(controller.state.hasSelectedAttachment, isFalse);
      expect(controller.state.hasExistingAttachment, isFalse);
      expect(controller.state.hasUnsavedChanges, isTrue);
    });

    test(
      'submits built request through coordinator and reaches success',
      () async {
        final repository = _RecordingRepository();
        final controller = HomeworkSubmissionController(
          seed: const HomeworkSubmissionSeed(
            homeworkId: 'hw-2',
            initialContent: 'old',
            hasExistingAttachment: true,
          ),
          coordinator: HomeworkSubmissionCoordinator(
            repository: repository,
            refreshHomeworks: () async {},
          ),
        );

        controller.updateContent('new content');
        controller.removeAttachment();

        final success = await controller.submit();

        expect(success, isTrue);
        expect(controller.state.status, HomeworkSubmissionStatus.success);
        expect(repository.requests.single.homeworkId, 'hw-2');
        expect(repository.requests.single.content, 'new content');
        expect(repository.requests.single.removeAttachment, isTrue);
      },
    );

    test('surfaces failure message when submission throws', () async {
      final controller = HomeworkSubmissionController(
        seed: const HomeworkSubmissionSeed(
          homeworkId: 'hw-3',
          initialContent: '',
          hasExistingAttachment: false,
        ),
        coordinator: HomeworkSubmissionCoordinator(
          repository: _ThrowingRepository(),
          refreshHomeworks: () async {},
        ),
      );

      final success = await controller.submit();

      expect(success, isFalse);
      expect(controller.state.status, HomeworkSubmissionStatus.failure);
      expect(controller.state.errorMessage, contains('提交失败'));
    });
  });

  group('HomeworkSubmissionCoordinator', () {
    test('refreshes homeworks after repository submit succeeds', () async {
      final repository = _RecordingRepository();
      var refreshCalls = 0;
      final coordinator = HomeworkSubmissionCoordinator(
        repository: repository,
        refreshHomeworks: () async {
          refreshCalls++;
        },
      );

      await coordinator.submit(
        const HomeworkSubmissionRequest(homeworkId: 'hw-4'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.requests.single.homeworkId, 'hw-4');
      expect(refreshCalls, 1);
    });
  });
}

class _RecordingRepository implements HomeworkSubmissionRepository {
  final List<HomeworkSubmissionRequest> requests = [];

  @override
  Future<void> submit(HomeworkSubmissionRequest request) async {
    requests.add(request);
  }
}

class _ThrowingRepository implements HomeworkSubmissionRepository {
  @override
  Future<void> submit(HomeworkSubmissionRequest request) async {
    throw Exception('network down');
  }
}

db.Homework _homework({
  String? submittedContent,
  String? submittedAttachmentJson,
}) {
  return db.Homework(
    id: 'hw-1',
    courseId: 'course-1',
    baseId: 'base-1',
    title: 'Homework',
    description: null,
    deadline: DateTime(2026, 3, 21).millisecondsSinceEpoch.toString(),
    lateSubmissionDeadline: null,
    submitTime: null,
    submitted: true,
    graded: false,
    grade: null,
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
    submittedContent: submittedContent,
    submittedAttachmentJson: submittedAttachmentJson,
    gradeAttachmentJson: null,
  );
}
