import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/database.dart';
import '../files/file_repository.dart';
import 'app_providers.dart';

final learningDataActionsProvider = Provider<LearningDataActions>((ref) {
  return LearningDataActions(ref);
});

class LearningDataActions {
  LearningDataActions(this._ref);

  final Ref _ref;

  AppDatabase get _database => _ref.read(databaseProvider);
  FileRepository get _fileRepository => _ref.read(fileRepositoryProvider);

  Future<void> markNotificationRead(String notificationId) async {
    await _database.markNotificationReadLocal(notificationId);
  }

  Future<void> markFileRead(String fileId) async {
    await _fileRepository.markRead(fileId);
  }

  Future<void> markFileUnread(String fileId) async {
    await _fileRepository.markUnread(fileId);
  }

  Future<void> setFileReadState(String fileId, {required bool isRead}) async {
    await _fileRepository.setReadState(fileId, isRead: isRead);
  }
}
