import 'dart:convert';

import '../api/enums.dart';
import '../api/models.dart';

enum SessionRecoveryMethod { ssoCookie, secureCredential }

enum AutoReloginProbeMethod { secureCredential }

enum AutoReloginStatusPhase { disabled, needsSetup, probing, ready, degraded }

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
      return '自动重新登录已就绪';
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
    required this.enabledByUser,
    required this.hasStoredCredential,
    required this.trustedBrowserReady,
    this.lastConfiguredAt,
    this.lastProbeAt,
    this.lastProbeMethod,
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
        enabledByUser: false,
        hasStoredCredential: false,
        trustedBrowserReady: false,
      );

  const AutoReloginStatusSnapshot.disabled()
    : this._(
        isLoaded: true,
        phase: AutoReloginStatusPhase.disabled,
        enabledByUser: false,
        hasStoredCredential: false,
        trustedBrowserReady: false,
      );

  static const Object _unset = Object();

  final bool isLoaded;
  final AutoReloginStatusPhase phase;
  final bool enabledByUser;
  final bool hasStoredCredential;
  final bool trustedBrowserReady;
  final DateTime? lastConfiguredAt;
  final DateTime? lastProbeAt;
  final AutoReloginProbeMethod? lastProbeMethod;
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

  String? get probeMethodDisplayLabel {
    return switch (lastProbeMethod) {
      AutoReloginProbeMethod.secureCredential => '安全凭据',
      null => null,
    };
  }

  String? get recoveryMethodDisplayLabel {
    return switch (lastRecoveryMethod) {
      SessionRecoveryMethod.ssoCookie => 'SSO 漫游',
      SessionRecoveryMethod.secureCredential => '安全凭据',
      null => null,
    };
  }

  AutoReloginStatusSnapshot markProbeStarted(DateTime at) {
    return copyWith(
      isLoaded: true,
      phase: AutoReloginStatusPhase.probing,
      enabledByUser: true,
      lastConfiguredAt: lastConfiguredAt ?? at,
      lastFailureAt: null,
      lastFailureStage: null,
      lastFailureReason: null,
      lastFailureSource: null,
    );
  }

  AutoReloginStatusSnapshot markEnrollmentSuccess({
    required AutoReloginProbeMethod probeMethod,
    required DateTime at,
    required bool trustedBrowserReady,
  }) {
    return copyWith(
      isLoaded: true,
      phase: AutoReloginStatusPhase.ready,
      enabledByUser: true,
      hasStoredCredential: true,
      trustedBrowserReady: trustedBrowserReady,
      lastConfiguredAt: at,
      lastProbeAt: at,
      lastProbeMethod: probeMethod,
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
    return copyWith(
      isLoaded: true,
      phase: clearsFailure ? AutoReloginStatusPhase.ready : phase,
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
    return copyWith(
      isLoaded: true,
      phase: enabledByUser
          ? AutoReloginStatusPhase.degraded
          : AutoReloginStatusPhase.needsSetup,
      enabledByUser: true,
      lastFailureAt: at,
      lastFailureStage: stage,
      lastFailureReason: reason,
      lastFailureSource: source,
    );
  }

  AutoReloginStatusSnapshot markDisabled() {
    return copyWith(
      isLoaded: true,
      phase: AutoReloginStatusPhase.disabled,
      enabledByUser: false,
      hasStoredCredential: false,
      trustedBrowserReady: false,
      lastFailureAt: null,
      lastFailureStage: null,
      lastFailureReason: null,
      lastFailureSource: null,
    );
  }

  AutoReloginStatusSnapshot reset() {
    return const AutoReloginStatusSnapshot.disabled();
  }

  AutoReloginStatusSnapshot copyWith({
    bool? isLoaded,
    AutoReloginStatusPhase? phase,
    bool? enabledByUser,
    bool? hasStoredCredential,
    bool? trustedBrowserReady,
    Object? lastConfiguredAt = _unset,
    Object? lastProbeAt = _unset,
    Object? lastProbeMethod = _unset,
    Object? lastRecoveryAt = _unset,
    Object? lastRecoveryMethod = _unset,
    Object? lastFailureAt = _unset,
    Object? lastFailureStage = _unset,
    Object? lastFailureReason = _unset,
    Object? lastFailureSource = _unset,
  }) {
    return AutoReloginStatusSnapshot._(
      isLoaded: isLoaded ?? this.isLoaded,
      phase: phase ?? this.phase,
      enabledByUser: enabledByUser ?? this.enabledByUser,
      hasStoredCredential: hasStoredCredential ?? this.hasStoredCredential,
      trustedBrowserReady: trustedBrowserReady ?? this.trustedBrowserReady,
      lastConfiguredAt: identical(lastConfiguredAt, _unset)
          ? this.lastConfiguredAt
          : lastConfiguredAt as DateTime?,
      lastProbeAt: identical(lastProbeAt, _unset)
          ? this.lastProbeAt
          : lastProbeAt as DateTime?,
      lastProbeMethod: identical(lastProbeMethod, _unset)
          ? this.lastProbeMethod
          : lastProbeMethod as AutoReloginProbeMethod?,
      lastRecoveryAt: identical(lastRecoveryAt, _unset)
          ? this.lastRecoveryAt
          : lastRecoveryAt as DateTime?,
      lastRecoveryMethod: identical(lastRecoveryMethod, _unset)
          ? this.lastRecoveryMethod
          : lastRecoveryMethod as SessionRecoveryMethod?,
      lastFailureAt: identical(lastFailureAt, _unset)
          ? this.lastFailureAt
          : lastFailureAt as DateTime?,
      lastFailureStage: identical(lastFailureStage, _unset)
          ? this.lastFailureStage
          : lastFailureStage as AuthReloginFailureStage?,
      lastFailureReason: identical(lastFailureReason, _unset)
          ? this.lastFailureReason
          : lastFailureReason as FailReason?,
      lastFailureSource: identical(lastFailureSource, _unset)
          ? this.lastFailureSource
          : lastFailureSource as AutoReloginFailureSource?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'phase': phase.name,
      'enabledByUser': enabledByUser,
      'hasStoredCredential': hasStoredCredential,
      'trustedBrowserReady': trustedBrowserReady,
      'lastConfiguredAt': lastConfiguredAt?.toUtc().toIso8601String(),
      'lastProbeAt': lastProbeAt?.toUtc().toIso8601String(),
      'lastProbeMethod': lastProbeMethod?.name,
      'lastRecoveryAt': lastRecoveryAt?.toUtc().toIso8601String(),
      'lastRecoveryMethod': lastRecoveryMethod?.name,
      'lastFailureAt': lastFailureAt?.toUtc().toIso8601String(),
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
      final parsedPhase = _parseStatusPhase(json['phase'] as String?);
      final legacyProbeAt = _parseDateTime(json['lastVerifiedAt']);
      final probeAt = _parseDateTime(json['lastProbeAt']) ?? legacyProbeAt;
      final configuredAt = _parseDateTime(json['lastConfiguredAt']) ?? probeAt;
      final hasStoredCredential =
          _parseBool(json['hasStoredCredential']) ??
          (parsedPhase == AutoReloginStatusPhase.ready ||
              parsedPhase == AutoReloginStatusPhase.degraded ||
              probeAt != null);

      return AutoReloginStatusSnapshot._(
        isLoaded: true,
        phase: parsedPhase,
        enabledByUser:
            _parseBool(json['enabledByUser']) ??
            parsedPhase != AutoReloginStatusPhase.disabled,
        hasStoredCredential: hasStoredCredential,
        trustedBrowserReady: _parseBool(json['trustedBrowserReady']) ?? false,
        lastConfiguredAt: configuredAt,
        lastProbeAt: probeAt,
        lastProbeMethod:
            _enumByName(
              AutoReloginProbeMethod.values,
              json['lastProbeMethod'] as String?,
            ) ??
            (probeAt != null ? AutoReloginProbeMethod.secureCredential : null),
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
    FailReason.badCredential || FailReason.errorFetchFromId =>
      AuthReloginFailureStage.identityAuthentication,
    FailReason.errorRoaming ||
    FailReason.notLoggedIn => AuthReloginFailureStage.learnSessionBootstrap,
    FailReason.invalidResponse ||
    FailReason.unexpectedStatus ||
    FailReason.operationFailed ||
    FailReason.errorSettingCookies ||
    FailReason.notImplemented => AuthReloginFailureStage.responseValidation,
  };
}

AutoReloginStatusPhase _parseStatusPhase(String? raw) {
  switch (raw) {
    case 'verified':
      return AutoReloginStatusPhase.ready;
    case 'needs_setup':
      return AutoReloginStatusPhase.needsSetup;
    case 'needsSetup':
      return AutoReloginStatusPhase.needsSetup;
    case 'probing':
      return AutoReloginStatusPhase.probing;
    case 'ready':
      return AutoReloginStatusPhase.ready;
    case 'degraded':
      return AutoReloginStatusPhase.degraded;
    case 'disabled':
    default:
      return AutoReloginStatusPhase.disabled;
  }
}

DateTime? _parseDateTime(Object? raw) {
  if (raw is! String || raw.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw);
}

bool? _parseBool(Object? raw) {
  return switch (raw) {
    final bool value => value,
    final String value => value == 'true' || value == '1' || value == 'on',
    final num value => value != 0,
    _ => null,
  };
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
