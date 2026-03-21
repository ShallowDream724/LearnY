import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/providers/providers.dart';

final notificationDetailProvider =
    StreamProvider.family<db.Notification?, String>((ref, notificationId) {
      final database = ref.watch(databaseProvider);
      return database.watchNotificationById(notificationId);
    });
