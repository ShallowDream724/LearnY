import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';

class NotificationActions {
  const NotificationActions(this._ref);

  final Ref _ref;

  Future<void> markRead(String notificationId) {
    return _ref
        .read(learningDataActionsProvider)
        .markNotificationRead(notificationId);
  }

  Future<void> markUnread(String notificationId) {
    return _ref
        .read(learningDataActionsProvider)
        .markNotificationUnread(notificationId);
  }

  Future<void> setReadState({
    required String notificationId,
    required bool isRead,
  }) async {
    if (isRead) {
      await markRead(notificationId);
      return;
    }
    await markUnread(notificationId);
  }
}

final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});
