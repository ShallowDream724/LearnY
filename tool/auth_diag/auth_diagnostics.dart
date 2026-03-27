import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter/foundation.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart';
import 'package:learn_y/core/auth/sso_cookie_bridge.dart';
import 'package:learn_y/core/auth/sso_fallback_page_parser.dart';

Future<int> runAuthDiagnostics(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(_CliOptions.usage);
    return 0;
  }

  final logFile = File(options.logPath);
  await logFile.parent.create(recursive: true);
  final logger = _MaskedLogger(logFile);
  debugPrint = logger.debugPrint;

  try {
    final capture = _CaptureContext.fromJson(
      jsonDecode(await File(options.capturePath).readAsString())
          as Map<String, dynamic>,
    );
    final username = options.resolveUsername();
    final password = options.resolvePassword();

    logger.section('capture summary');
    logger.info('status=${capture.status}');
    logger.info('finalUrl=${capture.finalUrl ?? '(none)'}');
    logger.info('ticket=${_mask(capture.ticket)}');
    logger.info('ticketDisposition=${capture.ticketDisposition}');
    logger.info('cookieCount=${capture.cookies.length}');
    logger.info(
      'formData=${jsonEncode(capture.formData.map((key, value) => MapEntry(key, _mask(value))))}',
    );
    if (capture.loginRequest != null) {
      logger.info(
        'loginRequest=${capture.loginRequest!.endpoint} keys=${capture.loginRequest!.bodyKeys.join(', ')}',
      );
      if (capture.loginRequest!.headers.isNotEmpty) {
        logger.info(
          'loginRequestHeaders=${jsonEncode(capture.loginRequest!.headers)}',
        );
      }
    }
    if (capture.inlineError != null && capture.inlineError!.trim().isNotEmpty) {
      logger.info('inlineError=${capture.inlineError}');
    }

    final effectiveAuthFields = capture.authFields;

    final results = <_StageResult>[];

    Future<void> runStage(
      String id,
      String title,
      Future<_StageResult> Function() action,
    ) async {
      logger.section(title);
      final stopwatch = Stopwatch()..start();
      try {
        final result = await action();
        results.add(
          result.copyWith(
            id: id,
            title: title,
            durationMs: stopwatch.elapsedMilliseconds,
          ),
        );
        logger.info(
          'result=${result.status.name} durationMs=${stopwatch.elapsedMilliseconds}',
        );
        if (result.message != null && result.message!.isNotEmpty) {
          logger.info(result.message!);
        }
      } catch (error, stackTrace) {
        results.add(
          _StageResult(
            id: id,
            title: title,
            status: _StageStatus.failed,
            durationMs: stopwatch.elapsedMilliseconds,
            message: _describeError(error),
          ),
        );
        logger.info(
          'result=failed durationMs=${stopwatch.elapsedMilliseconds}',
        );
        logger.info('error=${_describeError(error)}');
        logger.info('$stackTrace');
      }
    }

    await runStage(
      'captured_ticket_bootstrap',
      'captured ticket bootstrap',
      () async {
        final ticket = capture.ticket;
        if (ticket == null || ticket.isEmpty) {
          return const _StageResult.skipped(
            'capture.json does not contain a roaming ticket',
          );
        }
        if (capture.ticketDisposition != 'preserved') {
          return const _StageResult.skipped(
            'captured ticket was already observed by the browser; rerun capture with preserved ticket mode to replay it safely',
          );
        }

        final helper = _newHelper();
        await helper.loginWithTicket(ticket);
        final user = await helper.getUserInfo();
        return _StageResult.success(
          'ticket bootstrap succeeded as ${user.name} / ${user.department}',
        );
      },
    );

    await runStage(
      'captured_fallback_bootstrap',
      'captured fallback bootstrap',
      () async {
        if (capture.learnPageHtml == null ||
            capture.learnPageHtml!.trim().isEmpty) {
          return const _StageResult.skipped(
            'capture.json does not contain an authenticated learn HTML snapshot',
          );
        }
        if (capture.cookieString == null ||
            capture.cookieString!.trim().isEmpty) {
          return const _StageResult.skipped(
            'capture.json does not contain document.cookie data',
          );
        }

        final helper = _newHelper();
        final snapshot = const SsoFallbackPageParser().parse(
          capture.learnPageHtml!,
        );
        helper.setCSRFToken(snapshot.csrfToken);
        await SsoCookieBridge(
          helper,
        ).transferWebViewCookiesToDio(capture.cookieString!);
        final user = await helper.getUserInfo();
        return _StageResult.success(
          'fallback bootstrap succeeded as ${user.name} / ${user.department}',
        );
      },
    );

    await runStage(
      'captured_full_cookie_session',
      'captured full cookie session',
      () async {
        if (capture.cookies.isEmpty) {
          return const _StageResult.skipped(
            'capture.json does not contain browser cookies',
          );
        }

        final helper = _newHelper();
        await _importCookies(helper.cookieJar, capture.cookies);
        final user = await helper.getUserInfo();
        return _StageResult.success(
          'full browser cookie session succeeded as ${user.name} / ${user.department}',
        );
      },
    );

    await runStage(
      'silent_sso_cookie_recovery',
      'silent sso cookie recovery',
      () async {
        if (capture.cookies.isEmpty) {
          return const _StageResult.skipped(
            'capture.json does not contain browser cookies',
          );
        }

        final recoveryCookies = _cookiesForSilentRecovery(capture.cookies);
        if (recoveryCookies.isEmpty) {
          return const _StageResult.skipped(
            'capture.json does not contain cookies suitable for silent recovery',
          );
        }

        final helper = _newHelper();
        await _importCookies(helper.cookieJar, recoveryCookies);
        final recovered = await helper.attemptSilentSessionRecovery();
        if (!recovered) {
          return const _StageResult.failed(
            'attemptSilentSessionRecovery() returned false',
          );
        }
        final user = await helper.getUserInfo();
        return _StageResult.success(
          'silent cookie recovery succeeded as ${user.name} / ${user.department}',
        );
      },
    );

    await runStage('fresh_credential_chain', 'fresh credential chain', () async {
      if (options.skipFreshCredentialChain) {
        return const _StageResult.skipped('skipped by operator');
      }
      if (username == null || username.isEmpty) {
        return const _StageResult.skipped(
          'no username provided for the fresh credential chain',
        );
      }
      if (password == null || password.isEmpty) {
        return const _StageResult.skipped(
          'no password provided for the fresh credential chain',
        );
      }
      final fingerPrint = effectiveAuthFields['fingerPrint'] ?? '';
      if (fingerPrint.trim().isEmpty) {
        return const _StageResult.skipped(
          'capture.json does not contain fingerPrint from the login request or DOM capture',
        );
      }

      final helper = _newHelper();
      logger.info(
        'fresh auth fields=${jsonEncode(effectiveAuthFields.map((key, value) => MapEntry(key, _mask(value))))}',
      );
      final ticket = await helper.getRoamingTicket(
        username,
        password,
        fingerPrint,
        fingerGenPrint: effectiveAuthFields['fingerGenPrint'] ?? '',
        fingerGenPrint3: effectiveAuthFields['fingerGenPrint3'] ?? '',
        deviceName: effectiveAuthFields['deviceName'] ?? '',
      );
      logger.info('fresh roaming ticket=${_mask(ticket)}');
      await helper.loginWithTicket(ticket);
      final user = await helper.getUserInfo();
      return _StageResult.success(
        'fresh credential chain succeeded as ${user.name} / ${user.department}',
      );
    });

    final summary = <String, dynamic>{
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'capturePath': options.capturePath,
      'stages': results.map((stage) => stage.toJson()).toList(),
      'successCount': results
          .where((stage) => stage.status == _StageStatus.success)
          .length,
      'failedCount': results
          .where((stage) => stage.status == _StageStatus.failed)
          .length,
      'skippedCount': results
          .where((stage) => stage.status == _StageStatus.skipped)
          .length,
    };

    final summaryFile = File(options.summaryPath);
    await summaryFile.parent.create(recursive: true);
    await summaryFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(summary),
    );

    stdout.writeln('[auth-diag] Summary written to ${summaryFile.path}');
    stdout.writeln('[auth-diag] Log written to ${logFile.path}');
    for (final result in results) {
      stdout.writeln(
        '[auth-diag] ${result.status.name.padRight(7)} ${result.title}: '
        '${result.message ?? ''}',
      );
    }
    return 0;
  } finally {
    await logger.dispose();
  }
}

class _CliOptions {
  const _CliOptions({
    required this.capturePath,
    required this.summaryPath,
    required this.logPath,
    required this.usernameEnv,
    required this.passwordEnv,
    required this.usernameArg,
    required this.skipFreshCredentialChain,
    required this.showHelp,
  });

  static const String usage =
      'Internal usage: --capture <capture.json> --summary <summary.json> '
      '--log <diag.log> '
      '[--username <student_id>] [--username-env ENV] [--password-env ENV] '
      '[--skip-fresh-credential-chain]';

  final String capturePath;
  final String summaryPath;
  final String logPath;
  final String usernameEnv;
  final String passwordEnv;
  final String? usernameArg;
  final bool skipFreshCredentialChain;
  final bool showHelp;

  static _CliOptions parse(List<String> args) {
    String? capturePath;
    String? summaryPath;
    String? logPath;
    var usernameEnv = 'LEARNY_AUTH_DIAG_USERNAME';
    var passwordEnv = 'LEARNY_AUTH_DIAG_PASSWORD';
    String? usernameArg;
    var skipFreshCredentialChain = false;
    var showHelp = false;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--capture':
          capturePath = args[++i];
          break;
        case '--summary':
          summaryPath = args[++i];
          break;
        case '--log':
          logPath = args[++i];
          break;
        case '--username-env':
          usernameEnv = args[++i];
          break;
        case '--password-env':
          passwordEnv = args[++i];
          break;
        case '--username':
          usernameArg = args[++i];
          break;
        case '--skip-fresh-credential-chain':
          skipFreshCredentialChain = true;
          break;
        case '--help':
          showHelp = true;
          break;
        default:
          throw ArgumentError('Unknown argument: ${args[i]}');
      }
    }

    if (showHelp) {
      return _CliOptions(
        capturePath: capturePath ?? '',
        summaryPath: summaryPath ?? '',
        logPath: logPath ?? '',
        usernameEnv: usernameEnv,
        passwordEnv: passwordEnv,
        usernameArg: usernameArg,
        skipFreshCredentialChain: skipFreshCredentialChain,
        showHelp: true,
      );
    }

    if (capturePath == null || summaryPath == null || logPath == null) {
      throw ArgumentError('Missing required arguments.\n$usage');
    }

    return _CliOptions(
      capturePath: capturePath,
      summaryPath: summaryPath,
      logPath: logPath,
      usernameEnv: usernameEnv,
      passwordEnv: passwordEnv,
      usernameArg: usernameArg,
      skipFreshCredentialChain: skipFreshCredentialChain,
      showHelp: false,
    );
  }

  String? resolveUsername() {
    if (usernameArg != null && usernameArg!.trim().isNotEmpty) {
      return usernameArg!.trim();
    }
    final username = Platform.environment[usernameEnv];
    if (username == null || username.trim().isEmpty) {
      return null;
    }
    return username.trim();
  }

  String? resolvePassword() {
    final password = Platform.environment[passwordEnv];
    if (password == null || password.isEmpty) {
      return null;
    }
    return password;
  }
}

class _CaptureContext {
  const _CaptureContext({
    required this.status,
    required this.finalUrl,
    required this.inlineError,
    required this.ticket,
    required this.ticketDisposition,
    required this.formData,
    required this.loginRequest,
    required this.cookieString,
    required this.learnPageHtml,
    required this.cookies,
  });

  factory _CaptureContext.fromJson(Map<String, dynamic> json) {
    final formDataRaw = json['formData'] as Map<String, dynamic>? ?? const {};
    final cookiesRaw = json['cookies'] as List<dynamic>? ?? const [];
    final loginRequestRaw = json['loginRequest'] as Map<String, dynamic>?;
    final status = json['status'] as String? ?? 'unknown';
    final finalUrl = json['finalUrl'] as String?;
    final ticket = json['ticket'] as String?;
    final rawTicketDisposition = json['ticketDisposition'] as String?;
    return _CaptureContext(
      status: status,
      finalUrl: finalUrl,
      inlineError: json['inlineError'] as String?,
      ticket: ticket,
      ticketDisposition:
          rawTicketDisposition == null || rawTicketDisposition.trim().isEmpty
          ? _inferTicketDisposition(
              status: status,
              finalUrl: finalUrl,
              ticket: ticket,
            )
          : rawTicketDisposition,
      formData: formDataRaw.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      loginRequest: loginRequestRaw == null
          ? null
          : _CapturedLoginRequest.fromJson(loginRequestRaw),
      cookieString: json['cookieString'] as String?,
      learnPageHtml: json['learnPageHtml'] as String?,
      cookies: cookiesRaw
          .whereType<Map>()
          .map(
            (raw) => _CapturedCookie.fromJson(
              raw.map((key, value) => MapEntry('$key', value)),
            ),
          )
          .toList(),
    );
  }

  final String status;
  final String? finalUrl;
  final String? inlineError;
  final String? ticket;
  final String ticketDisposition;
  final Map<String, String> formData;
  final _CapturedLoginRequest? loginRequest;
  final String? cookieString;
  final String? learnPageHtml;
  final List<_CapturedCookie> cookies;

  Map<String, String> get authFields {
    final requestFields = loginRequest?.fields ?? const <String, String>{};
    if (requestFields.isNotEmpty) {
      return requestFields;
    }
    return formData;
  }
}

String _inferTicketDisposition({
  required String status,
  required String? finalUrl,
  required String? ticket,
}) {
  if (ticket == null || ticket.trim().isEmpty) {
    return 'none';
  }
  if (status == 'ticket_preserved') {
    return 'preserved';
  }
  if (finalUrl != null && finalUrl.contains('learn.tsinghua.edu.cn')) {
    return 'consumed';
  }
  return 'observed';
}

class _CapturedLoginRequest {
  const _CapturedLoginRequest({
    required this.endpoint,
    required this.bodyKeys,
    required this.fields,
    required this.headers,
  });

  factory _CapturedLoginRequest.fromJson(Map<String, dynamic> json) {
    final bodyKeysRaw = json['bodyKeys'] as List<dynamic>? ?? const [];
    final fieldsRaw = json['fields'] as Map<String, dynamic>? ?? const {};
    final headersRaw = json['headers'] as Map<String, dynamic>? ?? const {};
    return _CapturedLoginRequest(
      endpoint: json['endpoint'] as String? ?? 'unknown',
      bodyKeys: bodyKeysRaw.map((value) => value.toString()).toList(),
      fields: fieldsRaw.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
      headers: headersRaw.map(
        (key, value) => MapEntry(key, value?.toString() ?? ''),
      ),
    );
  }

  final String endpoint;
  final List<String> bodyKeys;
  final Map<String, String> fields;
  final Map<String, String> headers;
}

class _CapturedCookie {
  const _CapturedCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.expires,
    required this.httpOnly,
    required this.secure,
  });

  factory _CapturedCookie.fromJson(Map<String, dynamic> json) {
    return _CapturedCookie(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      path: json['path'] as String? ?? '/',
      expires: (json['expires'] as num?)?.toDouble(),
      httpOnly: json['httpOnly'] as bool? ?? false,
      secure: json['secure'] as bool? ?? false,
    );
  }

  final String name;
  final String value;
  final String domain;
  final String path;
  final double? expires;
  final bool httpOnly;
  final bool secure;
}

enum _StageStatus { success, failed, skipped }

class _StageResult {
  const _StageResult({
    required this.id,
    required this.title,
    required this.status,
    required this.durationMs,
    this.message,
  });

  const _StageResult.success(String message)
    : this(
        id: '',
        title: '',
        status: _StageStatus.success,
        durationMs: 0,
        message: message,
      );

  const _StageResult.failed(String message)
    : this(
        id: '',
        title: '',
        status: _StageStatus.failed,
        durationMs: 0,
        message: message,
      );

  const _StageResult.skipped(String message)
    : this(
        id: '',
        title: '',
        status: _StageStatus.skipped,
        durationMs: 0,
        message: message,
      );

  final String id;
  final String title;
  final _StageStatus status;
  final int durationMs;
  final String? message;

  _StageResult copyWith({
    String? id,
    String? title,
    _StageStatus? status,
    int? durationMs,
    String? message,
  }) {
    return _StageResult(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      durationMs: durationMs ?? this.durationMs,
      message: message ?? this.message,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'status': status.name,
    'durationMs': durationMs,
    'message': message,
  };
}

Learn2018Helper _newHelper() {
  return Learn2018Helper(config: HelperConfig(cookieJar: CookieJar()));
}

Future<void> _importCookies(
  CookieJar jar,
  List<_CapturedCookie> capturedCookies,
) async {
  for (final captured in capturedCookies) {
    final normalizedDomain = captured.domain.startsWith('.')
        ? captured.domain.substring(1)
        : captured.domain;
    if (normalizedDomain.isEmpty || captured.name.isEmpty) {
      continue;
    }

    final uri = Uri(
      scheme: 'https',
      host: normalizedDomain,
      path: captured.path.isEmpty ? '/' : captured.path,
    );
    final cookie = Cookie(captured.name, captured.value)
      ..domain = captured.domain
      ..path = captured.path.isEmpty ? '/' : captured.path
      ..httpOnly = captured.httpOnly
      ..secure = captured.secure;

    final expires = captured.expires;
    if (expires != null && expires > 0) {
      cookie.expires = DateTime.fromMillisecondsSinceEpoch(
        (expires * 1000).round(),
        isUtc: true,
      );
    }

    await jar.saveFromResponse(uri, <Cookie>[cookie]);
  }
}

List<_CapturedCookie> _cookiesForSilentRecovery(
  List<_CapturedCookie> capturedCookies,
) {
  return capturedCookies.where((cookie) {
    final normalizedDomain = cookie.domain.startsWith('.')
        ? cookie.domain.substring(1)
        : cookie.domain;
    final isLearnSessionCookie =
        normalizedDomain == 'learn.tsinghua.edu.cn' &&
        cookie.name.toUpperCase() == 'JSESSIONID';
    return !isLearnSessionCookie;
  }).toList();
}

String _describeError(Object error) {
  if (error is ApiError) {
    final extra = error.extra;
    final extraDescription = extra == null
        ? ''
        : '; extra=${_describeExtra(extra)}';
    return 'ApiError(${error.reason.name}: ${error.reason.message}$extraDescription)';
  }
  return error.toString();
}

String _describeExtra(Object extra) {
  if (extra is Exception || extra is Error) {
    return extra.toString();
  }
  final text = extra.toString();
  if (text.length <= 240) {
    return text;
  }
  return '${text.substring(0, 237)}...';
}

String _mask(String? value, {int prefix = 6, int suffix = 4}) {
  if (value == null || value.isEmpty) {
    return '(empty)';
  }
  if (value.length <= prefix + suffix) {
    return '${value[0]}***${value[value.length - 1]}';
  }
  return '${value.substring(0, prefix)}***${value.substring(value.length - suffix)}';
}

class _MaskedLogger {
  _MaskedLogger(File file)
    : _sink = file.openWrite(mode: FileMode.writeOnlyAppend);

  final IOSink _sink;

  void section(String title) {
    info('');
    info('=== $title ===');
  }

  void info(String message) {
    _sink.writeln(_maskSensitive(message));
  }

  void debugPrint(String? message, {int? wrapWidth}) {
    if (message == null) {
      return;
    }
    info(message);
  }

  Future<void> dispose() async {
    await _sink.flush();
    await _sink.close();
  }

  String _maskSensitive(String message) {
    return message
        .replaceAllMapped(
          RegExp(r'(ST-[A-Za-z0-9\-]+)'),
          (match) => _mask(match.group(1)),
        )
        .replaceAllMapped(
          RegExp(
            r'((?:JSESSIONID|CASTGC|TGC|SESSION|csrftoken)[^=;\s]*=)([^;\s]+)',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)}${_mask(match.group(2))}',
        );
  }
}
