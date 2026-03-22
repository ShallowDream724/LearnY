import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/auth/auth_relogin_service.dart';
import 'package:learn_y/core/auth/credential_vault.dart';
import 'package:learn_y/core/auth/session_recovery_coordinator.dart';
import 'package:learn_y/core/auth/sso_session_recovery_service.dart';

void main() {
  group('SessionRecoveryCoordinator', () {
    test('prefers SSO cookie recovery before secure credential relogin', () async {
      final coordinator = SessionRecoveryCoordinator(
        ssoRecoveryService: _FakeSsoRecoveryService(result: true),
        authReloginService: _FakeAuthReloginService(result: true),
        isAutoReloginEnabled: () => true,
      );

      final result = await coordinator.recoverSession(
        apiClient: Learn2018Helper(),
      );

      expect(result.recovered, isTrue);
      expect(result.method, SessionRecoveryMethod.ssoCookie);
    });

    test('uses secure credential relogin when SSO recovery fails', () async {
      final coordinator = SessionRecoveryCoordinator(
        ssoRecoveryService: _FakeSsoRecoveryService(result: false),
        authReloginService: _FakeAuthReloginService(result: true),
        isAutoReloginEnabled: () => true,
      );

      final result = await coordinator.recoverSession(
        apiClient: Learn2018Helper(),
      );

      expect(result.recovered, isTrue);
      expect(result.method, SessionRecoveryMethod.secureCredential);
    });

    test('does not attempt secure credential relogin when disabled', () async {
      final authReloginService = _FakeAuthReloginService(result: true);
      final coordinator = SessionRecoveryCoordinator(
        ssoRecoveryService: _FakeSsoRecoveryService(result: false),
        authReloginService: authReloginService,
        isAutoReloginEnabled: () => false,
      );

      final result = await coordinator.recoverSession(
        apiClient: Learn2018Helper(),
      );

      expect(result.recovered, isFalse);
      expect(authReloginService.tryReloginCalls, 0);
    });
  });
}

class _FakeSsoRecoveryService extends SsoSessionRecoveryService {
  const _FakeSsoRecoveryService({required this.result});

  final bool result;

  @override
  Future<bool> tryRecover(Learn2018Helper apiClient) async {
    return result;
  }
}

class _FakeAuthReloginService extends AuthReloginService {
  _FakeAuthReloginService({required this.result})
    : super(
        _NoopCredentialVault(),
      );

  final bool result;
  int tryReloginCalls = 0;

  @override
  Future<bool> tryRelogin(Learn2018Helper apiClient) async {
    tryReloginCalls++;
    return result;
  }
}

class _NoopCredentialVault extends CredentialVault {
  _NoopCredentialVault() : super(const _NoopSecureStorage());
}

class _NoopSecureStorage implements FlutterSecureStorage {
  const _NoopSecureStorage();

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
