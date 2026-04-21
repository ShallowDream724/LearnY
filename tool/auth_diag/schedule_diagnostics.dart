import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:learn_y/core/api/enums.dart';
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart' as api;
import 'package:learn_y/core/api/urls.dart' as urls;
import 'package:learn_y/core/api/utils.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';

Future<int> runScheduleDiagnostics(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    stdout.writeln(_CliOptions.usage);
    return 0;
  }

  final capture = _CaptureContext.fromJson(
    jsonDecode(await File(options.capturePath).readAsString())
        as Map<String, dynamic>,
  );

  if (capture.cookies.isEmpty) {
    throw StateError(
      'capture.json does not contain browser cookies; rerun after reaching learn',
    );
  }

  final helper = Learn2018Helper(config: HelperConfig(cookieJar: CookieJar()));
  await _importCookies(helper.cookieJar, capture.cookies);

  final user = await helper.getUserInfo();
  final semester = await helper.getCurrentSemester();
  final resolvedLanguage = helper.getCurrentLanguage();
  final today = _shanghaiToday();
  final days = buildHomeScheduleDays(today, length: options.days);

  final calendarProbe = await _probeCalendar(
    helper: helper,
    startDate: days.first.dateKey,
    endDate: days.last.dateKey,
  );
  final calendarEvents = calendarProbe.events;
  final zhCourses = await helper.getCourseList(semester.id, lang: Language.zh);
  final enCourses = await helper.getCourseList(semester.id, lang: Language.en);

  final calendarSnapshot = buildHomeScheduleSnapshotFromCalendarEvents(
    days: days,
    events: calendarEvents,
    courseIdsByName: _courseIdsByName(zhCourses),
  );
  final zhFallbackSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
    days: days,
    courses: _toDbCourses(zhCourses, semesterId: semester.id),
    semesterStartDate: semester.startDate,
  );
  final enFallbackSnapshot = buildHomeScheduleSnapshotFromCachedCourses(
    days: days,
    courses: _toDbCourses(enCourses, semesterId: semester.id),
    semesterStartDate: semester.startDate,
  );

  final output = <String, dynamic>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'capturePath': options.capturePath,
    'user': {'name': user.name, 'department': user.department},
    'detectedLanguage': resolvedLanguage.value,
    'semester': {
      'id': semester.id,
      'startDate': semester.startDate,
      'endDate': semester.endDate,
      'type': semester.type.value,
    },
    'range': {
      'startDate': days.first.dateKey,
      'endDate': days.last.dateKey,
      'days': [for (final day in days) day.dateKey],
    },
    'calendar': {
      'eventCount': calendarEvents.length,
      'error': calendarProbe.error,
      'rawPreview': calendarProbe.rawPreview,
      'rawStatusCode': calendarProbe.rawStatusCode,
      'rawUri': calendarProbe.rawUri,
      'itemsByDateKey': _countItemsByDateKey(calendarSnapshot, days),
      'samples': [
        for (final event in calendarEvents.take(10))
          {
            'date': event.date,
            'courseName': event.courseName,
            'startTime': event.startTime,
            'endTime': event.endTime,
            'location': event.location,
            'status': event.status,
          },
      ],
    },
    'courseListZh': _summarizeCourseList(
      courses: zhCourses,
      snapshot: zhFallbackSnapshot,
      days: days,
    ),
    'courseListEn': _summarizeCourseList(
      courses: enCourses,
      snapshot: enFallbackSnapshot,
      days: days,
    ),
    'hypothesis': {
      'calendarEmpty': calendarEvents.isEmpty,
      'zhFallbackEmpty': !_hasAnyScheduleItems(zhFallbackSnapshot),
      'enFallbackEmpty': !_hasAnyScheduleItems(enFallbackSnapshot),
    },
  };

  final outputFile = File(options.outputPath);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(output),
  );

  stdout.writeln('[schedule-diag] User: ${user.name} / ${user.department}');
  stdout.writeln(
    '[schedule-diag] Semester: ${semester.id} ${semester.startDate}..${semester.endDate}',
  );
  stdout.writeln(
    '[schedule-diag] Calendar events: ${calendarEvents.length}; '
    'zh fallback items: ${_totalItemCount(zhFallbackSnapshot)}; '
    'en fallback items: ${_totalItemCount(enFallbackSnapshot)}',
  );
  stdout.writeln('[schedule-diag] Output: ${outputFile.path}');
  return 0;
}

Map<String, dynamic> _summarizeCourseList({
  required List<api.CourseInfo> courses,
  required HomeScheduleSnapshot snapshot,
  required List<HomeScheduleDayOption> days,
}) {
  final nonEmptyTimeEntries = courses
      .where((course) => course.timeAndLocation.isNotEmpty)
      .toList(growable: false);

  return {
    'courseCount': courses.length,
    'coursesWithTimeLocation': nonEmptyTimeEntries.length,
    'itemsByDateKey': _countItemsByDateKey(snapshot, days),
    'samples': [
      for (final course in nonEmptyTimeEntries.take(10))
        {
          'name': course.name,
          'chineseName': course.chineseName,
          'englishName': course.englishName,
          'timeAndLocation': course.timeAndLocation
              .map((value) => value?.toString() ?? '')
              .toList(growable: false),
        },
    ],
  };
}

Map<String, int> _countItemsByDateKey(
  HomeScheduleSnapshot snapshot,
  List<HomeScheduleDayOption> days,
) {
  return {for (final day in days) day.dateKey: snapshot.itemsFor(day).length};
}

int _totalItemCount(HomeScheduleSnapshot snapshot) {
  return snapshot.itemsByDateKey.values.fold<int>(
    0,
    (sum, items) => sum + items.length,
  );
}

bool _hasAnyScheduleItems(HomeScheduleSnapshot snapshot) {
  return snapshot.itemsByDateKey.values.any((items) => items.isNotEmpty);
}

Map<String, String> _courseIdsByName(List<api.CourseInfo> courses) {
  final map = <String, String>{};
  for (final course in courses) {
    final key = course.name.trim();
    if (key.isEmpty || map.containsKey(key)) {
      continue;
    }
    map[key] = course.id;
  }
  return map;
}

List<db.Course> _toDbCourses(
  List<api.CourseInfo> courses, {
  required String semesterId,
}) {
  return [
    for (final course in courses)
      db.Course(
        id: course.id,
        name: course.name,
        chineseName: course.chineseName,
        englishName: course.englishName,
        teacherName: course.teacherName,
        teacherNumber: course.teacherNumber,
        courseNumber: course.courseNumber,
        courseIndex: course.courseIndex,
        courseType: course.courseType.value,
        semesterId: semesterId,
        timeAndLocationJson: jsonEncode(course.timeAndLocation),
        sortOrder: 0,
        lastSynced: null,
      ),
  ];
}

DateTime _shanghaiToday() {
  final now = DateTime.now().toUtc().add(const Duration(hours: 8));
  return DateTime(now.year, now.month, now.day);
}

Future<_CalendarProbeResult> _probeCalendar({
  required Learn2018Helper helper,
  required String startDate,
  required String endDate,
}) async {
  try {
    final events = await helper.getCalendar(startDate, endDate);
    return _CalendarProbeResult(events: events);
  } catch (error) {
    final manual = await _probeCalendarRaw(
      helper: helper,
      startDate: startDate,
      endDate: endDate,
    );
    return _CalendarProbeResult(
      events: const [],
      error: error.toString(),
      rawPreview: manual.rawPreview,
      rawStatusCode: manual.statusCode,
      rawUri: manual.uri,
    );
  }
}

Future<_RawCalendarProbeResult> _probeCalendarRaw({
  required Learn2018Helper helper,
  required String startDate,
  required String endDate,
}) async {
  final courseListResp = await helper.dio.get<String>(
    urls.learnStudentCourseListPage(),
  );
  final pageSource = courseListResp.data ?? '';
  final csrfToken = extractCsrfTokenFromPage(pageSource);
  if (csrfToken == null || csrfToken.isEmpty) {
    throw StateError(
      'Failed to extract CSRF token from learn course list page',
    );
  }
  helper.setCSRFToken(csrfToken);

  final ticketResp = await helper.dio.post<dynamic>(
    urls.addCSRFTokenToUrl(urls.registrarTicket(), csrfToken),
    data: FormData.fromMap(urls.registrarTicketFormData()),
  );
  var ticket = ticketResp.data.toString().trim();
  if (ticket.startsWith('"') || ticket.startsWith("'")) {
    ticket = ticket.substring(1, ticket.length - 1);
  }

  await helper.dio.get<dynamic>(urls.registrarAuth(ticket));
  final rawResp = await helper.dio.get<String>(
    urls.addCSRFTokenToUrl(
      urls.registrarCalendar(
        DateFormat('yyyyMMdd').format(DateTime.parse(startDate)),
        DateFormat('yyyyMMdd').format(DateTime.parse(endDate)),
        callbackName: jsonpExtractorName,
      ),
      csrfToken,
    ),
  );

  final rawBody = rawResp.data ?? '';
  final compact = rawBody.replaceAll(RegExp(r'\s+'), ' ').trim();
  final preview = compact.length <= 600 ? compact : compact.substring(0, 600);
  return _RawCalendarProbeResult(
    rawPreview: preview,
    statusCode: rawResp.statusCode,
    uri: rawResp.realUri?.toString(),
  );
}

Future<void> _importCookies(
  CookieJar jar,
  List<_CapturedCookie> capturedCookies,
) async {
  for (final captured in capturedCookies) {
    final normalizedDomain = captured.domain.startsWith('.')
        ? captured.domain.substring(1)
        : captured.domain;
    if (normalizedDomain.isEmpty || captured.name.isEmpty) {
      continue;
    }

    final uri = Uri(
      scheme: 'https',
      host: normalizedDomain,
      path: captured.path.isEmpty ? '/' : captured.path,
    );
    final cookie = Cookie(captured.name, captured.value)
      ..domain = captured.domain
      ..path = captured.path.isEmpty ? '/' : captured.path
      ..httpOnly = captured.httpOnly
      ..secure = captured.secure;

    final expires = captured.expires;
    if (expires != null && expires > 0) {
      cookie.expires = DateTime.fromMillisecondsSinceEpoch(
        (expires * 1000).round(),
        isUtc: true,
      );
    }

    await jar.saveFromResponse(uri, <Cookie>[cookie]);
  }
}

class _CliOptions {
  const _CliOptions({
    required this.capturePath,
    required this.outputPath,
    required this.days,
    required this.showHelp,
  });

  final String capturePath;
  final String outputPath;
  final int days;
  final bool showHelp;

  static const String usage =
      'Usage: --capture <capture.json> --output <summary.json> [--days <n>]';

  static _CliOptions parse(List<String> args) {
    String? capturePath;
    String? outputPath;
    var days = 7;
    var showHelp = false;

    for (var index = 0; index < args.length; index += 1) {
      final arg = args[index];
      switch (arg) {
        case '--capture':
          capturePath = args[++index];
        case '--output':
          outputPath = args[++index];
        case '--days':
          days = int.parse(args[++index]);
        case '--help':
        case '-h':
          showHelp = true;
        default:
          throw ArgumentError('Unknown argument: $arg');
      }
    }

    if (showHelp) {
      return _CliOptions(
        capturePath: '',
        outputPath: '',
        days: days,
        showHelp: true,
      );
    }
    if (capturePath == null || outputPath == null) {
      throw ArgumentError(usage);
    }

    return _CliOptions(
      capturePath: capturePath,
      outputPath: outputPath,
      days: days,
      showHelp: false,
    );
  }
}

class _CaptureContext {
  const _CaptureContext({required this.cookies});

  factory _CaptureContext.fromJson(Map<String, dynamic> json) {
    final rawCookies = json['cookies'] as List<dynamic>? ?? const [];
    return _CaptureContext(
      cookies: rawCookies
          .whereType<Map<String, dynamic>>()
          .map(_CapturedCookie.fromJson)
          .toList(growable: false),
    );
  }

  final List<_CapturedCookie> cookies;
}

class _CapturedCookie {
  const _CapturedCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.expires,
    required this.httpOnly,
    required this.secure,
  });

  factory _CapturedCookie.fromJson(Map<String, dynamic> json) {
    return _CapturedCookie(
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      domain: json['domain']?.toString() ?? '',
      path: json['path']?.toString() ?? '/',
      expires: (json['expires'] as num?)?.toDouble(),
      httpOnly: json['httpOnly'] == true,
      secure: json['secure'] == true,
    );
  }

  final String name;
  final String value;
  final String domain;
  final String path;
  final double? expires;
  final bool httpOnly;
  final bool secure;
}

class _CalendarProbeResult {
  const _CalendarProbeResult({
    required this.events,
    this.error,
    this.rawPreview,
    this.rawStatusCode,
    this.rawUri,
  });

  final List<api.CalendarEvent> events;
  final String? error;
  final String? rawPreview;
  final int? rawStatusCode;
  final String? rawUri;
}

class _RawCalendarProbeResult {
  const _RawCalendarProbeResult({
    required this.rawPreview,
    required this.statusCode,
    required this.uri,
  });

  final String rawPreview;
  final int? statusCode;
  final String? uri;
}
