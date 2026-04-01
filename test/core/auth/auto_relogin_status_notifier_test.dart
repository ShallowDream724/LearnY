import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/auth_relogin_models.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/auth_preferences_provider.dart';

void main() {
  group('AutoReloginStatusNotifier', () {
    test(
      'preserves ready snapshot when recovery success races initial load',
      () async {
        final db = _DelayedAppDatabase();
        addTearDown(db.close);

        final probeAt = DateTime(2026, 3, 28, 20, 49);
        await db.setState(
          AppStateKeys.autoReloginStatus,
          AutoReloginStatusSnapshot.disabled()
              .markEnrollmentSuccess(
                probeMethod: AutoReloginProbeMethod.secureCredential,
                at: probeAt,
                trustedBrowserReady: true,
              )
              .toJsonString(),
        );

        final notifier = AutoReloginStatusNotifier(db);
        await notifier.recordRecoverySuccess(SessionRecoveryMethod.ssoCookie);

        expect(notifier.state.phase, AutoReloginStatusPhase.ready);
        expect(notifier.state.lastProbeAt, probeAt.toUtc());
        expect(
          notifier.state.lastRecoveryMethod,
          SessionRecoveryMethod.ssoCookie,
        );
        expect(notifier.state.lastRecoveryAt, isNotNull);
      },
    );

    test('migrates legacy verified snapshot into ready + probe timestamp', () {
      final legacyRaw = jsonEncode(<String, dynamic>{
        'phase': 'verified',
        'lastVerifiedAt': '2026-03-28T20:49:00.000',
      });

      final snapshot = AutoReloginStatusSnapshot.fromJsonString(legacyRaw);

      expect(snapshot.phase, AutoReloginStatusPhase.ready);
      expect(snapshot.lastProbeAt, DateTime.parse('2026-03-28T20:49:00.000'));
      expect(snapshot.lastProbeMethod, AutoReloginProbeMethod.secureCredential);
    });

    test('persists new status timestamps as utc instants', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final notifier = AutoReloginStatusNotifier(db);

      await notifier.recordEnrollmentSuccess(
        probeMethod: AutoReloginProbeMethod.secureCredential,
        trustedBrowserReady: true,
      );

      final storedRaw = await db.getState(AppStateKeys.autoReloginStatus);
      expect(storedRaw, isNotNull);

      final storedJson = jsonDecode(storedRaw!) as Map<String, dynamic>;
      expect(storedJson['lastConfiguredAt'], endsWith('Z'));
      expect(storedJson['lastProbeAt'], endsWith('Z'));
    });
  });
}

class _DelayedAppDatabase extends AppDatabase {
  _DelayedAppDatabase() : super(NativeDatabase.memory());

  @override
  Future<String?> getState(String key) async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final row = await (select(
      appState,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }
}
