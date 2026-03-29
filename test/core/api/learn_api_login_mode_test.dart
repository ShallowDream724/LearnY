import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';

void main() {
  group('learn login mode detection', () {
    test('detects trusted-device single-login pages', () {
      expect(
        supportsSingleLoginShortcut(
          '<html><script>function checkSingle(){}</script></html>',
        ),
        isTrue,
      );
    });

    test('does not detect single-login on normal credential pages', () {
      expect(
        supportsSingleLoginShortcut(
          '<html><input id="i_user" /><input id="i_pass" /></html>',
        ),
        isFalse,
      );
    });

    test('builds normal identity check payload without singleLogin', () {
      final formData = buildIdentityCheckFormData(
        username: '20240001',
        encryptedPassword: 'encrypted-value',
        fingerPrint: 'fp-1',
        fingerGenPrint: '',
        fingerGenPrint3: '',
        deviceName: 'windows,Edge/146',
      );

      expect(formData['i_user'], '20240001');
      expect(formData['i_pass'], 'encrypted-value');
      expect(formData['fingerPrint'], 'fp-1');
      expect(formData['deviceName'], 'windows,Edge/146');
      expect(formData.containsKey('singleLogin'), isFalse);
    });

    test('can opt into singleLogin when explicitly requested', () {
      final formData = buildIdentityCheckFormData(
        username: '20240001',
        encryptedPassword: 'encrypted-value',
        fingerPrint: 'fp-1',
        includeSingleLogin: true,
      );

      expect(formData['singleLogin'], 'on');
    });

    test('normalizes SM2 identity password to 04-prefixed ciphertext', () {
      const publicKey =
          '0432C4AE2C1F1981195F9904466A39C9948FE30BBFF2660BE1715A4589334C74C7'
          'BC3736A2F4F6779C59BDCEE36B692153D0A9877CC62A474002DF32E52139F0A0';

      final encrypted = encryptIdentityPassword('abc', publicKey);

      expect(encrypted.startsWith('04'), isTrue);
      expect(encrypted.length, 130 + 64 + ('abc'.length * 2));
    });
  });
}
