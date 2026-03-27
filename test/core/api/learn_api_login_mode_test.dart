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
  });
}
