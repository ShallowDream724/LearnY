import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/enums.dart';
import '../../../core/providers/providers.dart';

class NotificationActions {
  const NotificationActions(this._ref);

  final Ref _ref;

  Future<void> markRead(String notificationId) {
    return _ref
        .read(learningDataActionsProvider)
        .markNotificationRead(notificationId);
  }

  Future<void> setFavorite({
    required String notificationId,
    required bool isFavorite,
  }) async {
    final api = _ref.read(apiClientProvider);
    if (isFavorite) {
      await api.addToFavorites(ContentType.notification, notificationId);
      return;
    }

    await api.removeFromFavorites(notificationId);
  }
}

final notificationActionsProvider = Provider<NotificationActions>((ref) {
  return NotificationActions(ref);
});
