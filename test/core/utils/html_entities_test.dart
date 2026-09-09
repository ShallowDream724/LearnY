import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/utils.dart';

void main() {
  test('decodes school titles with named and numeric HTML entities', () {
    expect(decodeHTML('PDE第一次作业&mdash;&mdash;傅里叶变换部分'), 'PDE第一次作业——傅里叶变换部分');
    expect(
      decodeHTML('&alpha; &le; &#8804; &#x1D6FC; &nbsp; &copy;'),
      'α ≤ ≤ 𝛼   ©',
    );
  });

  test('preserves literal markup, unknown names and one encoding layer', () {
    expect(
      decodeHTML('vector<T> &lt;T&gt; &amp;lt; &unknown;'),
      'vector<T> <T> &lt; &unknown;',
    );
    expect(decodeHTML('&#0; &#x110000;'), '\uFFFD \uFFFD');
    expect(decodeHTML(null), '');
  });
}
