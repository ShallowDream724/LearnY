import 'dart:convert';

import '../api/enums.dart';
import '../api/models.dart';

enum SessionRecoveryMethod { ssoCookie, secureCredential }

enum AutoReloginStatusPhase { disabled, verified, degraded }

enum AutoReloginFailureSource { enrollment, sessionRecovery }

enum AuthReloginFailureStage {
  credentialUnavailable,
  trustedBrowserState,
  identityAuthentication,
  learnSessionBootstrap,
  responseValidation,
  unknown,
}

class AuthReloginResult {
  const AuthReloginResult._({
    required this.succeeded,
    required this.attemptCount,
    required this.usedTrustedBrowser,
    this.failureStage,
    this.reason,
    this.details,
  });

  const AuthReloginResult.success({
    int attemptCount = 1,
    bool usedTrustedBrowser = false,
  }) : this._(
         succeeded: true,
         attemptCount: attemptCount,
         usedTrustedBrowser: usedTrustedBrowser,
       );

  const AuthReloginResult.failure({
    required AuthReloginFailureStage stage,
    FailReason? reason,
    String? details,
    int attemptCount = 1,
    bool usedTrustedBrowser = false,
  }) : this._(
         succeeded: false,
         attemptCount: attemptCount,
         usedTrustedBrowser: usedTrustedBrowser,
         failureStage: stage,
         reason: reason,
         details: details,
       );

  factory AuthReloginResult.fromApiError(
    ApiError error, {
    int attemptCount = 1,
    bool usedTrustedBrowser = false,
  }) {
    return AuthReloginResult.failure(
      stage: _mapFailReasonToStage(error.reason),
      reason: error.reason,
      details: error.extra?.toString(),
      attemptCount: attemptCount,
      usedTrustedBrowser: usedTrustedBrowser,
    );
  }

  factory AuthReloginResult.fromError(
    Object error, {
    int attemptCount = 1,
    bool usedTrustedBrowser = false,
  }) {
    if (error is ApiError) {
      return AuthReloginResult.fromApiError(
        error,
        attemptCount: attemptCount,
        usedTrustedBrowser: usedTrustedBrowser,
      );
    }

    return AuthReloginResult.failure(
      stage: AuthReloginFailureStage.unknown,
      details: error.toString(),
      attemptCount: attemptCount,
      usedTrustedBrowser: usedTrustedBrowser,
    );
  }

  final bool succeeded;
  final int attemptCount;
  final bool usedTrustedBrowser;
  final AuthReloginFailureStage? failureStage;
  final FailReason? reason;
  final String? details;

  bool get shouldRetry {
    if (succeeded) {
      return false;
    }

    return switch (reason) {
      FailReason.noCredential || FailReason.badCredential => false,
      _ => failureStage != AuthReloginFailureStage.trustedBrowserState,
    };
  }

  String get failureDisplayLabel {
    final stage = failureStage ?? AuthReloginFailureStage.unknown;
    return describeAuthReloginFailure(stage: stage, reason: reason);
  }

  String get enrollmentFailureMessage {
    if (succeeded) {
      return '自动重新登录验证成功';
    }

    return switch (reason) {
      FailReason.badCredential => '自动重新登录验证失败：统一身份账号或密码不正确',
      FailReason.errorRoaming => '自动重新登录验证失败：学堂会话建立失败，请稍后重试',
      FailReason.errorFetchFromId => '自动重新登录验证失败：统一身份认证验证失败，请稍后重试',
      _ when failureStage == AuthReloginFailureStage.trustedBrowserState =>
        '自动重新登录授权未完成，请在二次认证后信任当前设备',
      _ when failureStage == AuthReloginFailureStage.credentialUnavailable =>
        '自动重新登录验证失败：安全凭据缺失，请重新配置',
      _ when failureStage == AuthReloginFailureStage.learnSessionBootstrap =>
        '自动重新登录验证失败：学堂会话建立失败，请稍后重试',
      _ => '自动重新登录验证失败：$failureDisplayLabel',
    };
  }

  String get sessionExpiredMessage {
    if (succeeded) {
      return '会话已恢复';
    }

    return switch (failureStage ?? AuthReloginFailureStage.unknown) {
      AuthReloginFailureStage.credentialUnavailable =>
        '会话已过期：自动重新登录需重新配置，可继续查看缓存数据',
      AuthReloginFailureStage.trustedBrowserState =>
        '会话已过期：自动重新登录授权未完成，可继续查看缓存数据',
      _ => '会话已过期：静默恢复失败（$failureDisplayLabel），可继续查看缓存数据',
    };
  }
}

class AutoReloginStatusSnapshot {
  const AutoReloginStatusSnapshot._({
    required this.isLoaded,
    required this.phase,
    this.lastVerifiedAt,
    this.lastRecoveryAt,
    this.lastRecoveryMethod,
    this.lastFailureAt,
    this.lastFailureStage,
    this.lastFailureReason,
    this.lastFailureSource,
  });

  const AutoReloginStatusSnapshot.loading()
    : this._(
        isLoaded: false,
        phase: AutoReloginStatusPhase.disabled,
      );

  const AutoReloginStatusSnapshot.disabled()
    : this._(
        isLoaded: true,
        phase: AutoReloginStatusPhase.disabled,
      );

  final bool isLoaded;
  final AutoReloginStatusPhase phase;
  final DateTime? lastVerifiedAt;
  final DateTime? lastRecoveryAt;
  final SessionRecoveryMethod? lastRecoveryMethod;
  final DateTime? lastFailureAt;
  final AuthReloginFailureStage? lastFailureStage;
  final FailReason? lastFailureReason;
  final AutoReloginFailureSource? lastFailureSource;

  String? get failureDisplayLabel {
    final stage = lastFailureStage;
    if (stage == null) {
      return null;
    }
    return describeAuthReloginFailure(stage: stage, reason: lastFailureReason);
  }

  String? get recoveryMethodDisplayLabel {
    return switch (lastRecoveryMethod) {
      SessionRecoveryMethod.ssoCookie => 'SSO 漫游',
      SessionRecoveryMethod.secureCredential => '安全凭据',
      null => null,
    };
  }

  AutoReloginStatusSnapshot markVerified(DateTime at) {
    return AutoReloginStatusSnapshot._(
      isLoaded: true,
      phase: AutoReloginStatusPhase.verified,
      lastVerifiedAt: at,
      lastRecoveryAt: lastRecoveryAt,
      lastRecoveryMethod: lastRecoveryMethod,
      lastFailureAt: null,
      lastFailureStage: null,
      lastFailureReason: null,
      lastFailureSource: null,
    );
  }

  AutoReloginStatusSnapshot markRecoverySuccess(
    SessionRecoveryMethod method,
    DateTime at,
  ) {
    final clearsFailure = method == SessionRecoveryMethod.secureCredential;
    return AutoReloginStatusSnapshot._(
      isLoaded: true,
      phase: clearsFailure ? AutoReloginStatusPhase.verified : phase,
      lastVerifiedAt: lastVerifiedAt,
      lastRecoveryAt: at,
      lastRecoveryMethod: method,
      lastFailureAt: clearsFailure ? null : lastFailureAt,
      lastFailureStage: clearsFailure ? null : lastFailureStage,
      lastFailureReason: clearsFailure ? null : lastFailureReason,
      lastFailureSource: clearsFailure ? null : lastFailureSource,
    );
  }

  AutoReloginStatusSnapshot markFailure({
    required AuthReloginFailureStage stage,
    required AutoReloginFailureSource source,
    FailReason? reason,
    required DateTime at,
  }) {
    return AutoReloginStatusSnapshot._(
      isLoaded: true,
      phase: AutoReloginStatusPhase.degraded,
      lastVerifiedAt: lastVerifiedAt,
      lastRecoveryAt: lastRecoveryAt,
      lastRecoveryMethod: lastRecoveryMethod,
      lastFailureAt: at,
      lastFailureStage: stage,
      lastFailureReason: reason,
      lastFailureSource: source,
    );
  }

  AutoReloginStatusSnapshot markDisabled() {
    return AutoReloginStatusSnapshot._(
      isLoaded: true,
      phase: AutoReloginStatusPhase.disabled,
      lastVerifiedAt: lastVerifiedAt,
      lastRecoveryAt: lastRecoveryAt,
      lastRecoveryMethod: lastRecoveryMethod,
      lastFailureAt: null,
      lastFailureStage: null,
      lastFailureReason: null,
      lastFailureSource: null,
    );
  }

  AutoReloginStatusSnapshot reset() {
    return const AutoReloginStatusSnapshot.disabled();
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'phase': phase.name,
      'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
      'lastRecoveryAt': lastRecoveryAt?.toIso8601String(),
      'lastRecoveryMethod': lastRecoveryMethod?.name,
      'lastFailureAt': lastFailureAt?.toIso8601String(),
      'lastFailureStage': lastFailureStage?.name,
      'lastFailureReason': lastFailureReason?.name,
      'lastFailureSource': lastFailureSource?.name,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  static AutoReloginStatusSnapshot fromJsonString(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const AutoReloginStatusSnapshot.disabled();
    }

    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return AutoReloginStatusSnapshot._(
        isLoaded: true,
        phase: _enumByName(
              AutoReloginStatusPhase.values,
              json['phase'] as String?,
            ) ??
            AutoReloginStatusPhase.disabled,
        lastVerifiedAt: _parseDateTime(json['lastVerifiedAt']),
        lastRecoveryAt: _parseDateTime(json['lastRecoveryAt']),
        lastRecoveryMethod: _enumByName(
          SessionRecoveryMethod.values,
          json['lastRecoveryMethod'] as String?,
        ),
        lastFailureAt: _parseDateTime(json['lastFailureAt']),
        lastFailureStage: _enumByName(
          AuthReloginFailureStage.values,
          json['lastFailureStage'] as String?,
        ),
        lastFailureReason: _enumByName(
          FailReason.values,
          json['lastFailureReason'] as String?,
        ),
        lastFailureSource: _enumByName(
          AutoReloginFailureSource.values,
          json['lastFailureSource'] as String?,
        ),
      );
    } catch (_) {
      return const AutoReloginStatusSnapshot.disabled();
    }
  }
}

String describeAuthReloginFailure({
  required AuthReloginFailureStage stage,
  FailReason? reason,
}) {
  return switch (reason) {
    FailReason.noCredential => '安全凭据缺失',
    FailReason.badCredential => '统一身份认证（账号或密码无效）',
    FailReason.errorFetchFromId => '统一身份认证',
    FailReason.errorRoaming || FailReason.notLoggedIn => '学堂会话建立',
    FailReason.invalidResponse ||
    FailReason.unexpectedStatus ||
    FailReason.operationFailed ||
    FailReason.errorSettingCookies ||
    FailReason.notImplemented => '静默重登校验',
    null => switch (stage) {
      AuthReloginFailureStage.credentialUnavailable => '安全凭据缺失',
      AuthReloginFailureStage.trustedBrowserState => '信任设备授权',
      AuthReloginFailureStage.identityAuthentication => '统一身份认证',
      AuthReloginFailureStage.learnSessionBootstrap => '学堂会话建立',
      AuthReloginFailureStage.responseValidation => '静默重登校验',
      AuthReloginFailureStage.unknown => '未知环节',
    },
  };
}

AuthReloginFailureStage _mapFailReasonToStage(FailReason reason) {
  return switch (reason) {
    FailReason.noCredential => AuthReloginFailureStage.credentialUnavailable,
    FailReason.badCredential ||
    FailReason.errorFetchFromId => AuthReloginFailureStage.identityAuthentication,
    FailReason.errorRoaming ||
    FailReason.notLoggedIn => AuthReloginFailureStage.learnSessionBootstrap,
    FailReason.invalidResponse ||
    FailReason.unexpectedStatus ||
    FailReason.operationFailed ||
    FailReason.errorSettingCookies ||
    FailReason.notImplemented => AuthReloginFailureStage.responseValidation,
  };
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

T? _enumByName<T extends Enum>(List<T> values, String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  for (final value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  return null;
}
