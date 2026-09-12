import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/models.dart';
import 'package:learn_y/core/api/school_list_loader.dart';

void main() {
  test(
    'follows declared numeric-string total and rejects a repeated page',
    () async {
      final offsets = <int?>[];
      final rows = await loadSchoolTable((offset, length) async {
        offsets.add(offset);
        return _page(offset == null ? ['first'] : ['second'], '2');
      });
      expect(rows, ['first', 'second']);
      expect(offsets, [null, 1]);
      await expectLater(
        loadSchoolTable((_, _) async => _page(['first'], '2')),
        throwsA(isA<ApiError>()),
      );
    },
  );

  test(
    'missing rows and an early empty page cannot become a deletion snapshot',
    () async {
      await expectLater(
        loadSchoolTable((_, _) async => {'result': 'success', 'object': {}}),
        throwsA(isA<ApiError>()),
      );
      await expectLater(
        loadSchoolTable(
          (offset, _) async => _page(offset == null ? ['one'] : [], 2),
        ),
        throwsA(isA<ApiError>()),
      );
      expect(await loadSchoolTable((_, _) async => _page([], '0')), isEmpty);
    },
  );

  test(
    'file list expands beyond 200 and stops when the size is sufficient',
    () async {
      final sizes = <int>[];
      final rows = await loadSchoolSizedList((size) async {
        sizes.add(size);
        return {
          'result': 'success',
          'object': List.generate(size < 201 ? size : 201, (i) => i),
        };
      });
      expect(sizes, [200, 400]);
      expect(rows, hasLength(201));
      await expectLater(
        loadSchoolSizedList((_) async => {'result': 'success', 'object': null}),
        throwsA(isA<ApiError>()),
      );
    },
  );
}

Map<String, Object> _page(List<Object> rows, Object total) => {
  'result': 'success',
  'object': {'iTotalDisplayRecords': total, 'aaData': rows},
};
