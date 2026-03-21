import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_controller.dart';

class AuthRouterRefreshNotifier extends ChangeNotifier {
  void markNeedsRefresh() {
    notifyListeners();
  }
}

final authRouterRefreshNotifierProvider = Provider<AuthRouterRefreshNotifier>((
  ref,
) {
  final notifier = AuthRouterRefreshNotifier();

  ref.listen<AuthState>(authProvider, (previous, next) {
    if (previous != null &&
        previous.isRestoring == next.isRestoring &&
        previous.canAccessCachedData == next.canAccessCachedData &&
        previous.isLoggedIn == next.isLoggedIn &&
        previous.requiresReauthentication == next.requiresReauthentication) {
      return;
    }
    notifier.markNeedsRefresh();
  });

  ref.onDispose(notifier.dispose);
  return notifier;
});
