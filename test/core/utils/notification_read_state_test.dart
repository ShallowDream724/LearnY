import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/utils/notification_read_state.dart';

void main() {
  group('NotificationReadStateX', () {
    test('treats server unread + local false as unread', () {
      final notification = _notification(hasRead: false, hasReadLocal: false);
      expect(notification.isEffectivelyUnread, isTrue);
      expect(notification.isEffectivelyRead, isFalse);
    });

    test('treats server read + local true as manually unread', () {
      final notification = _notification(hasRead: true, hasReadLocal: true);
      expect(notification.isEffectivelyUnread, isTrue);
      expect(notification.isEffectivelyRead, isFalse);
    });

    test('treats differing flags as read', () {
      expect(
        _notification(hasRead: false, hasReadLocal: true).isEffectivelyRead,
        isTrue,
      );
      expect(
        _notification(hasRead: true, hasReadLocal: false).isEffectivelyRead,
        isTrue,
      );
    });
  });
}

db.Notification _notification({
  required bool hasRead,
  required bool hasReadLocal,
}) {
  return db.Notification(
    id: 'notification-1',
    courseId: 'course-1',
    title: '通知',
    content: '',
    publisher: '',
    publishTime: '2026-03-22T12:00:00.000',
    expireTime: null,
    hasRead: hasRead,
    hasReadLocal: hasReadLocal,
    markedImportant: false,
    isFavorite: false,
    comment: null,
    attachmentJson: null,
  );
}
