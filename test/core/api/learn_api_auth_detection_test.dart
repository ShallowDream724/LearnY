import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/urls.dart' as urls;

void main() {
  group('learn auth page detection', () {
    test('treats identity login urls as unauthenticated session pages', () {
      expect(isIdentityLoginUri(Uri.parse(urls.idLogin())), isTrue);
      expect(
        isIdentityLoginUri(
          Uri.parse('${urls.learnStudentCourseListPage()}?login_timeout=1'),
        ),
        isTrue,
      );
      expect(
        isIdentityLoginUri(Uri.parse(urls.learnStudentCourseListPage())),
        isFalse,
      );
    });

    test('rejects identity login html even if it contains a csrf field', () {
      const loginHtml = '''
        <html>
          <body>
            <form id="theform">
              <input type="hidden" name="_csrf" value="id-csrf-token" />
              <input id="i_user" name="i_user" value="2023000000" />
              <input id="i_pass" name="i_pass" value="" />
              <div id="sm2publicKey">public-key</div>
            </form>
          </body>
        </html>
      ''';

      expect(looksLikeIdentityLoginPage(loginHtml), isTrue);
      expect(
        isAuthenticatedLearnPage(
          pageUri: Uri.parse(urls.idLogin()),
          pageSource: loginHtml,
        ),
        isFalse,
      );
      expect(
        isAuthenticatedLearnPage(
          pageUri: Uri.parse(urls.learnStudentCourseListPage()),
          pageSource: loginHtml,
        ),
        isFalse,
      );
    });

    test(
      'accepts authenticated learn course pages and extracts csrf token',
      () {
        const learnHtml = '''
        <html>
          <head>
            <script src="/f/wlxt/common/languagejs?lang=zh"></script>
          </head>
          <body>
            <a href="/f/wlxt/index/course/student/?_csrf=learn-csrf-token">课程</a>
          </body>
        </html>
      ''';

        expect(looksLikeIdentityLoginPage(learnHtml), isFalse);
        expect(
          isAuthenticatedLearnPage(
            pageUri: Uri.parse(urls.learnStudentCourseListPage()),
            pageSource: learnHtml,
          ),
          isTrue,
        );
        expect(extractCsrfTokenFromPage(learnHtml), 'learn-csrf-token');
      },
    );
  });
}
