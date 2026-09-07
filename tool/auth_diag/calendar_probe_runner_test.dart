import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart';
import 'package:learn_y/core/api/registrar_calendar_api.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/schedule/schedule_repository.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/sync/sync_operation.dart';
import 'package:learn_y/core/semester/semester_repository.dart';
import 'package:drift/native.dart';

/// Explicit local probe. Cookie changes live in memory and logs contain no payloads.
void main() {
  final cookiePath = Platform.environment['LEARNY_PROBE_COOKIES'];
  if (cookiePath == null) return;
  test(
    'probe current and next week through production calendar API',
    () async {
      final oldDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {};
      addTearDown(() => debugPrint = oldDebugPrint);
      final storage = _SnapshotStorage(cookiePath);
      final persisted = PersistCookieJar(storage: storage);
      final gatewayCapture =
          Platform.environment['LEARNY_PROBE_GATEWAY_COOKIES'];
      if (gatewayCapture != null) {
        final captured =
            jsonDecode(await File(gatewayCapture).readAsString()) as List;
        for (final domain
            in captured
                .cast<Map<String, dynamic>>()
                .map((entry) => entry['domain'] as String)
                .toSet()) {
          await persisted.delete(
            Uri.https(domain.replaceFirst(RegExp(r'^\.'), '')),
            true,
          );
        }
        for (final entry in captured.cast<Map<String, dynamic>>()) {
          final domain = entry['domain'] as String;
          final cookie =
              Cookie(entry['name'] as String, entry['value'] as String)
                ..domain = domain
                ..path = entry['path'] as String
                ..httpOnly = entry['httpOnly'] as bool
                ..secure = entry['secure'] as bool;
          await persisted.saveFromResponse(
            Uri.https(
              domain.replaceFirst(RegExp(r'^\.'), ''),
              cookie.path ?? '/',
            ),
            [cookie],
          );
        }
      }
      late final Learn2018Helper helper;
      helper = Learn2018Helper(
        config: HelperConfig(
          cookieJar: persisted,
          sessionRecoveryHandler: () => helper.attemptSilentSessionRecovery(),
        ),
      );
      addTearDown(() => helper.dio.close(force: true));
      final requests = <Map<String, Object?>>[];
      helper.dio.interceptors.add(
        InterceptorsWrapper(
          onResponse: (response, handler) {
            final location = Uri.tryParse(
              response.headers.value('location') ?? '',
            );
            requests.add({
              'host': response.requestOptions.uri.host,
              'path': response.requestOptions.uri.path.replaceAll(
                RegExp(r';[^/]*'),
                '',
              ),
              'status': response.statusCode,
              'bytes': response.data?.toString().length ?? 0,
              if (location != null && location.hasScheme)
                'redirect':
                    '${location.scheme}://${location.host}${location.path.replaceAll(RegExp(r';[^/]*'), '')}',
            });
            if (response.requestOptions.uri.host == 'webvpn.tsinghua.edu.cn' &&
                response.requestOptions.uri.path.endsWith('/')) {
              final page = html.parse(response.data?.toString() ?? '');
              requests.last['title'] = page.querySelector('title')?.text;
              requests.last['frames'] = page
                  .querySelectorAll('frame[src],iframe[src]')
                  .map(
                    (node) => Uri.tryParse(node.attributes['src'] ?? '')?.path,
                  )
                  .toList();
            }
            handler.next(response);
          },
        ),
      );
      final result = <String, Object?>{};
      try {
        final semester = await helper.getCurrentSemester();
        result['learn'] = {
          'status': 'authenticated',
          'semester': semester.id,
          'start': semester.startDate,
          'end': semester.endDate,
        };
      } catch (error) {
        result['learn'] = _error(error);
      }
      for (final range in [
        ('2026-09-07', '2026-09-13'),
        ('2026-09-14', '2026-09-20'),
        if (Platform.environment['LEARNY_PROBE_EXTENDED'] == '1')
          ('2026-04-20', '2026-04-26'),
      ]) {
        try {
          final events = await helper.getCalendar(range.$1, range.$2);
          final counts = <String, int>{};
          for (final event in events) {
            counts.update(event.date, (value) => value + 1, ifAbsent: () => 1);
          }
          result['${range.$1}/${range.$2}'] = {
            'status': 'success',
            'count': events.length,
            'countsByDate': counts,
          };
        } catch (error) {
          result['${range.$1}/${range.$2}'] = _error(error);
        }
      }
      if (Platform.environment['LEARNY_PROBE_EXTENDED'] == '1') {
        try {
          final graduateEvents = await helper.getCalendar(
            '2026-09-14',
            '2026-09-20',
            graduate: true,
          );
          result['graduateCalendar'] = {'count': graduateEvents.length};
        } catch (error) {
          result['graduateCalendar'] = _error(error);
        }
        try {
          final database = AppDatabase(NativeDatabase.memory());
          addTearDown(database.close);
          await SemesterRepository(
            database: database,
            apiClient: helper,
          ).refreshCatalog();
          if (await database.getSemesterById('2026-2027-1') == null) {
            throw StateError('Autumn semester missing from the server catalog');
          }
          final operation = SyncOperation();
          final projected =
              await ScheduleRepository(database: database, apiClient: helper)
                  .watch(
                    days: buildHomeScheduleDays(DateTime(2026, 9, 14)),
                    fetchRemote: true,
                    operation: operation,
                  )
                  .firstWhere(
                    (state) =>
                        !state.isRefreshing && state.snapshot.hasRoutineData,
                  );
          final courses = await database.getCoursesBySemester('2026-2027-1');
          result['fallLearnCourses'] = {
            'count': courses.length,
            'withSchedule': courses
                .where(
                  (course) => (jsonDecode(course.timeAndLocationJson) as List)
                      .isNotEmpty,
                )
                .length,
          };
          result['fallProductSchedule'] = {
            'countsByDate': {
              for (final day in projected.snapshot.days)
                day.dateKey: projected.snapshot.itemsFor(day).length,
            },
            'unscheduled': projected.snapshot.unscheduledCourses.length,
            'estimated': projected.snapshot.hasEstimatedItems,
          };
        } catch (error) {
          result['fallProductSchedule'] = _error(error);
        }
      }
      result['requests'] = requests;
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Map<String, Object?> _error(Object error) => {
  'status': 'error',
  'type': error.runtimeType.toString(),
  if (error is ApiError) 'reason': error.reason.name,
  if (error is RegistrarException) 'reason': error.failure.name,
  if (error is DioException) 'reason': error.type.name,
};

class _SnapshotStorage implements Storage {
  _SnapshotStorage(this.path);
  final String path;
  final _data = <String, String>{};
  @override
  Future<void> init(bool persistSession, bool ignoreExpires) async {
    final dir = Directory(
      '$path/ie${ignoreExpires ? 1 : 0}_ps${persistSession ? 1 : 0}',
    );
    if (!await dir.exists()) {
      throw StateError('Cookie directory does not exist');
    }
    await for (final entry in dir.list()) {
      if (entry is File) {
        _data[entry.uri.pathSegments.last] = await entry.readAsString();
      }
    }
  }

  @override
  Future<String?> read(String key) async => _data[key];
  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll(List<String> keys) async {
    _data.clear();
  }
}
