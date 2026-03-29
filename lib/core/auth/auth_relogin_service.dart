import 'dart:math';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/enums.dart';
import '../api/learn_api.dart';
import '../api/models.dart';
import 'credential_vault.dart';
import 'auth_relogin_models.dart';

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

  Future<AuthReloginResult> enrollCredential({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();
    if (normalizedUsername.isEmpty || password.isEmpty) {
      return const AuthReloginResult.failure(
        stage: AuthReloginFailureStage.credentialUnavailable,
        reason: FailReason.noCredential,
      );
    }

    final credential = _buildCredentialSafely(
      username: normalizedUsername,
      password: password,
      fingerPrint: _generateFingerprint(),
    );
    if (credential == null) {
      return const AuthReloginResult.failure(
        stage: AuthReloginFailureStage.credentialUnavailable,
        reason: FailReason.noCredential,
      );
    }

    return _verifyAndPersistCredential(credential);
  }

  Future<AuthReloginResult> saveEnrolledCredential({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
    bool singleLoginEnabled = false,
  }) async {
    final credential = _buildCredentialSafely(
      username: username,
      password: password,
      fingerPrint: fingerPrint,
      fingerGenPrint: fingerGenPrint,
      fingerGenPrint3: fingerGenPrint3,
      deviceName: deviceName,
      singleLoginEnabled: singleLoginEnabled,
    );
    if (credential == null) {
      return const AuthReloginResult.failure(
        stage: AuthReloginFailureStage.credentialUnavailable,
        reason: FailReason.noCredential,
      );
    }

    return _verifyAndPersistCredential(credential);
  }

  Future<AuthReloginResult> saveVerifiedCredential({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
    bool singleLoginEnabled = false,
  }) async {
    return saveEnrolledCredential(
      username: username,
      password: password,
      fingerPrint: fingerPrint,
      fingerGenPrint: fingerGenPrint,
      fingerGenPrint3: fingerGenPrint3,
      deviceName: deviceName,
      singleLoginEnabled: singleLoginEnabled,
    );
  }

  Future<AuthReloginResult> tryRelogin(Learn2018Helper apiClient) async {
    final credential = await _vault.read();
    if (credential == null) {
      debugPrint('[LearnY] Secure credential relogin skipped: no credential');
      return const AuthReloginResult.failure(
        stage: AuthReloginFailureStage.credentialUnavailable,
        reason: FailReason.noCredential,
      );
    }

    return _attemptLogin(
      apiClient,
      credential,
      attemptCount: 1,
      flowLabel: 'Secure credential relogin',
    );
  }

  Future<void> clearStoredCredential() {
    return _vault.clear();
  }

  Future<AuthReloginResult> _verifyAndPersistCredential(
    StoredCredential credential,
  ) async {
    final verification = await _verifyCredentialWithRetry(credential);
    if (!verification.succeeded) {
      return verification;
    }

    await _vault.save(credential);
    return verification;
  }

  Future<AuthReloginResult> _verifyCredentialWithRetry(
    StoredCredential credential,
  ) async {
    final delays = <Duration>[
      Duration.zero,
      const Duration(milliseconds: 900),
      const Duration(milliseconds: 1800),
    ];

    AuthReloginResult? lastResult;
    for (var attempt = 0; attempt < delays.length; attempt++) {
      final delay = delays[attempt];
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }

      final helper = _helperFactory();
      final result = await _attemptLogin(
        helper,
        credential,
        attemptCount: attempt + 1,
        flowLabel: 'Enrollment verification',
      );
      if (result.succeeded) {
        return result;
      }
      lastResult = result;
      if (!result.shouldRetry) {
        break;
      }
    }

    return lastResult ??
        const AuthReloginResult.failure(
          stage: AuthReloginFailureStage.unknown,
        );
  }

  Future<AuthReloginResult> _attemptLogin(
    Learn2018Helper helper,
    StoredCredential credential, {
    required int attemptCount,
    required String flowLabel,
  }) async {
    final usesTrustedBrowser = credential.fingerGenPrint.trim().isNotEmpty;
    try {
      debugPrint(
        '[LearnY] $flowLabel started '
        '(attempt=$attemptCount, '
        'trusted=$usesTrustedBrowser, '
        'singleLogin=${credential.singleLoginEnabled})',
      );
      await helper.login(
        credential.username,
        credential.password,
        credential.fingerPrint,
        credential.fingerGenPrint,
        credential.fingerGenPrint3,
        credential.deviceName,
        credential.singleLoginEnabled,
      );
      debugPrint('[LearnY] $flowLabel completed (attempt=$attemptCount)');
      return AuthReloginResult.success(
        attemptCount: attemptCount,
        usedTrustedBrowser: usesTrustedBrowser,
      );
    } catch (error, stackTrace) {
      final result = AuthReloginResult.fromError(
        error,
        attemptCount: attemptCount,
        usedTrustedBrowser: usesTrustedBrowser,
      );
      debugPrint(
        '[LearnY] $flowLabel failed '
        '(attempt=$attemptCount, stage=${result.failureStage?.name}, '
        'reason=${result.reason?.name ?? 'unknown'})',
      );
      debugPrint('$error');
      debugPrint('$stackTrace');
      return result;
    }
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

  StoredCredential? _buildCredentialSafely({
    required String username,
    required String password,
    required String fingerPrint,
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
    String deviceName = '',
    bool singleLoginEnabled = false,
  }) {
    try {
      return _buildCredential(
        username: username,
        password: password,
        fingerPrint: fingerPrint,
        fingerGenPrint: fingerGenPrint,
        fingerGenPrint3: fingerGenPrint3,
        deviceName: deviceName,
        singleLoginEnabled: singleLoginEnabled,
      );
    } on ApiError {
      return null;
    }
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
