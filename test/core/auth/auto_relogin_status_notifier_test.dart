import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/auth_relogin_models.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/auth_preferences_provider.dart';

void main() {
  group('AutoReloginStatusNotifier', () {
    test(
      'preserves verified snapshot when recovery success races initial load',
      () async {
        final db = _DelayedAppDatabase();
        addTearDown(db.close);

        final verifiedAt = DateTime(2026, 3, 28, 20, 49);
        await db.setState(
          AppStateKeys.autoReloginStatus,
          AutoReloginStatusSnapshot.disabled()
              .markVerified(verifiedAt)
              .toJsonString(),
        );

        final notifier = AutoReloginStatusNotifier(db);
        await notifier.recordRecoverySuccess(SessionRecoveryMethod.ssoCookie);

        expect(notifier.state.phase, AutoReloginStatusPhase.verified);
        expect(notifier.state.lastVerifiedAt, verifiedAt);
        expect(
          notifier.state.lastRecoveryMethod,
          SessionRecoveryMethod.ssoCookie,
        );
        expect(notifier.state.lastRecoveryAt, isNotNull);
      },
    );
  });
}

class _DelayedAppDatabase extends AppDatabase {
  _DelayedAppDatabase() : super(NativeDatabase.memory());

  Future<String?> getState(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final row = await (select(
      appState,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
