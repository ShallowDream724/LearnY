import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/identity_password_utils.dart';

void main() {
  group('looksLikeIdentityPasswordCiphertext', () {
    test('detects SM2 ciphertext captured from identity form submission', () {
      final ciphertext = '04${'a' * 218}';

      expect(looksLikeIdentityPasswordCiphertext(ciphertext), isTrue);
    });

    test('does not flag normal passwords as ciphertext', () {
      expect(looksLikeIdentityPasswordCiphertext('secret123'), isFalse);
      expect(looksLikeIdentityPasswordCiphertext('04abc123'), isFalse);
    });
  });

  group('resolveEnrollmentPassword', () {
    test('falls back to setup password when submitted value is ciphertext', () {
      final resolved = resolveEnrollmentPassword(
        submittedPassword: '04${'b' * 218}',
        fallbackPassword: 'plain-secret',
      );

      expect(resolved, 'plain-secret');
    });

    test('keeps submitted password when it is still plain text', () {
      final resolved = resolveEnrollmentPassword(
        submittedPassword: 'typed-on-page',
        fallbackPassword: 'dialog-secret',
      );

      expect(resolved, 'typed-on-page');
    });
  });
}
