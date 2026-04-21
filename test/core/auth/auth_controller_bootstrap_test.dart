import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/auth_controller.dart';

void main() {
  group('buildInitialAuthState', () {
    test('uses restoring state when startup bootstrap was not provided', () {
      expect(
        buildInitialAuthState(
          didBootstrapAppSession: false,
          initialUsername: 'demo',
        ).isRestoring,
        isTrue,
      );
    });

    test('uses cached state when bootstrapped username exists', () {
      final state = buildInitialAuthState(
        didBootstrapAppSession: true,
        initialUsername: '  demo  ',
      );

      expect(state.isRestoring, isFalse);
      expect(state.username, 'demo');
      expect(state.canAccessCachedData, isTrue);
    });

    test('uses signed-out state when bootstrapped username is empty', () {
      final state = buildInitialAuthState(
        didBootstrapAppSession: true,
        initialUsername: '   ',
      );

      expect(state.isSignedOut, isTrue);
      expect(state.canAccessCachedData, isFalse);
    });
  });
}
