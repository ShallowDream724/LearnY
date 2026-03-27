import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/enums.dart';
import '../api/learn_api.dart';
import '../api/models.dart';
import 'credential_vault.dart';

typedef LearnApiFactory = Learn2018Helper Function();

class AuthReloginService {
  AuthReloginService(
    this._vault, {
    Random? random,
    LearnApiFactory? helperFactory,
  }) : _random = random ?? Random.secure(),
       _helperFactory = helperFactory ?? _defaultHelperFactory;

  final CredentialVault _vault;
  final Random _random;
  final LearnApiFactory _helperFactory;

  static Learn2018Helper _defaultHelperFactory() {
    return Learn2018Helper(config: HelperConfig(cookieJar: CookieJar()));
  }

  Future<void> enrollCredential({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      throw const ApiError(reason: FailReason.noCredential);
    }

    final credential = _buildCredential(
      username: normalizedUsername,
      password: password,
      fingerPrint: _generateFingerprint(),
    );

    await _verifyCredential(credential);
    await _vault.save(credential);
  }

  Future<void> saveEnrolledCredential({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
    bool singleLoginEnabled = false,
  }) async {
    final credential = _buildCredential(
      username: username,
      password: password,
      fingerPrint: fingerPrint,
      fingerGenPrint: fingerGenPrint,
      fingerGenPrint3: fingerGenPrint3,
      deviceName: deviceName,
      singleLoginEnabled: singleLoginEnabled,
    );

    await _vault.save(credential);
  }

  Future<void> saveVerifiedCredential({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
    bool singleLoginEnabled = false,
  }) async {
    final credential = _buildCredential(
      username: username,
      password: password,
      fingerPrint: fingerPrint,
      fingerGenPrint: fingerGenPrint,
      fingerGenPrint3: fingerGenPrint3,
      deviceName: deviceName,
      singleLoginEnabled: singleLoginEnabled,
    );

    await _verifyCredential(credential);
    await _vault.save(credential);
  }

  Future<bool> tryRelogin(Learn2018Helper apiClient) async {
    final credential = await _vault.read();
    if (credential == null) {
      debugPrint('[LearnY] Secure credential relogin skipped: no credential');
      return false;
    }

    try {
      debugPrint(
        '[LearnY] Secure credential relogin started '
        '(trusted=${credential.fingerGenPrint.trim().isNotEmpty}, '
        'singleLogin=${credential.singleLoginEnabled})',
      );
      await apiClient.login(
        credential.username,
        credential.password,
        credential.fingerPrint,
        credential.fingerGenPrint,
        credential.fingerGenPrint3,
        credential.deviceName,
        credential.singleLoginEnabled,
      );
      debugPrint('[LearnY] Secure credential relogin completed');
      return true;
    } catch (error, stackTrace) {
      debugPrint('[LearnY] Secure credential relogin failed: $error');
      debugPrint('$stackTrace');
      return false;
    }
  }

  Future<void> clearStoredCredential() {
    return _vault.clear();
  }

  Future<void> _verifyCredential(StoredCredential credential) async {
    final helper = _helperFactory();
    await helper.login(
      credential.username,
      credential.password,
      credential.fingerPrint,
      credential.fingerGenPrint,
      credential.fingerGenPrint3,
      credential.deviceName,
      credential.singleLoginEnabled,
    );
  }

  StoredCredential _buildCredential({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
    bool singleLoginEnabled = false,
  }) {
    final normalizedUsername = username.trim();
    final normalizedFingerPrint = fingerPrint.trim();
    if (normalizedUsername.isEmpty ||
        password.isEmpty ||
        normalizedFingerPrint.isEmpty) {
      throw const ApiError(reason: FailReason.noCredential);
    }

    return StoredCredential(
      username: normalizedUsername,
      password: password,
      fingerPrint: normalizedFingerPrint,
      fingerGenPrint: fingerGenPrint.trim(),
      fingerGenPrint3: fingerGenPrint3.trim(),
      deviceName: deviceName.trim(),
      singleLoginEnabled: singleLoginEnabled,
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
