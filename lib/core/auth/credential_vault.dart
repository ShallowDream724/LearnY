import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../providers/app_providers.dart';

class StoredCredential {
  const StoredCredential({
    required this.username,
    required this.password,
    required this.fingerPrint,
    this.fingerGenPrint = '',
    this.fingerGenPrint3 = '',
    this.deviceName = '',
  });

  final String username;
  final String password;
  final String fingerPrint;
  final String fingerGenPrint;
  final String fingerGenPrint3;
  final String deviceName;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'username': username,
    'password': password,
    'fingerPrint': fingerPrint,
    'fingerGenPrint': fingerGenPrint,
    'fingerGenPrint3': fingerGenPrint3,
    'deviceName': deviceName,
  };

  static StoredCredential? fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final username = (json['username'] as String? ?? '').trim();
      final password = json['password'] as String? ?? '';
      final fingerPrint = (json['fingerPrint'] as String? ?? '').trim();
      final fingerGenPrint = json['fingerGenPrint'] as String? ?? '';
      final fingerGenPrint3 = json['fingerGenPrint3'] as String? ?? '';
      final deviceName = json['deviceName'] as String? ?? '';

      if (username.isEmpty || password.isEmpty || fingerPrint.isEmpty) {
        return null;
      }

      return StoredCredential(
        username: username,
        password: password,
        fingerPrint: fingerPrint,
        fingerGenPrint: fingerGenPrint,
        fingerGenPrint3: fingerGenPrint3,
        deviceName: deviceName,
      );
    } catch (_) {
      return null;
    }
  }
}

class CredentialVault {
  const CredentialVault(this._storage);

  static const String _vaultKey = 'learny.auth.auto_relogin_credential';

  final FlutterSecureStorage _storage;

  Future<StoredCredential?> read() async {
    final raw = await _storage.read(key: _vaultKey);
    return StoredCredential.fromJsonString(raw);
  }

  Future<bool> hasCredential() async {
    return (await read()) != null;
  }

  Future<void> save(StoredCredential credential) {
    return _storage.write(
      key: _vaultKey,
      value: jsonEncode(credential.toJson()),
    );
  }

  Future<void> clear() {
    return _storage.delete(key: _vaultKey);
  }
}

final credentialVaultProvider = Provider<CredentialVault>((ref) {
  return CredentialVault(ref.watch(secureStorageProvider));
});

final storedCredentialAvailabilityProvider = FutureProvider<bool>((ref) async {
  return ref.watch(credentialVaultProvider).hasCredential();
});
