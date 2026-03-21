import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_state_keys.dart';
import '../database/database.dart';
import 'app_providers.dart';

// ---------------------------------------------------------------------------
// Theme mode
// ---------------------------------------------------------------------------

/// User's theme preference: system, light, or dark.
class ThemeModeNotifier extends StateNotifier<String> {
  final AppDatabase _db;

  ThemeModeNotifier(this._db) : super('system') {
    _load();
  }

  Future<void> _load() async {
    final saved = await _db.getState(AppStateKeys.themeMode);
    if (saved != null &&
        (saved == 'light' || saved == 'dark' || saved == 'system')) {
      state = saved;
    }
  }

  Future<void> setTheme(String mode) async {
    state = mode;
    await _db.setState(AppStateKeys.themeMode, mode);
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, String>((
  ref,
) {
  return ThemeModeNotifier(ref.watch(databaseProvider));
});

// ---------------------------------------------------------------------------
// Deadline threshold
// ---------------------------------------------------------------------------

/// How many hours ahead to show in the urgent deadline banner.
class DeadlineThresholdNotifier extends StateNotifier<int> {
  final AppDatabase _db;

  DeadlineThresholdNotifier(this._db) : super(168) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _db.getState(AppStateKeys.deadlineThresholdHours);
    if (saved == null) return;

    final value = int.tryParse(saved);
    if (value != null && value > 0) {
      state = value;
    }
  }

  Future<void> setHours(int hours) async {
    if (hours <= 0) return;
    state = hours;
    await _db.setState(AppStateKeys.deadlineThresholdHours, hours.toString());
  }
}

final deadlineThresholdHoursProvider =
    StateNotifierProvider<DeadlineThresholdNotifier, int>((ref) {
      return DeadlineThresholdNotifier(ref.watch(databaseProvider));
    });

// ---------------------------------------------------------------------------
// File cache limit
// ---------------------------------------------------------------------------

/// Maximum cache size in megabytes. `null` means unlimited.
class FileCacheLimitNotifier extends StateNotifier<int?> {
  final AppDatabase _db;

  FileCacheLimitNotifier(this._db) : super(null) {
    _load();
  }

  Future<void> _load() async {
    final saved = await _db.getState(AppStateKeys.fileCacheLimitMb);
    if (saved == null || saved.isEmpty) {
      return;
    }

    final value = int.tryParse(saved);
    if (value == null || value <= 0) {
      state = null;
      return;
    }

    state = value;
  }

  Future<void> setLimitMb(int? limitMb) async {
    state = limitMb != null && limitMb > 0 ? limitMb : null;
    if (state == null) {
      await _db.deleteState(AppStateKeys.fileCacheLimitMb);
      return;
    }

    await _db.setState(AppStateKeys.fileCacheLimitMb, state!.toString());
  }
}

final fileCacheLimitMbProvider =
    StateNotifierProvider<FileCacheLimitNotifier, int?>((ref) {
      return FileCacheLimitNotifier(ref.watch(databaseProvider));
    });

final fileCacheLimitBytesProvider = Provider<int?>((ref) {
  final limitMb = ref.watch(fileCacheLimitMbProvider);
  if (limitMb == null || limitMb <= 0) {
    return null;
  }
  return limitMb * 1024 * 1024;
});
