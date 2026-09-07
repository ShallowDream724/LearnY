import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_state_keys.dart';
import '../core/database/database.dart';
import '../core/files/file_repository.dart';
import '../core/providers/providers.dart';
import '../core/semester/semester_repository.dart';
import '../core/services/file_storage_workspace_service.dart';
import '../core/sync/sync_engine.dart';
import 'demo_api.dart';
import 'demo_data.dart';
import 'demo_secure_storage.dart';

class DemoEnvironment {
  DemoEnvironment._(
    this.database,
    this.cookieJar,
    this.api,
    this.documentsDirectory,
    this.workspace,
    this.selectedSemesterId,
  );

  final AppDatabase database;
  final CookieJar cookieJar;
  final DemoLearnApi api;
  final Directory documentsDirectory;
  final FileStorageWorkspaceService workspace;
  final String selectedSemesterId;
  final secureStorage = DemoSecureStorage();
  bool _disposed = false;

  static Future<DemoEnvironment> create({
    DateTime? now,
    DemoNetwork network = DemoNetwork.normal,
    bool selectPreviousSemester = false,
  }) async {
    final data = DemoData(now: now);
    final database = AppDatabase(NativeDatabase.memory());
    final cookieJar = CookieJar();
    final api = DemoLearnApi(data, cookieJar: cookieJar);
    final documentsDirectory = await Directory.systemTemp.createTemp(
      'learny-demo-',
    );
    final workspace = FileStorageWorkspaceService(
      database: database,
      getDocumentsDirectory: () async => documentsDirectory,
    );
    final selectedSemesterId = selectPreviousSemester
        ? data.semesters[1].id
        : data.officialSemesterId;
    final environment = DemoEnvironment._(
      database,
      cookieJar,
      api,
      documentsDirectory,
      workspace,
      selectedSemesterId,
    );
    try {
      await workspace.prepare();
      final semesters = SemesterRepository(apiClient: api, database: database);
      await semesters.refreshCatalog();
      // Keep historic metadata complete while preserving the official current ID.
      for (final semester in data.semesters) {
        await database.upsertSemester(
          SemestersCompanion.insert(
            id: semester.id,
            startDate: semester.startDate,
            endDate: semester.endDate,
            startYear: semester.startYear,
            endYear: semester.endYear,
            type: semester.type.value,
          ),
        );
      }
      final engine = SyncEngine(
        apiClient: api,
        database: database,
        fileRepository: DriftFileRepository(database),
        semesterRepository: semesters,
      );
      for (final semester in data.semesters) {
        await engine.syncAll(semester.id);
      }
      await semesters.saveSelection(selectedSemesterId);
      await database.setState(AppStateKeys.username, DemoData.username);
      await database.setState(
        AppStateKeys.learningDataOwner,
        DemoData.username,
      );
      await database.setState(AppStateKeys.userDepartment, '计算机科学与技术系');
      await database.setState(AppStateKeys.autoReloginEnabled, 'false');
      api.network = network;
      return environment;
    } catch (_) {
      await environment.dispose();
      rethrow;
    }
  }

  List<Override> get overrides => [
    databaseProvider.overrideWithValue(database),
    cookieJarProvider.overrideWithValue(cookieJar),
    secureStorageProvider.overrideWithValue(secureStorage),
    apiClientProvider.overrideWithValue(api),
    fileStorageWorkspaceServiceProvider.overrideWithValue(workspace),
    initialAuthUsernameProvider.overrideWithValue(DemoData.username),
    initialCurrentSemesterIdProvider.overrideWithValue(selectedSemesterId),
    didBootstrapAppSessionProvider.overrideWithValue(true),
    initialAutoReloginEnabledProvider.overrideWithValue(false),
    authProvider.overrideWith(
      (ref) =>
          _DemoAuthController(ref, ref.watch(authSessionRepositoryProvider)),
    ),
    authReloginServiceProvider.overrideWith(
      (ref) => AuthReloginService(
        ref.watch(credentialVaultProvider),
        helperFactory: () => api,
      ),
    ),
    appBuildInfoProvider.overrideWith(
      (ref) async => const AppBuildInfo(
        version: '0.1.3',
        buildNumber: 'demo',
        packageName: 'learny.demo',
      ),
    ),
    appUpdateInfoProvider.overrideWith(
      (ref) async => AppUpdateInfo(
        currentBuild: await ref.watch(appBuildInfoProvider.future),
        checkedAt: api.data.now,
        availability: AppUpdateAvailability.noRelease,
      ),
    ),
  ];

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    api.dio.close(force: true);
    await database.close();
    await secureStorage.deleteAll();
    await cookieJar.deleteAll();
    if (await documentsDirectory.exists()) {
      await documentsDirectory.delete(recursive: true);
    }
  }
}

/// Demo identity never opens the native SSO WebView, including after logout.
class _DemoAuthController extends AuthController {
  _DemoAuthController(super.ref, super.repository) {
    markSessionHealthy();
  }

  @override
  Future<void> logout() async => markSessionHealthy(DemoData.username);

  @override
  void markSessionExpired([String? message]) =>
      markSessionHealthy(DemoData.username);

  @override
  Future<void> onLoginSuccess(String username) async =>
      markSessionHealthy(DemoData.username);
}
