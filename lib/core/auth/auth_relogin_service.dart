import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/enums.dart';
import '../api/learn_api.dart';
import '../api/models.dart';
import 'credential_vault.dart';

class AuthReloginService {
  AuthReloginService(this._vault, {Random? random})
    : _random = random ?? Random.secure();

  final CredentialVault _vault;
  final Random _random;

  Future<void> enrollCredential({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const ApiError(reason: FailReason.noCredential);
    }

    final credential = StoredCredential(
      username: normalizedUsername,
      password: password,
      fingerPrint: _generateFingerprint(),
    );

    await _verifyCredential(credential);
    await _vault.save(credential);
  }

  Future<void> saveVerifiedCredential({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
  }) async {
    final normalizedUsername = username.trim();
    final normalizedFingerPrint = fingerPrint.trim();
    if (
      normalizedUsername.isEmpty ||
      password.isEmpty ||
      normalizedFingerPrint.isEmpty
    ) {
      throw const ApiError(reason: FailReason.noCredential);
    }

    await _vault.save(
      StoredCredential(
        username: normalizedUsername,
        password: password,
        fingerPrint: normalizedFingerPrint,
        fingerGenPrint: fingerGenPrint,
        fingerGenPrint3: fingerGenPrint3,
        deviceName: deviceName,
      ),
    );
  }

  Future<bool> tryRelogin(Learn2018Helper apiClient) async {
    final credential = await _vault.read();
    if (credential == null) {
      return false;
    }

    try {
      await apiClient.login(
        credential.username,
        credential.password,
        credential.fingerPrint,
        credential.fingerGenPrint,
        credential.fingerGenPrint3,
        credential.deviceName,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearStoredCredential() {
    return _vault.clear();
  }

  Future<void> _verifyCredential(StoredCredential credential) async {
    final helper = Learn2018Helper(config: HelperConfig(cookieJar: CookieJar()));
    await helper.login(
      credential.username,
      credential.password,
      credential.fingerPrint,
      credential.fingerGenPrint,
      credential.fingerGenPrint3,
      credential.deviceName,
    );
  }

  String _generateFingerprint() {
    const alphabet = '0123456789abcdef';
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(alphabet[_random.nextInt(alphabet.length)]);
    }
    return buffer.toString();
  }
}

final authReloginServiceProvider = Provider<AuthReloginService>((ref) {
  return AuthReloginService(ref.watch(credentialVaultProvider));
});
