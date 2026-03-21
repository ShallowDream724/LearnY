import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/utils.dart';

void main() {
  group('extractJSONPResult', () {
    test('parses the classic JSONP wrapper', () {
      final result =
          extractJSONPResult(
                'thu_learn_lib_jsonp_extractor([{"nr":"课程","kssj":"08:00"}])',
              )
              as List;

      expect(result, hasLength(1));
      expect(result.first['nr'], '课程');
      expect(result.first['kssj'], '08:00');
    });

    test('parses wrapped JSONP with leading noise', () {
      final result =
          extractJSONPResult(
                'try{thu_learn_lib_jsonp_extractor([{"nr":"课程"}]);}catch(e){}',
              )
              as List;

      expect(result, hasLength(1));
      expect(result.first['nr'], '课程');
    });

    test('parses raw json arrays as a fallback', () {
      final result = extractJSONPResult('[{"nr":"课程","dd":"六教"}]') as List;

      expect(result, hasLength(1));
      expect(result.first['dd'], '六教');
    });
  });
}
