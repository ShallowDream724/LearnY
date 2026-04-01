enum AuthEntryMode { loginOnly, loginAndEnableAutoRelogin, enableAutoRelogin }

class AutoReloginSetupInput {
  const AutoReloginSetupInput({required this.username, required this.password});

  final String username;
  final String password;
}

class AutoReloginEnrollmentPayload {
  const AutoReloginEnrollmentPayload({
    required this.username,
    required this.password,
    required this.fingerPrint,
    this.fingerGenPrint = '',
    this.fingerGenPrint3 = '',
    this.deviceName = '',
    this.singleLoginEnabled = false,
  });

  final String username;
  final String password;
  final String fingerPrint;
  final String fingerGenPrint;
  final String fingerGenPrint3;
  final String deviceName;
  final bool singleLoginEnabled;

  String get resolvedFingerGenPrint => fingerGenPrint.trim();

  String get resolvedFingerGenPrint3 {
    final normalizedFingerGenPrint3 = fingerGenPrint3.trim();
    if (normalizedFingerGenPrint3.isNotEmpty) {
      return normalizedFingerGenPrint3;
    }
    return resolvedFingerGenPrint;
  }

  bool get hasReusableTrustedBrowserState => resolvedFingerGenPrint.isNotEmpty;
}

class AuthEntryRequest {
  const AuthEntryRequest.loginOnly({this.resetBrowserContext = false})
    : mode = AuthEntryMode.loginOnly,
      input = null;

  const AuthEntryRequest.loginAndEnableAutoRelogin({
    required this.input,
    this.resetBrowserContext = false,
  }) : mode = AuthEntryMode.loginAndEnableAutoRelogin;

  const AuthEntryRequest.enableAutoRelogin({
    required this.input,
    this.resetBrowserContext = false,
  }) : mode = AuthEntryMode.enableAutoRelogin;

  final AuthEntryMode mode;
  final AutoReloginSetupInput? input;
  final bool resetBrowserContext;

  bool get requiresAutoRelogin =>
      mode == AuthEntryMode.loginAndEnableAutoRelogin ||
      mode == AuthEntryMode.enableAutoRelogin;

  bool get shouldInjectCredential => input != null;
}

class AuthEntryResult {
  const AuthEntryResult({
    required this.username,
    this.autoReloginConfigured = false,
    this.noticeMessage,
  });

  final String username;
  final bool autoReloginConfigured;
  final String? noticeMessage;
}
