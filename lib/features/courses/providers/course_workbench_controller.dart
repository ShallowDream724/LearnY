import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'course_workbench_models.dart';
import 'course_workbench_repository.dart';

class CourseWorkbenchController extends StateNotifier<CourseWorkbenchState> {
  CourseWorkbenchController(this._ref) : super(const CourseWorkbenchState());

  final Ref _ref;

  void beginEditing(List<ResolvedCourseCardModel> cards) {
    state = CourseWorkbenchState(
      isEditing: true,
      baselineCards: List<ResolvedCourseCardModel>.unmodifiable(cards),
      draftCards: List<ResolvedCourseCardModel>.from(cards),
    );
  }

  Future<bool> cancelEditing({required bool force}) async {
    if (!state.isEditing) {
      return true;
    }
    if (!force && state.hasChanges) {
      return false;
    }
    state = const CourseWorkbenchState();
    return true;
  }

  void startDragging(String courseId) {
    if (!state.isEditing) {
      return;
    }
    state = state.copyWith(
      draggingCourseId: courseId,
      clearHoverCourseId: true,
      clearHoverInsertIndex: true,
    );
  }

  void stopDragging() {
    if (!state.isEditing) {
      return;
    }
    state = state.copyWith(
      clearDraggingCourseId: true,
      clearHoverCourseId: true,
      clearHoverInsertIndex: true,
    );
  }

  void completeDragging() {
    stopDragging();
  }

  void previewReorder({
    required String draggedCourseId,
    required String targetCourseId,
    required int insertIndex,
  }) {
    if (!state.isEditing || draggedCourseId == targetCourseId) {
      return;
    }
    if (state.hoverCourseId == targetCourseId &&
        state.hoverInsertIndex == insertIndex) {
      return;
    }
    final items = List<ResolvedCourseCardModel>.from(state.draftCards);
    final draggedIndex = items.indexWhere(
      (item) => item.course.id == draggedCourseId,
    );
    final targetIndex = items.indexWhere(
      (item) => item.course.id == targetCourseId,
    );
    if (draggedIndex == -1 ||
        targetIndex == -1 ||
        insertIndex < 0 ||
        insertIndex > items.length) {
      return;
    }

    var normalizedInsertIndex = insertIndex;
    if (draggedIndex < normalizedInsertIndex) {
      normalizedInsertIndex -= 1;
    }
    if (normalizedInsertIndex == draggedIndex) {
      state = state.copyWith(
        hoverCourseId: targetCourseId,
        hoverInsertIndex: insertIndex,
      );
      return;
    }

    final dragged = items.removeAt(draggedIndex);
    items.insert(normalizedInsertIndex, dragged);
    state = state.copyWith(
      draftCards: items,
      hoverCourseId: targetCourseId,
      hoverInsertIndex: insertIndex,
    );
  }

  void updateAlias(String courseId, String? alias) {
    _updateDraft(courseId, (item) {
      final normalized = alias?.trim();
      return item.copyWith(
        alias: normalized,
        clearAlias: normalized == null || normalized.isEmpty,
      );
    });
  }

  void updateIcon(String courseId, String? iconKey) {
    _updateDraft(courseId, (item) {
      final normalized = iconKey?.trim();
      return item.copyWith(
        iconKey: normalized,
        clearIconKey: normalized == null || normalized.isEmpty,
      );
    });
  }

  void restoreCourseCustomization(String courseId) {
    _updateDraft(
      courseId,
      (item) => item.copyWith(
        clearAlias: true,
        clearIconKey: true,
        clearAccentKey: true,
      ),
    );
  }

  void restoreDefaultOrder() {
    if (!state.isEditing) {
      return;
    }
    final restored = [...state.draftCards]
      ..sort((a, b) => a.defaultSortOrder.compareTo(b.defaultSortOrder));
    state = state.copyWith(
      draftCards: restored,
      clearDraggingCourseId: true,
      clearHoverCourseId: true,
      clearHoverInsertIndex: true,
    );
  }

  Future<bool> save() async {
    if (!state.isEditing) {
      return true;
    }
    final scope = _ref.read(courseWorkbenchScopeProvider);
    if (scope == null) {
      return false;
    }
    await _ref
        .read(courseDisplayPrefsRepositoryProvider)
        .saveScope(scope: scope, cards: state.draftCards);
    state = const CourseWorkbenchState();
    return true;
  }

  void _updateDraft(
    String courseId,
    ResolvedCourseCardModel Function(ResolvedCourseCardModel item) transform,
  ) {
    if (!state.isEditing) {
      return;
    }
    final items = [
      for (final item in state.draftCards)
        if (item.course.id == courseId) transform(item) else item,
    ];
    state = state.copyWith(draftCards: items);
  }
}

final courseWorkbenchControllerProvider =
    StateNotifierProvider<CourseWorkbenchController, CourseWorkbenchState>((
      ref,
    ) {
      return CourseWorkbenchController(ref);
    });
