import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html;
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart';
import 'package:learn_y/core/api/registrar_calendar_api.dart';
import 'package:learn_y/core/auth/credential_vault.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/schedule/schedule_repository.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/sync/sync_operation.dart';
import 'package:learn_y/core/semester/semester_repository.dart';
import 'package:learn_y/core/semester/academic_calendar_catalog.dart';
import 'package:drift/native.dart';
import 'school_read_contract_probe.dart';

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
      final savedCredential = StoredCredential.fromJsonString(
        Platform.environment['LEARNY_PROBE_CREDENTIAL_JSON'],
      );
      final probeUsername = Platform.environment['LEARNY_PROBE_USERNAME'];
      final probePassword = Platform.environment['LEARNY_PROBE_PASSWORD'];
      // Explicit, process-only password probe. An empty fingerprint preserves
      // the server's normal challenge behavior; never invent trusted state.
      final credential =
          savedCredential ??
          (probeUsername != null && probePassword != null
              ? StoredCredential(
                  username: probeUsername,
                  password: probePassword,
                  fingerPrint: '',
                )
              : null);
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
          campusCredentialProvider: credential == null
              ? null
              : () async => Credential(
                  username: credential.username,
                  password: credential.password,
                  fingerPrint: credential.fingerPrint,
                  fingerGenPrint: credential.fingerGenPrint,
                  fingerGenPrint3: credential.fingerGenPrint3,
                  deviceName: credential.deviceName,
                  singleLoginEnabled: credential.singleLoginEnabled,
                ),
          sessionRecoveryHandler: () => helper.attemptSilentSessionRecovery(),
        ),
      );
      addTearDown(() => helper.dio.close(force: true));
      final transport = Platform.environment['LEARNY_PROBE_TRANSPORT'];
      if (transport != null) {
        helper.dio.httpClientAdapter = IOHttpClientAdapter(
          createHttpClient: () =>
              HttpClient()
                ..findProxy = (_) =>
                    transport == 'proxy' ? 'PROXY 127.0.0.1:20808' : 'DIRECT',
        );
      }
      final requests = <Map<String, Object?>>[];
      final courseScores = <String, int>{};
      var passwordPosts = 0;
      final passwordLimit =
          int.tryParse(
            Platform.environment['LEARNY_PROBE_PASSWORD_LIMIT'] ?? '1',
          ) ??
          1;
      helper.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (options.method == 'POST' &&
                options.uri.host == 'id.tsinghua.edu.cn' &&
                options.uri.path == '/do/off/ui/auth/login/check' &&
                ++passwordPosts > passwordLimit) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  type: DioExceptionType.cancel,
                  error: 'Diagnostic password submission limit reached',
                ),
              );
              return;
            }
            handler.next(options);
          },
          onResponse: (response, handler) {
            final location = Uri.tryParse(
              response.headers.value('location') ?? '',
            );
            requests.add({
              'method': response.requestOptions.method,
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
            if (Platform.environment['LEARNY_PROBE_READ_CONTRACTS'] == '1') {
              try {
                final data = response.data is String
                    ? jsonDecode(response.data)
                    : response.data;
                if (data is Map || data is List) {
                  requests.last['shape'] = _shape(data);
                }
                if (response.requestOptions.uri.path.contains(
                      '/loadCourseBySemesterId/',
                    ) &&
                    data is Map) {
                  for (final course
                      in (data['resultList'] as List).whereType<Map>()) {
                    int count(String key) =>
                        int.tryParse(course[key]?.toString() ?? '') ?? 0;
                    courseScores[course['wlkcid'].toString()] =
                        (count('ggs') > 0 ? 1000 : 0) +
                        (count('zls') > 0 ? 100 : 0) +
                        (count('zys') > 0 ? 100 : 0) -
                        count('zys');
                  }
                }
              } catch (_) {}
            }
            if (response.requestOptions.uri.host == 'id.tsinghua.edu.cn' &&
                response.statusCode == 200) {
              final page = html.parse(response.data?.toString() ?? '');
              String destination(String value) {
                final uri = response.requestOptions.uri.resolve(value);
                return '${uri.host}${uri.path}';
              }

              requests.last['identityPage'] = {
                'title': page.querySelector('title')?.text,
                'passwordField':
                    page.querySelector('input[type="password"]') != null,
                'sm2Key': page.querySelector('#sm2publicKey') != null,
                'singleLogin': (response.data ?? '').contains('checkSingle'),
                'forms': page
                    .querySelectorAll('form[action]')
                    .map(
                      (node) => {
                        'action': destination(node.attributes['action']!),
                        'inputs': node.querySelectorAll('input').map((input) {
                          final value = input.attributes['value'] ?? '';
                          return {
                            'name': input.attributes['name'],
                            'type': input.attributes['type'],
                            'valueKind': value.isEmpty
                                ? 'empty'
                                : {
                                    'on',
                                    'off',
                                    'true',
                                    'false',
                                    '0',
                                    '1',
                                  }.contains(value)
                                ? value
                                : 'opaque:${value.length}',
                          };
                        }).toList(),
                      },
                    )
                    .toList(),
                'links': page
                    .querySelectorAll('a[href]')
                    .map((node) => destination(node.attributes['href']!))
                    .toList(),
                'refresh': page
                    .querySelectorAll('meta[http-equiv]')
                    .map((node) => node.attributes['http-equiv'])
                    .toList(),
                'scripts': page
                    .querySelectorAll('script')
                    .map(
                      (node) => node.attributes['src'] == null
                          ? 'inline'
                          : destination(node.attributes['src']!),
                    )
                    .toList(),
              };
            }
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
      final identityUrl = Platform.environment['LEARNY_PROBE_IDENTITY_URL'];
      if (identityUrl != null) {
        await helper.dio.get<String>(
          identityUrl,
          options: Options(
            followRedirects: false,
            responseType: ResponseType.plain,
            validateStatus: (_) => true,
          ),
        );
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(requests));
        return;
      }
      final result = <String, Object?>{};
      if (credential != null &&
          Platform.environment['LEARNY_PROBE_SKIP_CREDENTIAL_LOGIN'] != '1') {
        try {
          await helper.login(
            credential.username,
            credential.password,
            credential.fingerPrint,
            credential.fingerGenPrint,
            credential.fingerGenPrint3,
            credential.deviceName,
            credential.singleLoginEnabled,
          );
          result['credentialRecovery'] = 'success';
        } catch (error) {
          result['credentialRecovery'] = _error(error);
          result['requests'] = requests;
          stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
          return;
        }
      }
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
      if (Platform.environment['LEARNY_PROBE_ROSTER_ONLY'] == '1') {
        final watch = Stopwatch()..start();
        try {
          final courses = await helper.getCourseList(
            (result['learn'] as Map)['semester'] as String,
          );
          result['roster'] = {
            'status': 'success',
            'count': courses.length,
            'metadataLoaded': courses
                .where((course) => course.timeAndLocationLoaded)
                .length,
            'elapsedMs': watch.elapsedMilliseconds,
          };
        } catch (error) {
          result['roster'] = _error(error);
        }
        result['requests'] = requests;
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
        return;
      }
      if (Platform.environment['LEARNY_PROBE_READ_CONTRACTS'] == '1') {
        try {
          result['readContracts'] = await probeSchoolReadContracts(
            helper,
            (result['learn'] as Map)['semester'] as String,
            courseScores,
          );
        } catch (error) {
          result['readContracts'] = _error(error);
        }
        result['requests'] = requests;
        stdout.writeln(const JsonEncoder.withIndent('  ').convert(result));
        return;
      }
      for (final range in [
        if (Platform.environment['LEARNY_PROBE_FULL_TERM'] == '1')
          ('2026-09-14', '2027-01-17')
        else
          ('2026-09-07', '2026-09-13'),
        if (Platform.environment['LEARNY_PROBE_FULL_TERM'] != '1' &&
            Platform.environment['LEARNY_PROBE_SINGLE_RANGE'] != '1')
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
          addTearDown(operation.cancel);
          final calendar = AcademicCalendarCatalog.parse(
            await File('assets/calendar/academic_terms.json').readAsString(),
          ).forAudience(CalendarAudience.undergraduate);
          final repository = ScheduleRepository(
            database: database,
            apiClient: helper,
            academicCalendar: calendar,
          );
          addTearDown(repository.dispose);
          final projected = await repository
              .watch(
                days: buildHomeScheduleDays(DateTime(2026, 9, 14)),
                fetchRemote: true,
                operation: operation,
              )
              .firstWhere(
                (state) => !state.isRefreshing && state.snapshot.hasRoutineData,
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
      final snapshotOutput =
          Platform.environment['LEARNY_PROBE_SNAPSHOT_OUTPUT'];
      if (snapshotOutput != null) await storage.exportTo(snapshotOutput);
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

Object _shape(Object? value, [int depth = 0]) {
  if (value is List) {
    return {
      'count': value.length,
      if (value.firstOrNull is Map)
        'rowKeys': (value.first as Map).keys.toList(),
    };
  }
  if (value is Map) {
    return {
      'keys': value.keys.toList(),
      for (final key in [
        'iTotalRecords',
        'iTotalDisplayRecords',
        'iDisplayStart',
        'iDisplayLength',
        'total',
        'totalCount',
        'records',
      ])
        if (num.tryParse(value[key]?.toString() ?? '') != null)
          key: num.parse(value[key].toString()),
      if (depth < 2)
        for (final key in [
          'object',
          'result',
          'aaData',
          'resultList',
          'resultsList',
          'rows',
        ])
          if (value[key] is Map || value[key] is List)
            key: _shape(value[key], depth + 1),
    };
  }
  return value.runtimeType.toString();
}

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

  Future<void> exportTo(String destination) async {
    if (Directory(destination).absolute.path == Directory(path).absolute.path) {
      throw StateError('Cannot overwrite the source cookie snapshot');
    }
    final directory = await Directory(
      '$destination/ie0_ps1',
    ).create(recursive: true);
    for (final entry in _data.entries) {
      if (!RegExp(r'^[.a-zA-Z0-9_-]+$').hasMatch(entry.key)) continue;
      await File('${directory.path}/${entry.key}').writeAsString(entry.value);
    }
  }
}
