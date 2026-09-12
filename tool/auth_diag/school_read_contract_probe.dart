import 'dart:typed_data';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html;
import 'package:learn_y/core/api/learn_api.dart';
import 'package:learn_y/core/api/models.dart' as models;
import 'package:learn_y/core/api/urls.dart' as urls;
import 'package:learn_y/core/api/enums.dart';
import 'dart:convert';

/// Bounded reads only: never submits homework, changes read state or favorites.
Future<Map<String, Object?>> probeSchoolReadContracts(
  Learn2018Helper api,
  String currentSemester,
  Map<String, int> courseScores,
) async {
  final ids = await api.getSemesterIdList();
  final older =
      ids
          .where((id) => id.endsWith('-2') && id.compareTo(currentSemester) < 0)
          .toList()
        ..sort();
  final report = <String, Object?>{'semesterIds': ids, 'samples': <Object?>[]};
  final samples = report['samples'] as List<Object?>;
  for (final semester in [
    if (Platform.environment['LEARNY_PROBE_DENSE_SAMPLE'] != '1')
      currentSemester,
    if (older.isNotEmpty) older.last,
  ]) {
    final courses = await api.getCourseList(semester);
    final sample = <String, Object?>{
      'semester': semester,
      'courseCount': courses.length,
      'scheduleMetadataLoaded': courses
          .where((course) => course.timeAndLocationLoaded)
          .length,
    };
    samples.add(sample);
    if (courses.isEmpty) continue;
    final ranked = [...courses]
      ..sort(
        (a, b) => (courseScores[b.id] ?? 0).compareTo(courseScores[a.id] ?? 0),
      );
    final course = ranked.first;
    final notifications = await api.getNotificationList(course.id);
    final homework = await api.getHomeworkList(course.id);
    final files = await api.getFileList(course.id);
    if (Platform.environment['LEARNY_PROBE_PAGINATION'] == '1') {
      final smallFiles = await api.dio.getUri<dynamic>(
        withLearnAssetCsrf(
          Uri.parse(
            urls.learnFileList(course.id, CourseType.student),
          ).replace(queryParameters: {'wlkcid': course.id, 'size': '1'}),
          api.getCSRFToken(),
        ),
      );
      final smallNotices = await api.dio.postUri<dynamic>(
        withLearnAssetCsrf(
          Uri.parse(urls.learnNotificationList(CourseType.student, false)),
          api.getCSRFToken(),
        ),
        data: FormData.fromMap({
          'aoData': jsonEncode([
            {'name': 'wlkcid', 'value': course.id},
            {'name': 'iDisplayStart', 'value': 0},
            {'name': 'iDisplayLength', 'value': 1},
          ]),
        }),
      );
      dynamic decoded(dynamic value) =>
          value is String ? jsonDecode(value) : value;
      sample['pagination'] = {
        'fileSizeOneCount': (decoded(smallFiles.data)['object'] as List).length,
        'notificationLengthOneCount':
            (decoded(smallNotices.data)['object']['aaData'] as List).length,
        'notificationDeclaredTotal': decoded(
          smallNotices.data,
        )['object']['iTotalDisplayRecords'],
      };
    }
    sample.addAll({
      'notifications': notifications.length,
      'uniqueNotifications': notifications
          .map((item) => item.id)
          .toSet()
          .length,
      'notificationAttachments': notifications
          .where((item) => item.attachment != null)
          .length,
      'homework': homework.length,
      'uniqueHomework': homework.map((item) => item.id).toSet().length,
      'homeworkDescriptions': homework
          .where((item) => item.description?.isNotEmpty == true)
          .length,
      'homeworkFeedback': homework
          .where((item) => item.gradeContent?.isNotEmpty == true)
          .length,
      'files': files.length,
      'uniqueFiles': files.map((item) => item.id).toSet().length,
    });
    final attachments = <models.RemoteFile>[
      for (final item in notifications)
        if (item.attachment != null) item.attachment!,
      for (final item in homework)
        if (item.attachment != null) item.attachment!,
    ];
    final download =
        files.firstOrNull?.downloadUrl ?? attachments.firstOrNull?.downloadUrl;
    if (download != null)
      sample['download'] = await _sampleAsset(api, Uri.parse(download));
    final markup = [
      ...notifications.map((item) => item.content),
      ...homework.expand(
        (item) => [
          item.description ?? '',
          item.gradeContent ?? '',
          item.answerContent ?? '',
        ],
      ),
    ];
    for (final body in markup) {
      final src = html.parse(body).querySelector('img[src]')?.attributes['src'];
      if (src == null || src.startsWith('data:')) continue;
      final uri = Uri.parse('https://learn.tsinghua.edu.cn/').resolve(src);
      if (uri.scheme != 'https' || uri.host != 'learn.tsinghua.edu.cn')
        continue;
      sample['inlineImage'] = await _sampleAsset(api, uri);
      break;
    }
  }
  return report;
}

Future<Map<String, Object?>> _sampleAsset(Learn2018Helper api, Uri uri) async {
  final response = await api.dio.getUri<ResponseBody>(
    uri,
    options: Options(
      responseType: ResponseType.stream,
      headers: {'Range': 'bytes=0-4095'},
      validateStatus: (_) => true,
    ),
  );
  final prefix = BytesBuilder(copy: false);
  await for (final bytes in response.data!.stream) {
    final remaining = 4096 - prefix.length;
    prefix.add(bytes.length > remaining ? bytes.sublist(0, remaining) : bytes);
    if (prefix.length >= 4096) break;
  }
  final bytes = prefix.takeBytes();
  return {
    'status': response.statusCode,
    'type': response.headers.value('content-type'),
    'range': response.headers.value('content-range'),
    'receivedPrefixBytes': bytes.length,
    'pdf': bytes.length >= 4 && String.fromCharCodes(bytes.take(4)) == '%PDF',
    'zip': bytes.length >= 2 && bytes[0] == 0x50 && bytes[1] == 0x4b,
    'finalHost': response.realUri.host,
  };
}
