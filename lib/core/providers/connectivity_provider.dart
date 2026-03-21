/// Connectivity provider — monitors network state and exposes it to the UI.
///
/// Uses `connectivity_plus` for real-time network state changes.
/// The app shell wraps content with a _ConnectivityBanner that shows
/// a subtle offline indicator when network is unavailable.
import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
//  Connectivity state
// ---------------------------------------------------------------------------

enum NetworkStatus { online, offline, unknown }

class ConnectivityState {
  final NetworkStatus status;
  final DateTime? lastChecked;

  const ConnectivityState({
    this.status = NetworkStatus.unknown,
    this.lastChecked,
  });
}

// ---------------------------------------------------------------------------
//  Notifier
// ---------------------------------------------------------------------------

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  ConnectivityNotifier() : super(const ConnectivityState()) {
    _init();
  }

  Future<void> _init() async {
    // Initial check
    final result = await Connectivity().checkConnectivity();
    _updateFromResult(result);

    // Listen for changes
    _subscription = Connectivity().onConnectivityChanged.listen(
      _updateFromResult,
    );
  }

  void _updateFromResult(List<ConnectivityResult> results) {
    final isOffline = results.every((r) => r == ConnectivityResult.none);
    state = ConnectivityState(
      status: isOffline ? NetworkStatus.offline : NetworkStatus.online,
      lastChecked: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
//  Provider
// ---------------------------------------------------------------------------

final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, ConnectivityState>(
      (ref) => ConnectivityNotifier(),
    );
