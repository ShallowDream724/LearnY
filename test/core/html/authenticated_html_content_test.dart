import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/html/authenticated_html_content.dart';

void main() {
  group('authenticated html helpers', () {
    test('treats image-only html as visible content', () {
      expect(
        hasVisibleHtmlContent('<p><img src="/attachment/demo.png" /></p>'),
        isTrue,
      );
    });

    test('strips tags but preserves readable line breaks', () {
      expect(
        stripHtmlToPlainText('<p>第一段</p><p>第二段<br>换行</p>'),
        '第一段\n\n第二段\n换行',
      );
    });

    test('filters placeholder-only content', () {
      expect(
        hasVisibleHtmlContent(
          '<p>&gt;</p>',
          placeholderOnly: RegExp(r'^[\s\u00A0\u200B>\-–—→➡➔➜➝]+$'),
        ),
        isFalse,
      );
    });
  });
}
