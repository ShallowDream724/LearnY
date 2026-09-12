import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/database/app_state_keys.dart';
import 'core/database/connection.dart';
import 'core/database/database.dart';
import 'core/providers/providers.dart';
import 'core/services/file_storage_workspace_service.dart';
import 'core/semester/academic_calendar_catalog.dart';
import 'core/semester/academic_calendar.dart';
import 'core/semester/bundled_academic_calendar_source.dart';
import 'core/semester/semester_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize PersistCookieJar — cookies survive app restarts.
  // This is Layer 1 of our three-layer session defense.
  final appDir = await getApplicationSupportDirectory();
  final cookieJar = PersistCookieJar(
    storage: FileStorage('${appDir.path}/cookies/'),
  );
  final bootstrap = await _resolveBootstrapState();
  var calendar = const AcademicCalendar();
  try {
    calendar = (await BundledAcademicCalendarSource().load()).forAudience(
      CalendarAudience.undergraduate,
    );
  } catch (error) {
    // A bad optional calendar must not prevent login or absolute-date browsing.
    debugPrint('[LearnY] Teaching calendar unavailable: $error');
  }

  runApp(
    ProviderScope(
      overrides: [
        academicCalendarProvider.overrideWithValue(calendar),
        cookieJarProvider.overrideWithValue(cookieJar),
        initialAuthUsernameProvider.overrideWithValue(
          bootstrap.initialAuthUsername,
        ),
        initialCurrentSemesterIdProvider.overrideWithValue(
          bootstrap.initialCurrentSemesterId,
        ),
        didBootstrapAppSessionProvider.overrideWithValue(true),
        initialAutoReloginEnabledProvider.overrideWithValue(
          bootstrap.initialAutoReloginEnabled,
        ),
      ],
      child: const LearnYApp(),
    ),
  );
}

class _BootstrapState {
  const _BootstrapState({
    required this.initialAuthUsername,
    required this.initialCurrentSemesterId,
    required this.initialAutoReloginEnabled,
  });

  final String? initialAuthUsername;
  final String? initialCurrentSemesterId;
  final bool initialAutoReloginEnabled;
}

Future<_BootstrapState> _resolveBootstrapState() async {
  final db = createDatabase();
  try {
    try {
      await FileStorageWorkspaceService(database: db).prepare();
    } catch (error) {
      debugPrint('[LearnY] File storage workspace prepare failed: $error');
    }

    final persistedUsername = await db.getState(AppStateKeys.username);
    final persistedSemesterId = await db.getState(
      AppStateKeys.currentSemesterId,
    );
    final persistedAutoRelogin = await db.getState(
      AppStateKeys.autoReloginEnabled,
    );

    String? initialCurrentSemesterId;
    if (persistedSemesterId != null && persistedSemesterId.trim().isNotEmpty) {
      initialCurrentSemesterId = persistedSemesterId;
    } else {
      final mostRecentSemester = await db.getMostRecentSemester();
      initialCurrentSemesterId = mostRecentSemester?.id;
    }

    return _BootstrapState(
      initialAuthUsername: _normalizeBootstrapStateValue(persistedUsername),
      initialCurrentSemesterId: initialCurrentSemesterId,
      initialAutoReloginEnabled: persistedAutoRelogin == 'true',
    );
  } finally {
    await db.close();
  }
}

String? _normalizeBootstrapStateValue(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}
