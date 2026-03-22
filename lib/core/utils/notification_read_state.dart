import '../database/database.dart' as db;

extension NotificationReadStateX on db.Notification {
  bool get isEffectivelyRead => hasRead != hasReadLocal;
  bool get isEffectivelyUnread => !isEffectivelyRead;
}
