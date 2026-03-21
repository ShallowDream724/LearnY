import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'homework_submission_models.dart';
import 'homework_submission_repository.dart';

class HomeworkSubmissionController
    extends StateNotifier<HomeworkSubmissionState> {
  HomeworkSubmissionController({
    required HomeworkSubmissionSeed seed,
    required HomeworkSubmissionCoordinator coordinator,
  }) : _coordinator = coordinator,
       super(HomeworkSubmissionState.initial(seed));

  final HomeworkSubmissionCoordinator _coordinator;

  void updateContent(String content) {
    if (content == state.content &&
        state.status != HomeworkSubmissionStatus.failure) {
      return;
    }
    state = _idleState().copyWith(content: content);
  }

  void selectAttachment(HomeworkSubmissionAttachment attachment) {
    state = _idleState().copyWith(
      attachment: attachment,
      removeExistingAttachment: state.seed.hasExistingAttachment,
    );
  }

  void removeAttachment() {
    state = _idleState().copyWith(
      attachment: null,
      removeExistingAttachment: state.seed.hasExistingAttachment,
    );
  }

  Future<bool> submit() async {
    if (state.isSubmitting) {
      return false;
    }

    state = state.copyWith(
      status: HomeworkSubmissionStatus.submitting,
      errorMessage: null,
    );

    try {
      await _coordinator.submit(state.toRequest());
      state = state.copyWith(
        status: HomeworkSubmissionStatus.success,
        errorMessage: null,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        status: HomeworkSubmissionStatus.failure,
        errorMessage: '提交失败: $error',
      );
      return false;
    }
  }

  void clearError() {
    if (state.status != HomeworkSubmissionStatus.failure &&
        state.errorMessage == null) {
      return;
    }
    state = _idleState();
  }

  HomeworkSubmissionState _idleState() {
    final shouldResetStatus = state.status == HomeworkSubmissionStatus.failure;
    if (!shouldResetStatus && state.errorMessage == null) {
      return state;
    }
    return state.copyWith(
      status: HomeworkSubmissionStatus.idle,
      errorMessage: null,
    );
  }
}

final homeworkSubmissionControllerProvider = StateNotifierProvider.autoDispose
    .family<
      HomeworkSubmissionController,
      HomeworkSubmissionState,
      HomeworkSubmissionSeed
    >((ref, seed) {
      return HomeworkSubmissionController(
        seed: seed,
        coordinator: ref.watch(homeworkSubmissionCoordinatorProvider),
      );
    });
