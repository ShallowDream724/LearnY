import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../core/api/enums.dart';
import '../core/api/learn_api.dart';
import '../core/api/models.dart' as api;
import 'demo_data.dart';

enum DemoNetwork { normal, offline, slow }

/// Rejects accidental new Dart HTTP clients, including helpers outside providers.
class DemoHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      throw const SocketException('Network access is disabled in the demo');
}

class DemoLearnApi extends Learn2018Helper {
  DemoLearnApi(
    this.data, {
    required CookieJar cookieJar,
    this.network = DemoNetwork.normal,
  }) : super(config: HelperConfig(cookieJar: cookieJar)) {
    dio.httpClientAdapter = _DemoFileAdapter(this);
  }

  final DemoData data;
  DemoNetwork network;

  Future<void> waitForNetwork() async {
    if (network == DemoNetwork.slow) {
      await Future<void>.delayed(const Duration(seconds: 2));
    }
    if (network == DemoNetwork.offline) {
      throw DioException(
        requestOptions: RequestOptions(path: 'demo://offline'),
        type: DioExceptionType.connectionError,
      );
    }
  }

  @override
  Future<List<String>> getSemesterIdList() async {
    await waitForNetwork();
    return data.semesters.map((semester) => semester.id).toList();
  }

  @override
  Future<api.SemesterInfo> getCurrentSemester() async {
    await waitForNetwork();
    return data.semesters.first;
  }

  @override
  Future<List<api.CourseInfo>> getCourseList(
    String semesterID, {
    CourseType courseType = CourseType.student,
    Language? lang,
  }) async {
    await waitForNetwork();
    return List.of(data.courses[semesterID] ?? []);
  }

  @override
  Future<List<api.Homework>> getHomeworkList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    await waitForNetwork();
    return List.of(data.homeworks[courseID] ?? []);
  }

  @override
  Future<List<api.Notification>> getNotificationList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    await waitForNetwork();
    return List.of(data.notifications[courseID] ?? []);
  }

  @override
  Future<List<api.CourseFile>> getFileList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    await waitForNetwork();
    return List.of(data.files[courseID] ?? []);
  }

  @override
  Future<api.UserInfo> getUserInfo([
    CourseType courseType = CourseType.student,
  ]) async {
    await waitForNetwork();
    return const api.UserInfo(name: DemoData.username, department: '计算机科学与技术系');
  }

  @override
  Future<List<api.CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) async {
    await waitForNetwork();
    final start = DateTime.parse(startDate.replaceAll('/', '-'));
    final end = DateTime.parse(endDate.replaceAll('/', '-'));
    final courses = data.courses[data.officialSemesterId]!;
    return [
      for (
        var date = start;
        !date.isAfter(end);
        date = date.add(const Duration(days: 1))
      )
        if (date.weekday <= 4)
          api.CalendarEvent(
            location: '六教 6A201',
            status: '',
            startTime: '08:00',
            endTime: '09:35',
            date: DemoData.timestamp(date).substring(0, 10),
            courseName: courses[date.weekday - 1].name,
          ),
    ];
  }

  @override
  Future<bool> attemptSilentSessionRecovery() async {
    await waitForNetwork();
    return true;
  }

  @override
  Future<void> login([
    String? username,
    String? password,
    String? fingerPrint,
    String? fingerGenPrint,
    String? fingerGenPrint3,
    String? deviceName,
    bool singleLoginEnabled = false,
  ]) => waitForNetwork();

  @override
  Future<void> loginWithTicket(String ticket) => waitForNetwork();

  @override
  Future<void> logout() async {}

  @override
  Future<void> submitHomework(
    String id, {
    String content = '',
    String? attachmentPath,
    String? attachmentName,
    bool removeAttachment = false,
  }) async {
    await waitForNetwork();
    if (attachmentPath != null) {
      throw UnsupportedError('示例环境仅支持正文提交');
    }
    for (final entries in data.homeworks.values) {
      final index = entries.indexWhere((homework) => homework.id == id);
      if (index < 0) continue;
      final previous = entries[index];
      entries[index] = api.Homework(
        id: previous.id,
        studentHomeworkId: previous.id,
        baseId: previous.baseId,
        title: previous.title,
        deadline: previous.deadline,
        url: '',
        submitUrl: '',
        completionType: previous.completionType,
        submissionType: previous.submissionType,
        isLateSubmission: DateTime.parse(
          previous.deadline,
        ).isBefore(DateTime.now()),
        submitted: true,
        graded: false,
        isFavorite: previous.isFavorite,
        description: previous.description,
        submittedContent: content,
        submitTime: DemoData.timestamp(DateTime.now()),
      );
      return;
    }
    throw StateError('Demo homework does not exist: $id');
  }
}

/// All transport requests are handled here; unknown URLs fail closed.
class _DemoFileAdapter implements HttpClientAdapter {
  _DemoFileAdapter(this.apiClient);
  final DemoLearnApi apiClient;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await apiClient.waitForNetwork();
    final uri = options.uri;
    final content =
        uri.host == 'demo.learny.invalid' &&
            uri.pathSegments.length == 2 &&
            uri.pathSegments.first == 'files'
        ? apiClient.data.fileContents[uri.pathSegments.last]
        : null;
    if (content == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'External requests are disabled in the demo',
      );
    }
    final bytes = utf8.encode(content);
    return ResponseBody.fromBytes(
      bytes,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain; charset=utf-8'],
        Headers.contentLengthHeader: ['${bytes.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
