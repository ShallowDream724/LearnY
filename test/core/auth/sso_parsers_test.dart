import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/auth/sso_fallback_page_parser.dart';
import 'package:learn_y/core/auth/sso_ticket_parser.dart';

void main() {
  group('SsoTicketParser', () {
    const parser = SsoTicketParser();

    test('consumes roaming ticket URLs', () {
      final instruction = parser.inspectNavigation(
        'https://learn.tsinghua.edu.cn/b/'
        'j_spring_security_thauth_roaming_entry?ticket=ST-12345',
      );

      expect(instruction.shouldConsumeTicket, isTrue);
      expect(instruction.ticket, 'ST-12345');
    });

    test('allows non-roaming navigations', () {
      final instruction = parser.inspectNavigation(
        'https://id.tsinghua.edu.cn/cas/login/form',
      );

      expect(instruction.shouldConsumeTicket, isFalse);
      expect(
        parser.shouldAttemptFallback('https://learn.tsinghua.edu.cn/'),
        isTrue,
      );
      expect(
        parser.shouldAttemptFallback(
          'https://learn.tsinghua.edu.cn/b/'
          'j_spring_security_thauth_roaming_entry?ticket=ST-12345',
        ),
        isFalse,
      );
    });
  });

  group('SsoFallbackPageParser', () {
    const parser = SsoFallbackPageParser();

    test('extracts csrf token and username from WebView html snapshot', () {
      final snapshot = parser.parse(
        '"<html><body><a class=\\"user-log\\">demo</a>'
        '<input type=\\"hidden\\" name=\\"_csrf\\" value=\\"csrf-123\\" />'
        '</body></html>"',
      );

      expect(snapshot.csrfToken, 'csrf-123');
      expect(snapshot.username, 'demo');
    });

    test('throws when csrf token is missing', () {
      expect(
        () => parser.parse('"<html><body>missing csrf</body></html>"'),
        throwsA(isA<SsoFallbackParseException>()),
      );
    });
  });
}
