import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth.dart';
import '../database/app_state_keys.dart';
import '../database/database.dart';
import 'app_providers.dart';

class HomeworkReminderStateStore {
  const HomeworkReminderStateStore(this._db);

  final AppDatabase _db;

  static String buildScopeKey({
    required String owner,
    required String semesterId,
  }) {
    final normalizedOwner = owner.trim().toLowerCase();
    final resolvedOwner = normalizedOwner.isEmpty ? 'anonymous' : normalizedOwner;
    return '${AppStateKeys.homeworkNoSubmissionNeededPrefix}'
        '::$resolvedOwner::$semesterId';
  }

  Stream<Set<String>> watchNoSubmissionNeededIds({required String scopeKey}) {
    return _db.watchState(scopeKey).map(_decodeIds);
  }

  Future<Set<String>> readNoSubmissionNeededIds({required String scopeKey}) async {
    return _decodeIds(await _db.getState(scopeKey));
  }

  Future<void> setNoSubmissionNeeded({
    required String scopeKey,
    required String homeworkId,
    required bool noSubmissionNeeded,
  }) async {
    final ids = await readNoSubmissionNeededIds(scopeKey: scopeKey);
    final next = {...ids};
    if (noSubmissionNeeded) {
      next.add(homeworkId);
    } else {
      next.remove(homeworkId);
    }

    if (next.isEmpty) {
      await _db.deleteState(scopeKey);
      return;
    }

    final encoded = jsonEncode(next.toList()..sort());
    await _db.setState(scopeKey, encoded);
  }

  Set<String> _decodeIds(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <String>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return const <String>{};
      }
      return decoded
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return const <String>{};
    }
  }
}

final homeworkReminderStateStoreProvider =
    Provider<HomeworkReminderStateStore>((ref) {
      return HomeworkReminderStateStore(ref.watch(databaseProvider));
    });

final learningDataOwnerProvider = StreamProvider<String?>((ref) {
  return ref.watch(databaseProvider).watchState(AppStateKeys.learningDataOwner);
});

final homeworkReminderScopeKeyProvider = Provider<String?>((ref) {
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null || semesterId.isEmpty) {
    return null;
  }

  final owner =
      ref.watch(authProvider).username ??
      ref.watch(learningDataOwnerProvider).valueOrNull ??
      '';
  return HomeworkReminderStateStore.buildScopeKey(
    owner: owner,
    semesterId: semesterId,
  );
});

final homeworkNoSubmissionNeededIdsProvider = StreamProvider<Set<String>>((ref) {
  final scopeKey = ref.watch(homeworkReminderScopeKeyProvider);
  if (scopeKey == null) {
    return Stream.value(const <String>{});
  }

  return ref
      .watch(homeworkReminderStateStoreProvider)
      .watchNoSubmissionNeededIds(scopeKey: scopeKey);
});

class HomeworkReminderActions {
  HomeworkReminderActions(this._ref);

  final Ref _ref;

  Future<void> setNoSubmissionNeeded(
    String homeworkId, {
    required bool noSubmissionNeeded,
  }) async {
    final scopeKey = _ref.read(homeworkReminderScopeKeyProvider);
    if (scopeKey == null || scopeKey.isEmpty) {
      return;
    }

    await _ref
        .read(homeworkReminderStateStoreProvider)
        .setNoSubmissionNeeded(
          scopeKey: scopeKey,
          homeworkId: homeworkId,
          noSubmissionNeeded: noSubmissionNeeded,
        );
  }
}

final homeworkReminderActionsProvider = Provider<HomeworkReminderActions>((ref) {
  return HomeworkReminderActions(ref);
});
