import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_state_keys.dart';
import '../database/database.dart';
import 'app_providers.dart';

class AutoReloginPreferenceNotifier extends StateNotifier<bool> {
  AutoReloginPreferenceNotifier(this._db, {required bool initialEnabled})
    : super(initialEnabled);

  final AppDatabase _db;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    if (enabled) {
      await _db.setState(AppStateKeys.autoReloginEnabled, 'true');
      return;
    }
    await _db.deleteState(AppStateKeys.autoReloginEnabled);
  }
}

final autoReloginEnabledProvider =
    StateNotifierProvider<AutoReloginPreferenceNotifier, bool>((ref) {
      return AutoReloginPreferenceNotifier(
        ref.watch(databaseProvider),
        initialEnabled: ref.watch(initialAutoReloginEnabledProvider),
      );
    });
