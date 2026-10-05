import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/api/learn_api.dart';

void main() {
  test(
    'course metadata is bounded, ordered and tolerant of a partial failure',
    () async {
      final helper = Learn2018Helper()..setCSRFToken('test-token');
      addTearDown(() => helper.dio.close(force: true));
      final gates = List.generate(5, (_) => Completer<void>());
      final firstWave = Completer<void>();
      final fourthStarted = Completer<void>();
      final started = <int>[];
      var active = 0;
      var peak = 0;
      helper.dio.httpClientAdapter = _Adapter((request) async {
        if (request.uri.path.contains('loadCourseBySemesterId')) {
          return _json({
            'message': 'success',
            'resultList': [
              for (var i = 0; i < 5; i++) {'wlkcid': '$i', 'kcm': 'Course $i'},
            ],
          });
        }
        final index = int.parse(request.uri.queryParameters['id']!);
        started.add(index);
        active++;
        if (active > peak) peak = active;
        if (started.length == 3) firstWave.complete();
        if (index == 3) fourthStarted.complete();
        try {
          await gates[index].future;
          if (index == 2) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.receiveTimeout,
            );
          }
          return _json(['time-$index']);
        } finally {
          active--;
        }
      });
      final request = helper.getCourseList('2026-2027-1');
      await firstWave.future;
      expect(started, [0, 1, 2]);
      gates[1].complete();
      await fourthStarted.future;
      expect(gates[0].isCompleted, isFalse);
      for (final i in [4, 3, 2, 0]) {
        gates[i].complete();
      }
      final courses = await request;
      expect(peak, 3);
      expect(courses.map((course) => course.id), ['0', '1', '2', '3', '4']);
      expect(courses[2].timeAndLocationLoaded, isFalse);
      expect(courses[2].timeAndLocation, isEmpty);
      expect(courses[4].timeAndLocationLoaded, isTrue);
      expect(courses[4].timeAndLocation, ['time-4']);
    },
  );
}

ResponseBody _json(Object value) => ResponseBody.fromString(
  jsonEncode(value),
  200,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);
  final Future<ResponseBody> Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}
