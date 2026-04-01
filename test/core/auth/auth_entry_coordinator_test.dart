import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/enums.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/auth/auth_entry_coordinator.dart';
import 'package:learn_y/core/auth/auth_entry_models.dart';
import 'package:learn_y/core/auth/auth_relogin_models.dart';
import 'package:learn_y/core/auth/auth_relogin_service.dart';
import 'package:learn_y/core/auth/auto_relogin_capability_store.dart';
import 'package:learn_y/core/auth/credential_vault.dart';
import 'package:learn_y/core/auth/sso_cookie_bridge.dart';
import 'package:learn_y/core/auth/sso_fallback_page_parser.dart';
import 'package:learn_y/core/auth/sso_session_bootstrapper.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/auth_preferences_provider.dart';

void main() {
  group('AuthEntryCoordinator', () {
    test(
      'successful enrollment marks capability ready and enables preference',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final preferenceNotifier = AutoReloginPreferenceNotifier(
          db,
          initialEnabled: false,
        );
        final statusNotifier = AutoReloginStatusNotifier(db);
        final authReloginService = _FakeAuthReloginService(
          result: const AuthReloginResult.success(),
        );
        final capabilityStore = AutoReloginCapabilityStore(
          preferenceNotifier: preferenceNotifier,
          statusNotifier: statusNotifier,
          authReloginService: authReloginService,
          invalidateStoredCredentialAvailability: () {},
        );

        String? loggedInUser;
        final coordinator = AuthEntryCoordinator(
          sessionBootstrapper: _FakeBootstrapper(username: '静昱鸣'),
          authReloginService: authReloginService,
          autoReloginCapabilityStore: capabilityStore,
          onLoginSuccess: (username) async {
            loggedInUser = username;
          },
        );

        final result = await coordinator.consumeTicket(
          request: AuthEntryRequest.loginAndEnableAutoRelogin(
            input: const AutoReloginSetupInput(
              username: '2024000000',
              password: 'secret',
            ),
          ),
          ticket: 'ST-1',
          enrollmentPayload: const AutoReloginEnrollmentPayload(
            username: '2024000000',
            password: 'secret',
            fingerPrint: 'fp',
            fingerGenPrint: 'trusted-token',
            singleLoginEnabled: true,
          ),
        );

        expect(loggedInUser, '静昱鸣');
        expect(result.autoReloginConfigured, isTrue);
        expect(preferenceNotifier.state, isTrue);
        expect(statusNotifier.state.phase, AutoReloginStatusPhase.ready);
        expect(statusNotifier.state.lastProbeAt, isNotNull);
        expect(authReloginService.capturedFingerGenPrint, 'trusted-token');
        expect(authReloginService.capturedFingerGenPrint3, 'trusted-token');
        expect(authReloginService.capturedSingleLoginEnabled, isTrue);
      },
    );

    test('login still succeeds when enrollment probe fails', () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      final preferenceNotifier = AutoReloginPreferenceNotifier(
        db,
        initialEnabled: false,
      );
      final statusNotifier = AutoReloginStatusNotifier(db);
      final authReloginService = _FakeAuthReloginService(
        result: const AuthReloginResult.failure(
          stage: AuthReloginFailureStage.identityAuthentication,
          reason: FailReason.badCredential,
        ),
      );
      final capabilityStore = AutoReloginCapabilityStore(
        preferenceNotifier: preferenceNotifier,
        statusNotifier: statusNotifier,
        authReloginService: authReloginService,
        invalidateStoredCredentialAvailability: () {},
      );

      String? loggedInUser;
      final coordinator = AuthEntryCoordinator(
        sessionBootstrapper: _FakeBootstrapper(username: '静昱鸣'),
        authReloginService: authReloginService,
        autoReloginCapabilityStore: capabilityStore,
        onLoginSuccess: (username) async {
          loggedInUser = username;
        },
      );

      final result = await coordinator.consumeTicket(
        request: AuthEntryRequest.loginAndEnableAutoRelogin(
          input: const AutoReloginSetupInput(
            username: '2024000000',
            password: 'secret',
          ),
        ),
        ticket: 'ST-1',
        enrollmentPayload: const AutoReloginEnrollmentPayload(
          username: '2024000000',
          password: 'secret',
          fingerPrint: 'fp',
          fingerGenPrint: 'trusted-token',
        ),
      );

      expect(loggedInUser, '静昱鸣');
      expect(result.autoReloginConfigured, isFalse);
      expect(result.noticeMessage, contains('密码不正确'));
      expect(preferenceNotifier.state, isFalse);
      expect(statusNotifier.state.phase, AutoReloginStatusPhase.degraded);
    });

    test(
      'configureAutoReloginForExistingSession upgrades existing session without relogin callback',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final preferenceNotifier = AutoReloginPreferenceNotifier(
          db,
          initialEnabled: false,
        );
        final statusNotifier = AutoReloginStatusNotifier(db);
        final authReloginService = _FakeAuthReloginService(
          result: const AuthReloginResult.success(),
        );
        final capabilityStore = AutoReloginCapabilityStore(
          preferenceNotifier: preferenceNotifier,
          statusNotifier: statusNotifier,
          authReloginService: authReloginService,
          invalidateStoredCredentialAvailability: () {},
        );

        String? loggedInUser;
        final coordinator = AuthEntryCoordinator(
          sessionBootstrapper: _FakeBootstrapper(username: '静昱鸣'),
          authReloginService: authReloginService,
          autoReloginCapabilityStore: capabilityStore,
          onLoginSuccess: (username) async {
            loggedInUser = username;
          },
        );

        final result = await coordinator.configureAutoReloginForExistingSession(
          username: '静昱鸣',
          enrollmentPayload: const AutoReloginEnrollmentPayload(
            username: '2024000000',
            password: 'secret',
            fingerPrint: 'fp',
            fingerGenPrint: 'trusted-token',
            singleLoginEnabled: true,
          ),
        );

        expect(result.username, '静昱鸣');
        expect(result.autoReloginConfigured, isTrue);
        expect(loggedInUser, isNull);
        expect(preferenceNotifier.state, isTrue);
        expect(statusNotifier.state.phase, AutoReloginStatusPhase.ready);
        expect(authReloginService.capturedFingerGenPrint3, 'trusted-token');
      },
    );
  });
}

class _FakeBootstrapper extends SsoSessionBootstrapper {
  _FakeBootstrapper({required this.username})
    : super(Learn2018Helper(), SsoCookieBridge(Learn2018Helper()));

  final String username;

  @override
  Future<String> establishSessionFromTicket(String ticket) async {
    return username;
  }

  @override
  Future<String> establishFallbackSession({
    required SsoFallbackPageSnapshot pageSnapshot,
    required String cookieString,
  }) async {
    return username;
  }
}

class _FakeAuthReloginService extends AuthReloginService {
  _FakeAuthReloginService({required this.result})
    : super(CredentialVault(const _NoopSecureStorage()));

  final AuthReloginResult result;
  String? capturedFingerGenPrint;
  String? capturedFingerGenPrint3;
  bool? capturedSingleLoginEnabled;

  @override
  Future<AuthReloginResult> saveEnrolledCredential({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
    bool singleLoginEnabled = false,
  }) async {
    capturedFingerGenPrint = fingerGenPrint;
    capturedFingerGenPrint3 = fingerGenPrint3;
    capturedSingleLoginEnabled = singleLoginEnabled;
    return result;
  }

  @override
  Future<void> clearStoredCredential() async {}
}

class _NoopSecureStorage implements FlutterSecureStorage {
  const _NoopSecureStorage();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
