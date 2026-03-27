import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/auth/auth_relogin_service.dart';
import 'package:learn_y/core/auth/credential_vault.dart';

void main() {
  group('AuthReloginService', () {
    test(
      'saveVerifiedCredential verifies and persists exact fingerprint fields',
      () async {
        final storage = _MemorySecureStorage();
        final vault = CredentialVault(storage);
        final helper = _RecordingLearnHelper();
        final service = AuthReloginService(vault, helperFactory: () => helper);

        await service.saveVerifiedCredential(
          username: '2024000000',
          password: 'secret',
          fingerPrint: 'fp',
          fingerGenPrint: '',
          fingerGenPrint3: 'fg3',
          deviceName: 'Android,LearnY',
        );

        expect(helper.calls, hasLength(1));
        expect(helper.calls.single.username, '2024000000');
        expect(helper.calls.single.password, 'secret');
        expect(helper.calls.single.fingerPrint, 'fp');
        expect(helper.calls.single.fingerGenPrint, '');
        expect(helper.calls.single.fingerGenPrint3, 'fg3');

        final saved = await vault.read();
        expect(saved, isNotNull);
        expect(saved!.fingerGenPrint, '');
        expect(saved.fingerGenPrint3, 'fg3');
        expect(saved.singleLoginEnabled, isFalse);
      },
    );

    test(
      'saveEnrolledCredential persists trusted-browser state without verify',
      () async {
        final storage = _MemorySecureStorage();
        final vault = CredentialVault(storage);
        final helper = _RecordingLearnHelper();
        final service = AuthReloginService(vault, helperFactory: () => helper);

        await service.saveEnrolledCredential(
          username: '2024000000',
          password: 'secret',
          fingerPrint: 'fp',
          fingerGenPrint: 'trusted-token',
          fingerGenPrint3: '',
          deviceName: 'Android,LearnY',
          singleLoginEnabled: true,
        );

        expect(helper.calls, isEmpty);

        final saved = await vault.read();
        expect(saved, isNotNull);
        expect(saved!.fingerGenPrint, 'trusted-token');
        expect(saved.singleLoginEnabled, isTrue);
      },
    );

    test('tryRelogin forwards trusted-browser singleLogin flag', () async {
      final storage = _MemorySecureStorage();
      final vault = CredentialVault(storage);
      final apiClient = _RecordingLearnHelper();
      final service = AuthReloginService(vault);

      await vault.save(
        const StoredCredential(
          username: '2024000000',
          password: 'secret',
          fingerPrint: 'fp',
          fingerGenPrint: 'trusted-token',
          deviceName: 'Android,LearnY',
          singleLoginEnabled: true,
        ),
      );

      final didRelogin = await service.tryRelogin(apiClient);

      expect(didRelogin, isTrue);
      expect(apiClient.calls, hasLength(1));
      expect(apiClient.calls.single.singleLoginEnabled, isTrue);
    });
  });
}

class _RecordingLearnHelper extends Learn2018Helper {
  final List<_LoginCall> calls = <_LoginCall>[];

  @override
  Future<void> login([
    String? username,
    String? password,
    String? fingerPrint,
    String? fingerGenPrint,
    String? fingerGenPrint3,
    String? deviceName,
    bool singleLoginEnabled = false,
  ]) async {
    calls.add(
      _LoginCall(
        username: username,
        password: password,
        fingerPrint: fingerPrint,
        fingerGenPrint: fingerGenPrint,
        fingerGenPrint3: fingerGenPrint3,
        deviceName: deviceName,
        singleLoginEnabled: singleLoginEnabled,
      ),
    );
  }
}

class _LoginCall {
  const _LoginCall({
    required this.username,
    required this.password,
    required this.fingerPrint,
    required this.fingerGenPrint,
    required this.fingerGenPrint3,
    required this.deviceName,
    required this.singleLoginEnabled,
  });

  final String? username;
  final String? password;
  final String? fingerPrint;
  final String? fingerGenPrint;
  final String? fingerGenPrint3;
  final String? deviceName;
  final bool singleLoginEnabled;
}

class _MemorySecureStorage implements FlutterSecureStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    _values.remove(key);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
