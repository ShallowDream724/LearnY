import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'identity_auth_web_surface_mobile.dart';
import 'identity_auth_web_surface_windows.dart';

typedef IdentityAuthPageStartedCallback = void Function(String url);
typedef IdentityAuthPageFinishedCallback = Future<void> Function(String url);
typedef IdentityAuthNavigationRequestCallback = bool Function(String url);
typedef IdentityAuthJavaScriptMessageCallback = void Function(Object message);

class IdentityAuthWebCallbacks {
  const IdentityAuthWebCallbacks({
    required this.onPageStarted,
    required this.onPageFinished,
    required this.onNavigationRequest,
    required this.onJavaScriptMessage,
  });

  final IdentityAuthPageStartedCallback onPageStarted;
  final IdentityAuthPageFinishedCallback onPageFinished;
  final IdentityAuthNavigationRequestCallback onNavigationRequest;
  final IdentityAuthJavaScriptMessageCallback onJavaScriptMessage;
}

enum IdentityAuthWebAvailabilityStatus {
  available,
  missingRuntime,
  unavailable,
}

class IdentityAuthWebAvailability {
  const IdentityAuthWebAvailability._({required this.status, this.message});

  const IdentityAuthWebAvailability.available()
    : this._(status: IdentityAuthWebAvailabilityStatus.available);

  const IdentityAuthWebAvailability.missingRuntime(String message)
    : this._(
        status: IdentityAuthWebAvailabilityStatus.missingRuntime,
        message: message,
      );

  const IdentityAuthWebAvailability.unavailable(String message)
    : this._(
        status: IdentityAuthWebAvailabilityStatus.unavailable,
        message: message,
      );

  final IdentityAuthWebAvailabilityStatus status;
  final String? message;

  bool get isAvailable => status == IdentityAuthWebAvailabilityStatus.available;
}

abstract class IdentityAuthWebSurfaceController {
  Future<IdentityAuthWebAvailability> initialize();

  Future<void> clearBrowsingData();

  Future<void> loadUrl(String url);

  Future<void> runJavaScript(String script);

  Future<Object?> runJavaScriptReturningResult(String script);

  Future<String?> getCurrentCookieHeader();

  Widget buildView();

  Future<void> dispose();
}

IdentityAuthWebSurfaceController createIdentityAuthWebSurfaceController(
  IdentityAuthWebCallbacks callbacks,
) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.windows => WindowsIdentityAuthWebSurfaceController(
      callbacks,
    ),
    _ => MobileIdentityAuthWebSurfaceController(callbacks),
  };
}
