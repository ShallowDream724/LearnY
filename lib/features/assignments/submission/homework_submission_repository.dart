import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/providers/sync_provider.dart';
import 'homework_submission_models.dart';

abstract class HomeworkSubmissionRepository {
  Future<void> submit(HomeworkSubmissionRequest request);
}

class ApiHomeworkSubmissionRepository implements HomeworkSubmissionRepository {
  const ApiHomeworkSubmissionRepository(this._ref);

  final Ref _ref;

  @override
  Future<void> submit(HomeworkSubmissionRequest request) async {
    final api = _ref.read(apiClientProvider);
    await api.submitHomework(
      request.homeworkId,
      content: request.content,
      attachmentPath: request.attachmentPath,
      attachmentName: request.attachmentName,
      removeAttachment: request.removeAttachment,
    );
  }
}

class HomeworkSubmissionCoordinator {
  const HomeworkSubmissionCoordinator({
    required HomeworkSubmissionRepository repository,
    required Future<void> Function() refreshHomeworks,
  }) : _repository = repository,
       _refreshHomeworks = refreshHomeworks;

  final HomeworkSubmissionRepository _repository;
  final Future<void> Function() _refreshHomeworks;

  Future<void> submit(HomeworkSubmissionRequest request) async {
    await _repository.submit(request);
    unawaited(_refreshHomeworks());
  }
}

final homeworkSubmissionRepositoryProvider =
    Provider<HomeworkSubmissionRepository>((ref) {
      return ApiHomeworkSubmissionRepository(ref);
    });

final homeworkSubmissionCoordinatorProvider =
    Provider<HomeworkSubmissionCoordinator>((ref) {
      return HomeworkSubmissionCoordinator(
        repository: ref.watch(homeworkSubmissionRepositoryProvider),
        refreshHomeworks: ref
            .read(syncStateProvider.notifier)
            .syncHomeworksOnly,
      );
    });
