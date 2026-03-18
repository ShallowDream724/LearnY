/// Core API client — 1:1 port of thu-learn-lib Learn2018Helper.
///
/// Uses [Dio] for HTTP + [cookie_jar] for cookies + [html] for HTML parsing.
/// SM2 encryption for login is handled via [pointycastle].
///
/// Usage:
/// ```dart
/// final helper = Learn2018Helper(
///   provider: () => Credential(username: 'u', password: 'p', fingerPrint: 'fp'),
/// );
/// await helper.login();
/// final user = await helper.getUserInfo();
/// ```
library;

import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;

import 'enums.dart';
import 'models.dart';
import 'urls.dart' as urls;
import 'utils.dart';

// ---------------------------------------------------------------------------
// Credential
// ---------------------------------------------------------------------------

class Credential {
  final String? username;
  final String? password;
  final String? fingerPrint;
  final String? fingerGenPrint;
  final String? fingerGenPrint3;

  const Credential({
    this.username,
    this.password,
    this.fingerPrint,
    this.fingerGenPrint,
    this.fingerGenPrint3,
  });
}

typedef CredentialProvider = Future<Credential> Function();

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

class HelperConfig {
  final CredentialProvider? provider;
  final CookieJar? cookieJar;
  final bool generatePreviewUrlForFirstPage;

  const HelperConfig({
    this.provider,
    this.cookieJar,
    this.generatePreviewUrlForFirstPage = true,
  });
}

// ---------------------------------------------------------------------------
// Learn2018Helper
// ---------------------------------------------------------------------------

class Learn2018Helper {
  final CredentialProvider? _provider;
  final CookieJar _cookieJar;
  final Dio _dio;
  final bool previewFirstPage;

  String _csrfToken = '';
  Language _lang = Language.zh;

  /// Expose Dio instance for the login screen's cookie bridge.
  /// The login intercepts the SSO ticket and needs Dio to consume it
  /// so that session cookies are captured by Dio's CookieManager.
  Dio get dio => _dio;

  /// Expose CookieJar for manual cookie injection (fallback path).
  CookieJar get cookieJar => _cookieJar;

  // -------------------------------------------------------------------
  // Constructor
  // -------------------------------------------------------------------

  Learn2018Helper({HelperConfig? config})
      : _provider = config?.provider,
        _cookieJar = config?.cookieJar ?? CookieJar(),
        previewFirstPage =
            config?.generatePreviewUrlForFirstPage ?? true,
        _dio = Dio(BaseOptions(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 400,
          responseType: ResponseType.plain,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(CookieManager(_cookieJar));
    // Redirect interceptor: follow redirects manually so cookies are tracked.
    _dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) async {
        if (response.statusCode != null &&
            response.statusCode! >= 300 &&
            response.statusCode! < 400) {
          final location = response.headers.value('location');
          if (location != null) {
            final redirected = await _dio.get(location);
            handler.resolve(redirected);
            return;
          }
        }
        handler.next(response);
      },
    ));
  }

  // -------------------------------------------------------------------
  // CSRF Token getter / setter
  // -------------------------------------------------------------------

  String getCSRFToken() => _csrfToken;
  void setCSRFToken(String token) => _csrfToken = token;

  // -------------------------------------------------------------------
  // Internal fetch helpers
  // -------------------------------------------------------------------

  bool _isLoginTimeout(Response resp) {
    final url = resp.realUri.toString();
    return url.contains('login_timeout') || resp.statusCode == 403;
  }

  /// Fetch wrapper with automatic re-login on session timeout.
  Future<Response> _myFetch(
    String url, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    final opts = Options(
      method: method,
      headers: headers,
      responseType: responseType,
    );

    Future<Response> doFetch() async {
      return _dio.request(url, data: data, options: opts);
    }

    final resp = await doFetch();
    if (_isLoginTimeout(resp)) {
      if (_provider != null) {
        await login();
        final retryResp = await doFetch();
        if (_isLoginTimeout(retryResp)) {
          throw const ApiError(reason: FailReason.notLoggedIn);
        }
        if (retryResp.statusCode != 200) {
          throw ApiError(
            reason: FailReason.unexpectedStatus,
            extra: {
              'code': retryResp.statusCode,
              'text': retryResp.statusMessage,
            },
          );
        }
        return retryResp;
      }
      throw const ApiError(reason: FailReason.notLoggedIn);
    }
    return resp;
  }

  /// Fetch with CSRF token attached as a query parameter.
  Future<Response> _myFetchWithToken(
    String url, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? headers,
    ResponseType? responseType,
  }) async {
    if (_csrfToken.isEmpty) {
      await login();
    }
    return _myFetch(
      urls.addCSRFTokenToUrl(url, _csrfToken),
      method: method,
      data: data,
      headers: headers,
      responseType: responseType,
    );
  }

  // -------------------------------------------------------------------
  // JSON helpers
  // -------------------------------------------------------------------

  Future<dynamic> _fetchJson(
    String url, {
    String method = 'GET',
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    final resp = await _myFetchWithToken(
      url,
      method: method,
      data: data,
      headers: headers,
    );
    return jsonDecode(resp.data.toString());
  }

  Future<String> _fetchText(
    String url, {
    String method = 'GET',
    dynamic data,
  }) async {
    final resp = await _myFetchWithToken(url, method: method, data: data);
    return resp.data.toString();
  }

  // -------------------------------------------------------------------
  // getRoamingTicket
  // -------------------------------------------------------------------

  /// Gets a roaming ticket from id.tsinghua.edu.cn.
  ///
  /// The login uses SM2 encryption for the password. We construct the
  /// encrypted password as `'04' + sm2Encrypt(password, publicKey)`.
  Future<String> getRoamingTicket(
    String username,
    String password,
    String fingerPrint, {
    String fingerGenPrint = '',
    String fingerGenPrint3 = '',
  }) async {
    // Clear JSESSIONID to ensure fresh login
    try {
      final uri = Uri.parse(urls.idPrefix);
      await _cookieJar.delete(uri);
    } catch (err) {
      throw ApiError(
        reason: FailReason.errorSettingCookies,
        extra: err,
      );
    }

    try {
      // 1. Get the login form page to extract sm2 public key
      final loginResp = await _dio.get(urls.idLogin());
      final doc = html_parser.parse(loginResp.data.toString());
      final sm2PublicKeyEl = doc.getElementById('sm2publicKey');
      final sm2PublicKey = sm2PublicKeyEl?.text.trim() ?? '';

      // 2. Encrypt password with SM2
      final encryptedPassword = _sm2Encrypt(password, sm2PublicKey);

      // 3. POST login form
      final formData = FormData.fromMap({
        'i_user': username,
        'i_pass': '04$encryptedPassword',
        'singleLogin': 'on',
        'fingerPrint': fingerPrint,
        'fingerGenPrint': fingerGenPrint,
        'fingerGenPrint3': fingerGenPrint3,
        'i_captcha': '',
      });

      final checkResp = await _dio.post(
        urls.idLoginCheck(),
        data: formData,
        options: Options(
          followRedirects: false,
          validateStatus: (s) => s != null && s < 500,
        ),
      );

      // 4. Extract ticket from the redirect anchor
      final respBody = checkResp.data.toString();
      final doc2 = html_parser.parse(respBody);
      final anchor = doc2.querySelector('a');
      final redirectUrl = anchor?.attributes['href'] ?? '';
      final ticket = redirectUrl.split('=').last;

      return ticket;
    } catch (err) {
      if (err is ApiError) rethrow;
      throw ApiError(
        reason: FailReason.errorFetchFromId,
        extra: err,
      );
    }
  }

  // -------------------------------------------------------------------
  // login
  // -------------------------------------------------------------------

  /// Login to learn.tsinghua.edu.cn.
  ///
  /// If [username], [password], or [fingerPrint] are not provided,
  /// they will be fetched from the [CredentialProvider].
  Future<void> login([
    String? username,
    String? password,
    String? fingerPrint,
    String? fingerGenPrint,
    String? fingerGenPrint3,
  ]) async {
    if (username == null || password == null || fingerPrint == null) {
      if (_provider == null) {
        throw const ApiError(reason: FailReason.noCredential);
      }
      final cred = await _provider!();
      username = cred.username;
      password = cred.password;
      fingerPrint = cred.fingerPrint;
      fingerGenPrint = cred.fingerGenPrint;
      fingerGenPrint3 = cred.fingerGenPrint3;
      if (username == null || password == null || fingerPrint == null) {
        throw const ApiError(reason: FailReason.noCredential);
      }
    }

    // Get roaming ticket
    final ticket = await getRoamingTicket(
      username,
      password,
      fingerPrint,
      fingerGenPrint: fingerGenPrint ?? '',
      fingerGenPrint3: fingerGenPrint3 ?? '',
    );

    // Roam to learn
    final loginResp = await _dio.get(
      urls.learnAuthRoam(ticket),
      options: Options(
        followRedirects: true,
        validateStatus: (s) => s != null && s < 400,
      ),
    );
    if (loginResp.statusCode != 200) {
      throw const ApiError(reason: FailReason.errorRoaming);
    }

    // Extract CSRF token from student course list page
    final courseListResp = await _dio.get(urls.learnStudentCourseListPage());
    final pageSource = courseListResp.data.toString();

    final tokenRegex = RegExp(r'&_csrf=(\S*)"', multiLine: true);
    final tokenMatches = tokenRegex.allMatches(pageSource).toList();
    if (tokenMatches.isEmpty) {
      throw const ApiError(
        reason: FailReason.invalidResponse,
        extra: 'cannot fetch CSRF token from source',
      );
    }
    _csrfToken = tokenMatches[0].group(1)!;

    // Extract current language
    final langRegex =
        RegExp(r'<script src="/f/wlxt/common/languagejs\?lang=(zh|en)"></script>');
    final langMatches = langRegex.allMatches(pageSource).toList();
    if (langMatches.isNotEmpty) {
      _lang = langMatches[0].group(1) == 'en' ? Language.en : Language.zh;
    }
  }

  // -------------------------------------------------------------------
  // logout
  // -------------------------------------------------------------------

  Future<void> logout() async {
    await _dio.post(urls.learnLogout());
  }

  // -------------------------------------------------------------------
  // getUserInfo
  // -------------------------------------------------------------------

  Future<UserInfo> getUserInfo([CourseType courseType = CourseType.student]) async {
    final html = await _fetchText(urls.learnHomepage(courseType));
    final doc = html_parser.parse(html);

    final name = doc.querySelector('a.user-log')?.text.trim() ?? '';
    final department =
        doc.querySelector('.fl.up-img-info p:nth-child(2) label')?.text.trim() ?? '';

    return UserInfo(name: name, department: department);
  }

  // -------------------------------------------------------------------
  // getCalendar
  // -------------------------------------------------------------------

  Future<List<CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  }) async {
    // Get registrar ticket
    final ticketResp = await _myFetchWithToken(
      urls.registrarTicket(),
      method: 'POST',
      data: FormData.fromMap(urls.registrarTicketFormData()),
    );
    var ticket = ticketResp.data.toString();
    // Remove surrounding quotes
    if (ticket.startsWith('"') || ticket.startsWith("'")) {
      ticket = ticket.substring(1, ticket.length - 1);
    }

    // Auth with registrar
    await _myFetch(urls.registrarAuth(ticket));

    // Fetch calendar data
    final resp = await _myFetchWithToken(urls.registrarCalendar(
      startDate,
      endDate,
      graduate: graduate,
      callbackName: jsonpExtractorName,
    ));
    if (resp.statusCode != 200) {
      throw const ApiError(reason: FailReason.invalidResponse);
    }

    final result = extractJSONPResult(resp.data.toString()) as List;
    return result
        .map((i) => CalendarEvent(
              location: i['dd']?.toString() ?? '',
              status: i['fl']?.toString() ?? '',
              startTime: i['kssj']?.toString() ?? '',
              endTime: i['jssj']?.toString() ?? '',
              date: i['nq']?.toString() ?? '',
              courseName: i['nr']?.toString() ?? '',
            ))
        .toList();
  }

  // -------------------------------------------------------------------
  // getSemesterIdList
  // -------------------------------------------------------------------

  Future<List<String>> getSemesterIdList() async {
    final json = await _fetchJson(urls.learnSemesterList());
    if (json is! List) {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    // Sometimes web learning returns null entries
    return json.whereType<String>().toList();
  }

  // -------------------------------------------------------------------
  // getCurrentSemester
  // -------------------------------------------------------------------

  Future<SemesterInfo> getCurrentSemester() async {
    final json = await _fetchJson(urls.learnCurrentSemester());
    if (json['message'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final r = json['result'];
    final xnxq = r['xnxq'].toString();
    return SemesterInfo(
      id: r['id'].toString(),
      startDate: r['kssj']?.toString() ?? '',
      endDate: r['jssj']?.toString() ?? '',
      startYear: int.parse(xnxq.substring(0, 4)),
      endYear: int.parse(xnxq.substring(5, 9)),
      type: parseSemesterType(int.parse(xnxq.substring(10, 11))),
    );
  }

  // -------------------------------------------------------------------
  // getCourseList
  // -------------------------------------------------------------------

  Future<List<CourseInfo>> getCourseList(
    String semesterID, {
    CourseType courseType = CourseType.student,
    Language? lang,
  }) async {
    lang ??= _lang;
    final json = await _fetchJson(
        urls.learnCourseList(semesterID, courseType, lang));

    if (json['message'] != 'success' || json['resultList'] is! List) {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }

    final result = json['resultList'] as List;
    final courses = <CourseInfo>[];

    for (final c in result) {
      List<dynamic> timeAndLocation = [];
      try {
        final tlJson = await _fetchJson(
            urls.learnCourseTimeLocation(c['wlkcid'].toString()));
        if (tlJson is List) timeAndLocation = tlJson;
      } catch (_) {
        // Non-blocking: some courses don't have time/location
      }

      courses.add(CourseInfo(
        id: c['wlkcid'].toString(),
        name: decodeHTML(c['zywkcm']?.toString()),
        chineseName: decodeHTML(c['kcm']?.toString()),
        englishName: decodeHTML(c['ywkcm']?.toString()),
        timeAndLocation: timeAndLocation,
        url: urls.learnCoursePage(c['wlkcid'].toString(), courseType),
        teacherName: c['jsm']?.toString() ?? '',
        teacherNumber: c['jsh']?.toString() ?? '',
        courseNumber: c['kch']?.toString() ?? '',
        courseIndex: _toInt(c['kxh']),
        courseType: courseType,
      ));
    }
    return courses;
  }

  // -------------------------------------------------------------------
  // getAllContents
  // -------------------------------------------------------------------

  Future<Map<String, List<dynamic>>> getAllContents(
    List<String> courseIDs,
    ContentType type, {
    CourseType courseType = CourseType.student,
    bool allowFailure = false,
  }) async {
    final contents = <String, List<dynamic>>{};
    final errors = <String, Object>{};

    await Future.wait(courseIDs.map((id) async {
      try {
        switch (type) {
          case ContentType.notification:
            contents[id] = await getNotificationList(id, courseType: courseType);
          case ContentType.file:
            contents[id] = await getFileList(id, courseType: courseType);
          case ContentType.homework:
            contents[id] = await getHomeworkList(id, courseType: courseType);
          case ContentType.discussion:
            contents[id] = await getDiscussionList(id, courseType: courseType);
          case ContentType.question:
            contents[id] = await getAnsweredQuestionList(id, courseType: courseType);
          case ContentType.questionnaire:
            contents[id] = await getQuestionnaireList(id);
        }
      } catch (e) {
        if (!allowFailure) {
          errors[id] = e;
        }
      }
    }));

    if (errors.isNotEmpty) {
      throw ApiError(
        reason: FailReason.invalidResponse,
        extra: {'errors': errors},
      );
    }
    return contents;
  }

  // -------------------------------------------------------------------
  // getNotificationList
  // -------------------------------------------------------------------

  Future<List<Notification>> getNotificationList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    final unexpired =
        await _getNotificationListKind(courseID, courseType, false);
    final expired =
        await _getNotificationListKind(courseID, courseType, true);
    return [...unexpired, ...expired];
  }

  Future<List<Notification>> _getNotificationListKind(
    String courseID,
    CourseType courseType,
    bool expired,
  ) async {
    final json = await _fetchJson(
      urls.learnNotificationList(courseType, expired),
      method: 'POST',
      data: FormData.fromMap(urls.learnPageListFormData(courseID: courseID)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }

    final result = (json['object']?['aaData'] ??
            json['object']?['resultsList'] ??
            []) as List;

    final notifications = <Notification>[];
    for (final n in result) {
      var notification = Notification(
        id: n['ggid'].toString(),
        content: _base64Decode(n['ggnr']?.toString()),
        title: decodeHTML(n['bt']?.toString()),
        url: urls.learnNotificationDetail(
            courseID, n['ggid'].toString(), courseType),
        publisher: n['fbrxm']?.toString() ?? '',
        hasRead: n['sfyd'] == yes,
        markedImportant: _toInt(n['sfqd']) == 1,
        publishTime: n['fbsj'] is String
            ? n['fbsj'].toString()
            : (n['fbsjStr']?.toString() ?? ''),
        expireTime: n['jzsj']?.toString(),
        isFavorite: n['sfsc'] == yes,
        comment: n['bznr']?.toString(),
      );

      // Fetch attachment detail if present
      final attachmentName = courseType == CourseType.student
          ? n['fjmc']?.toString()
          : n['fjbt']?.toString();
      if (attachmentName != null && attachmentName.isNotEmpty) {
        try {
          final detail = await _parseNotificationDetail(
              courseID, notification.id, courseType, attachmentName);
          notification = notification.copyWith(attachment: detail);
        } catch (_) {
          // Non-blocking
        }
      }

      notifications.add(notification);
    }
    return notifications;
  }

  // -------------------------------------------------------------------
  // getFileList
  // -------------------------------------------------------------------

  Future<List<CourseFile>> getFileList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    final json = await _fetchJson(urls.learnFileList(courseID, courseType));
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }

    List result;
    if (json['object']?['resultsList'] is List) {
      result = json['object']['resultsList'];
    } else if (json['object'] is List) {
      result = json['object'];
    } else {
      result = [];
    }

    // Fetch file categories
    final categories = <String, FileCategory>{};
    try {
      final cats = await getFileCategoryList(courseID, courseType: courseType);
      for (final c in cats) {
        categories[c.id] = c;
      }
    } catch (_) {}

    return result.map((f) {
      final title = decodeHTML(f['bt']?.toString());
      final fileId = f['wjid']?.toString() ?? '';
      final uploadTime = f['scsj']?.toString() ?? '';
      final downloadUrl = urls.learnFileDownload(fileId, courseType);
      final previewUrl = urls.learnFilePreview(
        ContentType.file,
        fileId,
        courseType,
        firstPageOnly: previewFirstPage,
      );
      final size = f['fileSize']?.toString() ?? '';

      return CourseFile(
        id: f['kjxxid']?.toString() ?? '',
        fileId: fileId,
        category: categories[f['kjflid']?.toString()],
        title: title,
        description: decodeHTML(f['ms']?.toString()),
        rawSize: _toInt(f['wjdx']),
        size: size,
        uploadTime: uploadTime,
        publishTime: uploadTime,
        downloadUrl: downloadUrl,
        previewUrl: previewUrl,
        isNew: f['isNew'] == true,
        markedImportant: f['sfqd'] == 1,
        visitCount: _toInt(f['xsllcs'] ?? f['llcs']),
        downloadCount: _toInt(f['xzcs']),
        fileType: f['wjlx']?.toString() ?? '',
        remoteFile: RemoteFile(
          id: fileId,
          name: title,
          downloadUrl: downloadUrl,
          previewUrl: previewUrl,
          size: size,
        ),
      );
    }).toList();
  }

  // -------------------------------------------------------------------
  // getFileCategoryList
  // -------------------------------------------------------------------

  Future<List<FileCategory>> getFileCategoryList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    final json =
        await _fetchJson(urls.learnFileCategoryList(courseID, courseType));
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final result = (json['object']?['rows'] ?? []) as List;
    return result
        .map((c) => FileCategory(
              id: c['kjflid']?.toString() ?? '',
              title: decodeHTML(c['bt']?.toString()),
              creationTime: c['czsj']?.toString() ?? '',
            ))
        .toList();
  }

  // -------------------------------------------------------------------
  // getFileListByCategory
  // -------------------------------------------------------------------

  Future<List<CourseFile>> getFileListByCategory(
    String courseID,
    String categoryId, {
    CourseType courseType = CourseType.student,
  }) async {
    if (courseType == CourseType.student) {
      return _getFileListByCategoryStudent(courseID, categoryId);
    } else {
      return _getFileListByCategoryTeacher(courseID, categoryId);
    }
  }

  Future<List<CourseFile>> _getFileListByCategoryStudent(
    String courseID,
    String categoryId,
  ) async {
    final json = await _fetchJson(
        urls.learnFileListByCategoryStudent(courseID, categoryId));
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }

    final result = (json['object'] ?? []) as List;
    return result.map((f) {
      // f is an array (not an object) here
      final fileId = f[7]?.toString() ?? '';
      final title = decodeHTML(f[1]?.toString());
      final rawSize = _toInt(f[9]);
      final size = formatFileSize(rawSize);
      final downloadUrl = urls.learnFileDownload(fileId, CourseType.student);
      final previewUrl = urls.learnFilePreview(
        ContentType.file,
        fileId,
        CourseType.student,
        firstPageOnly: previewFirstPage,
      );

      return CourseFile(
        id: f[0]?.toString() ?? '',
        fileId: fileId,
        title: title,
        description: decodeHTML(f[5]?.toString()),
        rawSize: rawSize,
        size: size,
        uploadTime: f[6]?.toString() ?? '',
        publishTime: f[10]?.toString() ?? '',
        downloadUrl: downloadUrl,
        previewUrl: previewUrl,
        isNew: f[8] == 1,
        markedImportant: f[2] == 1,
        visitCount: 0,
        downloadCount: 0,
        fileType: f[13]?.toString() ?? '',
        remoteFile: RemoteFile(
          id: fileId,
          name: title,
          downloadUrl: downloadUrl,
          previewUrl: previewUrl,
          size: size,
        ),
        isFavorite: f[11] == true,
        comment: f[14]?.toString(),
      );
    }).toList();
  }

  Future<List<CourseFile>> _getFileListByCategoryTeacher(
    String courseID,
    String categoryId,
  ) async {
    final json = await _fetchJson(
      urls.learnFileListByCategoryTeacher,
      method: 'POST',
      data: FormData.fromMap(
          urls.learnFileListByCategoryTeacherFormData(courseID, categoryId)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }

    final result = (json['object']?['aaData'] ?? []) as List;
    return result.map((f) {
      final title = decodeHTML(f['bt']?.toString());
      final fileId = f['wjid']?.toString() ?? '';
      final uploadTime = f['scsj']?.toString() ?? '';
      final downloadUrl = urls.learnFileDownload(fileId, CourseType.teacher);
      final previewUrl = urls.learnFilePreview(
        ContentType.file,
        fileId,
        CourseType.teacher,
        firstPageOnly: previewFirstPage,
      );
      final size = f['fileSize']?.toString() ?? '';

      return CourseFile(
        id: f['kjxxid']?.toString() ?? '',
        fileId: fileId,
        title: title,
        description: decodeHTML(f['ms']?.toString()),
        rawSize: _toInt(f['wjdx']),
        size: size,
        uploadTime: uploadTime,
        publishTime: uploadTime,
        downloadUrl: downloadUrl,
        previewUrl: previewUrl,
        isNew: f['isNew'] == true,
        markedImportant: f['sfqd'] == 1,
        visitCount: _toInt(f['xsllcs'] ?? f['llcs']),
        downloadCount: _toInt(f['xzcs']),
        fileType: f['wjlx']?.toString() ?? '',
        remoteFile: RemoteFile(
          id: fileId,
          name: title,
          downloadUrl: downloadUrl,
          previewUrl: previewUrl,
          size: size,
        ),
      );
    }).toList();
  }

  // -------------------------------------------------------------------
  // getHomeworkList
  // -------------------------------------------------------------------

  Future<List<Homework>> getHomeworkList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    if (courseType == CourseType.teacher) {
      return _getHomeworkListTeacher(courseID);
    }

    final results = await Future.wait(
      urls.learnHomeworkListSource.map(
        (s) => _getHomeworkListAtUrl(courseID, s.url, s.submitted, s.graded),
      ),
    );
    return results.expand((x) => x).toList();
  }

  Future<List<Homework>> _getHomeworkListTeacher(String courseID) async {
    final json = await _fetchJson(
      urls.learnHomeworkListTeacher,
      method: 'POST',
      data: FormData.fromMap(urls.learnPageListFormData(courseID: courseID)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final result = (json['object']?['aaData'] ?? []) as List;
    // Teacher mode returns HomeworkTA, but we map to a simplified Homework
    // for API consistency. In practice the app will handle this differently.
    return result.map((d) {
      return Homework(
        id: d['zyid']?.toString() ?? '',
        studentHomeworkId: d['zyid']?.toString() ?? '',
        baseId: d['zyid']?.toString() ?? '',
        title: decodeHTML(d['bt']?.toString()),
        deadline: d['jzsj']?.toString() ?? '',
        lateSubmissionDeadline: d['bjjzsj']?.toString(),
        url: urls.learnHomeworkDetailTeacher(courseID, d['zyid'].toString()),
        completionType: HomeworkCompletionType.fromValue(_toInt(d['zywcfs'])),
        submissionType: HomeworkSubmissionType.fromValue(_toInt(d['zytjfs'])),
        submitUrl: '',
        isLateSubmission: false,
        submitted: false,
        graded: false,
        isFavorite: false,
      );
    }).toList();
  }

  Future<List<Homework>> _getHomeworkListAtUrl(
    String courseID,
    String url,
    bool submitted,
    bool graded,
  ) async {
    final json = await _fetchJson(
      url,
      method: 'POST',
      data: FormData.fromMap(urls.learnPageListFormData(courseID: courseID)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }

    final result = (json['object']?['aaData'] ?? []) as List;

    // Try to fetch excellent homework list (non-blocking)
    Map<String, List<ExcellentHomework>> excellentMap = {};
    try {
      excellentMap = await _getExcellentHomeworkListByHomework(courseID);
    } catch (_) {}

    final homeworks = <Homework>[];
    for (final h in result) {
      final id = h['xszyid']?.toString() ?? '';
      final baseId = h['zyid']?.toString() ?? '';
      final hwUrl = urls.learnHomeworkPage(h['wlkcid']?.toString() ?? '', id);

      // Parse page for detail (attachment, answer, submission)
      Map<String, dynamic> pageDetail = {};
      try {
        pageDetail = await _parseHomeworkAtUrl(hwUrl);
      } catch (_) {}

      // Parse API detail (description override)
      Map<String, dynamic> apiDetail = {};
      try {
        apiDetail = await _getHomeworkDetail(baseId);
      } catch (_) {}

      final grade = _toDoubleOrNull(h['cj']);

      homeworks.add(Homework(
        id: id,
        studentHomeworkId: id,
        baseId: baseId,
        title: decodeHTML(h['bt']?.toString()),
        url: hwUrl,
        deadline: h['jzsj']?.toString() ?? '',
        lateSubmissionDeadline: h['bjjzsj']?.toString(),
        isLateSubmission: h['sfbj'] == yes,
        completionType: HomeworkCompletionType.fromValue(_toInt(h['zywcfs'])),
        submissionType: HomeworkSubmissionType.fromValue(_toInt(h['zytjfs'])),
        submitUrl: urls.learnHomeworkSubmitPage(
            h['wlkcid']?.toString() ?? '', id),
        submitTime: h['scsj']?.toString(),
        grade: grade,
        gradeLevel: grade != null ? gradeLevelMap[grade.toInt()] : null,
        graderName: trimAndDefine(h['jsm']),
        gradeContent: trimAndDefine(h['pynr']),
        gradeTime: h['pysj']?.toString(),
        isFavorite: h['sfsc'] == yes,
        favoriteTime: (h['scsj'] != null && h['sfsc'] == yes)
            ? h['scsj']?.toString()
            : null,
        comment: h['bznr']?.toString(),
        excellentHomeworkList: excellentMap[baseId],
        submitted: submitted,
        graded: graded,
        // Detail fields from page parsing
        description: apiDetail['description']?.toString() ??
            pageDetail['description']?.toString(),
        attachment: pageDetail['attachment'] as RemoteFile?,
        answerContent: pageDetail['answerContent']?.toString(),
        answerAttachment: pageDetail['answerAttachment'] as RemoteFile?,
        submittedContent: pageDetail['submittedContent']?.toString(),
        submittedAttachment: pageDetail['submittedAttachment'] as RemoteFile?,
        gradeAttachment: pageDetail['gradeAttachment'] as RemoteFile?,
      ));
    }
    return homeworks;
  }

  // -------------------------------------------------------------------
  // getDiscussionList
  // -------------------------------------------------------------------

  Future<List<Discussion>> getDiscussionList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    final json = await _fetchJson(
        urls.learnDiscussionList(courseID, courseType));
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final result = (json['object']?['resultsList'] ?? []) as List;
    return result.map((d) {
      final base = _parseDiscussionBase(d);
      return Discussion(
        id: base['id']!,
        title: base['title']!,
        publisherName: base['publisherName']!,
        publishTime: base['publishTime']!,
        lastReplierName: base['lastReplierName']!,
        lastReplyTime: base['lastReplyTime']!,
        visitCount: int.tryParse(base['visitCount']!) ?? 0,
        replyCount: int.tryParse(base['replyCount']!) ?? 0,
        isFavorite: base['isFavorite'] == 'true',
        comment: base['comment'],
        boardId: d['bqid']?.toString() ?? '',
        url: urls.learnDiscussionDetail(
          d['wlkcid']?.toString() ?? '',
          d['bqid']?.toString() ?? '',
          d['id']?.toString() ?? '',
          courseType,
        ),
      );
    }).toList();
  }

  // -------------------------------------------------------------------
  // getAnsweredQuestionList
  // -------------------------------------------------------------------

  Future<List<Question>> getAnsweredQuestionList(
    String courseID, {
    CourseType courseType = CourseType.student,
  }) async {
    final json = await _fetchJson(
        urls.learnQuestionListAnswered(courseID, courseType));
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final result = (json['object']?['resultsList'] ?? []) as List;
    return result.map((q) {
      final base = _parseDiscussionBase(q);
      return Question(
        id: base['id']!,
        title: base['title']!,
        publisherName: base['publisherName']!,
        publishTime: base['publishTime']!,
        lastReplierName: base['lastReplierName']!,
        lastReplyTime: base['lastReplyTime']!,
        visitCount: int.tryParse(base['visitCount']!) ?? 0,
        replyCount: int.tryParse(base['replyCount']!) ?? 0,
        isFavorite: base['isFavorite'] == 'true',
        comment: base['comment'],
        question: _base64Decode(q['wtnr']?.toString()),
        url: urls.learnQuestionDetail(
          q['wlkcid']?.toString() ?? '',
          q['id']?.toString() ?? '',
          courseType,
        ),
      );
    }).toList();
  }

  // -------------------------------------------------------------------
  // getQuestionnaireList
  // -------------------------------------------------------------------

  Future<List<Questionnaire>> getQuestionnaireList(String courseID) async {
    final ongoing = await _getQuestionnaireListAtUrl(
        courseID, urls.learnQnrListOngoing);
    final ended = await _getQuestionnaireListAtUrl(
        courseID, urls.learnQnrListEnded);
    return [...ongoing, ...ended];
  }

  Future<List<Questionnaire>> _getQuestionnaireListAtUrl(
    String courseID,
    String url,
  ) async {
    final json = await _fetchJson(
      url,
      method: 'POST',
      data: FormData.fromMap(urls.learnPageListFormData(courseID: courseID)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }

    final result = (json['object']?['aaData'] ?? []) as List;
    final questionnaires = <Questionnaire>[];
    for (final e in result) {
      final type = qnrTypeMap[e['wjlx']?.toString()] ?? QuestionnaireType.survey;
      List<QuestionnaireDetail> detail = [];
      try {
        detail = await _getQuestionnaireDetail(courseID, e['wjid'].toString());
      } catch (_) {}

      questionnaires.add(Questionnaire(
        id: e['wjid']?.toString() ?? '',
        type: type,
        title: decodeHTML(e['wjbt']?.toString()),
        startTime: e['kssj']?.toString() ?? '',
        endTime: e['jssj']?.toString() ?? '',
        uploadTime: e['scsj']?.toString() ?? '',
        uploaderId: e['scr']?.toString() ?? '',
        uploaderName: e['scrxm']?.toString() ?? '',
        submitTime: e['tjsj']?.toString(),
        isFavorite: e['sfsc'] == yes,
        comment: e['bznr']?.toString(),
        url: urls.learnQnrSubmitPage(
            e['wlkcid']?.toString() ?? '', e['wjid'].toString(), type),
        detail: detail,
      ));
    }
    return questionnaires;
  }

  Future<List<QuestionnaireDetail>> _getQuestionnaireDetail(
    String courseID,
    String qnrID,
  ) async {
    final json = await _fetchJson(
      urls.learnQnrDetail,
      method: 'POST',
      data: FormData.fromMap(urls.learnQnrDetailForm(courseID, qnrID)),
    );
    if (json is! List) return [];
    return json.map((e) {
      final options = (e['list'] as List?)?.map((o) {
        return QuestionnaireOption(
          id: o['xxid']?.toString() ?? '',
          index: _toInt(o['xxbh']),
          title: decodeHTML(o['xxbt']?.toString()),
        );
      }).toList();

      return QuestionnaireDetail(
        id: e['wtid']?.toString() ?? '',
        index: _toInt(e['wtbh']),
        type: QuestionnaireDetailType.values.firstWhere(
          (t) => t.value == e['type']?.toString(),
          orElse: () => QuestionnaireDetailType.text,
        ),
        required_: e['require'] == yes,
        title: decodeHTML(e['wtbt']?.toString()),
        score: _toDoubleOrNull(e['wtfz']),
        options: options,
      );
    }).toList();
  }

  // -------------------------------------------------------------------
  // Favorites
  // -------------------------------------------------------------------

  Future<void> addToFavorites(ContentType type, String id) async {
    final json = await _fetchJson(urls.learnFavoriteAdd(type, id));
    if (json['result'] != 'success' ||
        !(json['msg']?.toString().endsWith('成功') ?? false)) {
      throw ApiError(reason: FailReason.operationFailed, extra: json);
    }
  }

  Future<void> removeFromFavorites(String id) async {
    final json = await _fetchJson(urls.learnFavoriteRemove(id));
    if (json['result'] != 'success' ||
        !(json['msg']?.toString().endsWith('成功') ?? false)) {
      throw ApiError(reason: FailReason.operationFailed, extra: json);
    }
  }

  Future<List<FavoriteItem>> getFavorites({
    String? courseID,
    ContentType? type,
  }) async {
    final json = await _fetchJson(
      urls.learnFavoriteList(type: type),
      method: 'POST',
      data: FormData.fromMap(urls.learnPageListFormData(courseID: courseID)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final result = (json['object']?['aaData'] ?? []) as List;
    return result
        .map((e) {
          final ctype = contentTypeMapReverse[e['ywlx']?.toString()];
          if (ctype == null) return null;
          return FavoriteItem(
            id: e['ywid']?.toString() ?? '',
            type: ctype,
            title: decodeHTML(e['ywbt']?.toString()),
            time: (ctype == ContentType.discussion ||
                    ctype == ContentType.question)
                ? (e['tlsj']?.toString() ?? '')
                : (e['ywsj']?.toString() ?? ''),
            state: e['ywzt']?.toString() ?? '',
            extra: e['ywbz']?.toString(),
            semesterId: e['xnxq']?.toString() ?? '',
            courseId: e['wlkcid']?.toString() ?? '',
            pinned: e['sfzd'] == yes,
            pinnedTime: e['zdsj']?.toString(),
            comment: e['bznr']?.toString(),
            addedTime: e['scsj']?.toString() ?? '',
            itemId: e['id']?.toString() ?? '',
          );
        })
        .whereType<FavoriteItem>()
        .toList();
  }

  Future<void> pinFavoriteItem(String id) async {
    final json = await _fetchJson(
      urls.learnFavoritePin,
      method: 'POST',
      data: FormData.fromMap(urls.learnFavoritePinUnpinFormData(id)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.operationFailed, extra: json);
    }
  }

  Future<void> unpinFavoriteItem(String id) async {
    final json = await _fetchJson(
      urls.learnFavoriteUnpin,
      method: 'POST',
      data: FormData.fromMap(urls.learnFavoritePinUnpinFormData(id)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.operationFailed, extra: json);
    }
  }

  // -------------------------------------------------------------------
  // Comments
  // -------------------------------------------------------------------

  Future<void> setComment(ContentType type, String id, String content) async {
    final json = await _fetchJson(
      urls.learnCommentSet,
      method: 'POST',
      data: FormData.fromMap(urls.learnCommentSetFormData(type, id, content)),
    );
    if (json['result'] != 'success' ||
        !(json['msg']?.toString().endsWith('成功') ?? false)) {
      throw ApiError(reason: FailReason.operationFailed, extra: json);
    }
  }

  Future<List<CommentItem>> getComments({
    String? courseID,
    ContentType? type,
  }) async {
    final json = await _fetchJson(
      urls.learnCommentList(type: type),
      method: 'POST',
      data: FormData.fromMap(urls.learnPageListFormData(courseID: courseID)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final result = (json['object']?['aaData'] ?? []) as List;
    return result
        .map((e) {
          final ctype = contentTypeMapReverse[e['ywlx']?.toString()];
          if (ctype == null) return null;
          return CommentItem(
            id: e['ywid']?.toString() ?? '',
            type: ctype,
            content: e['bt']?.toString() ?? '',
            contentHTML: decodeHTML(e['bznrstring']?.toString()),
            title: decodeHTML(e['ywbt']?.toString()),
            semesterId: e['xnxq']?.toString() ?? '',
            courseId: e['wlkcid']?.toString() ?? '',
            commentTime: e['cjsj']?.toString() ?? '',
            itemId: e['id']?.toString() ?? '',
          );
        })
        .whereType<CommentItem>()
        .toList();
  }

  // -------------------------------------------------------------------
  // sortCourses
  // -------------------------------------------------------------------

  Future<void> sortCourses(List<String> courseIDs) async {
    final body = jsonEncode(
      courseIDs.asMap().entries.map((e) => {
        'wlkcid': e.value,
        'xh': e.key + 1,
      }).toList(),
    );
    final json = await _fetchJson(
      urls.learnSortCourses,
      method: 'POST',
      data: body,
      headers: {'Content-Type': 'application/json'},
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.operationFailed, extra: json);
    }
  }

  // -------------------------------------------------------------------
  // submitHomework
  // -------------------------------------------------------------------

  Future<void> submitHomework(
    String id, {
    String content = '',
    String? attachmentPath,
    String? attachmentName,
    bool removeAttachment = false,
  }) async {
    final formMap = <String, dynamic>{
      'xszyid': id,
      'zynr': content,
      'isDeleted': removeAttachment ? '1' : '0',
    };
    if (attachmentPath != null && attachmentName != null) {
      formMap['fileupload'] = await MultipartFile.fromFile(
        attachmentPath,
        filename: attachmentName,
      );
    } else {
      formMap['fileupload'] = 'undefined';
    }

    final json = await _fetchJson(
      urls.learnHomeworkSubmit(),
      method: 'POST',
      data: FormData.fromMap(formMap),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.operationFailed, extra: json);
    }
  }

  // -------------------------------------------------------------------
  // Language
  // -------------------------------------------------------------------

  Future<void> setLanguage(Language lang) async {
    await _myFetchWithToken(urls.learnWebsiteLanguage(lang), method: 'POST');
    _lang = lang;
  }

  Language getCurrentLanguage() => _lang;

  // ===================================================================
  //  PRIVATE HELPERS
  // ===================================================================

  // -------------------------------------------------------------------
  // parseNotificationDetail
  // -------------------------------------------------------------------

  Future<RemoteFile> _parseNotificationDetail(
    String courseID,
    String id,
    CourseType courseType,
    String attachmentName,
  ) async {
    final html = await _fetchText(
        urls.learnNotificationDetail(courseID, id, courseType));
    final doc = html_parser.parse(html);

    String path;
    if (courseType == CourseType.student) {
      path = doc.querySelector('.ml-10')?.attributes['href'] ?? '';
    } else {
      path = doc.querySelector('#wjid')?.attributes['href'] ?? '';
    }

    final size = trimAndDefine(
        doc.querySelector('div#attachment > div.fl > span[class^="color"]')?.text);

    // Extract attachment ID from URL params
    final params = Uri.parse('?${path.split('?').last}').queryParameters;
    final attachmentId = params['wjid'] ?? '';

    if (!path.startsWith(urls.learnPrefix)) {
      path = urls.learnPrefix + path;
    }

    return RemoteFile(
      id: attachmentId,
      name: attachmentName,
      downloadUrl: path,
      previewUrl: urls.learnFilePreview(
        ContentType.notification,
        attachmentId,
        courseType,
        firstPageOnly: previewFirstPage,
      ),
      size: size ?? '',
    );
  }

  // -------------------------------------------------------------------
  // parseHomeworkAtUrl
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> _parseHomeworkAtUrl(String url) async {
    final html = await _fetchText(url);
    final doc = html_parser.parse(html);

    final fileDivs = doc.querySelectorAll('div.list.fujian.clearfix');
    final contentDivs = doc.querySelectorAll(
        'div.list.calendar.clearfix > div.fl.right > div.c55');
    final boxboxDivs = doc.querySelectorAll('div.boxbox');

    String? submittedContent;
    if (boxboxDivs.length > 1) {
      final rightDivs = boxboxDivs[1].querySelectorAll('div.right');
      if (rightDivs.length > 2) {
        submittedContent = trimAndDefine(rightDivs[2].innerHtml);
      }
    }

    return {
      'description':
          contentDivs.isNotEmpty ? trimAndDefine(contentDivs[0].innerHtml) : null,
      'answerContent':
          contentDivs.length > 1 ? trimAndDefine(contentDivs[1].innerHtml) : null,
      'submittedContent': submittedContent,
      'attachment':
          fileDivs.isNotEmpty ? _parseHomeworkFile(fileDivs[0]) : null,
      'answerAttachment':
          fileDivs.length > 1 ? _parseHomeworkFile(fileDivs[1]) : null,
      'submittedAttachment':
          fileDivs.length > 2 ? _parseHomeworkFile(fileDivs[2]) : null,
      'gradeAttachment':
          fileDivs.length > 3 ? _parseHomeworkFile(fileDivs[3]) : null,
    };
  }

  // -------------------------------------------------------------------
  // getHomeworkDetail (API detail — description override)
  // -------------------------------------------------------------------

  Future<Map<String, dynamic>> _getHomeworkDetail(String baseId) async {
    final json = await _fetchJson(
      urls.learnHomeworkDetail,
      method: 'POST',
      data: FormData.fromMap(urls.learnHomeworkDetailFormData(baseId)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    return {
      'description': trimAndDefine(json['msg']),
    };
  }

  // -------------------------------------------------------------------
  // parseHomeworkFile
  // -------------------------------------------------------------------

  RemoteFile? _parseHomeworkFile(dynamic fileDiv) {
    if (fileDiv == null) return null;

    // Try .ftitle > a first, then .fl > a
    var fileNode = fileDiv.querySelector('.ftitle a') ??
        fileDiv.querySelector('.fl a');

    if (fileNode == null) return null;

    final href = fileNode.attributes['href'] ?? '';
    final size = trimAndDefine(
        fileDiv.querySelector('.fl > span[class^="color"]')?.text);
    final params = Uri.parse('?${href.split('?').last}').queryParameters;
    final attachmentId = params['fileId'] ?? '';

    String downloadUrl = urls.learnPrefix + href;
    if (params.containsKey('downloadUrl')) {
      downloadUrl = urls.learnPrefix + (params['downloadUrl'] ?? '');
    }

    return RemoteFile(
      id: attachmentId,
      name: fileNode.text?.trim() ?? '',
      downloadUrl: downloadUrl,
      previewUrl: urls.learnFilePreview(
        ContentType.homework,
        attachmentId,
        CourseType.student,
        firstPageOnly: previewFirstPage,
      ),
      size: size ?? '',
    );
  }

  // -------------------------------------------------------------------
  // getExcellentHomeworkListByHomework
  // -------------------------------------------------------------------

  Future<Map<String, List<ExcellentHomework>>>
      _getExcellentHomeworkListByHomework(String courseID) async {
    final json = await _fetchJson(
      urls.learnHomeworkListExcellent,
      method: 'POST',
      data: FormData.fromMap(urls.learnPageListFormData(courseID: courseID)),
    );
    if (json['result'] != 'success') {
      throw ApiError(reason: FailReason.invalidResponse, extra: json);
    }
    final result = (json['object']?['aaData'] ?? []) as List;
    final map = <String, List<ExcellentHomework>>{};

    for (final h in result) {
      final id = h['xszyid']?.toString() ?? '';
      final baseId = h['zyid']?.toString() ?? '';
      final hwUrl = urls.learnHomeworkExcellentPage(
          h['wlkcid']?.toString() ?? '', id);

      Map<String, dynamic> pageDetail = {};
      try {
        pageDetail = await _parseHomeworkAtUrl(hwUrl);
      } catch (_) {}

      Map<String, dynamic> apiDetail = {};
      try {
        apiDetail = await _getHomeworkDetail(baseId);
      } catch (_) {}

      // Parse author from "学号 姓名" format
      final cyParts = (h['cy']?.toString() ?? '').split(' ');

      final excellent = ExcellentHomework(
        id: id,
        baseId: baseId,
        title: decodeHTML(h['bt']?.toString()),
        url: hwUrl,
        completionType: HomeworkCompletionType.fromValue(_toInt(h['zywcfs'])),
        author: HomeworkAuthor(
          id: cyParts.isNotEmpty ? cyParts[0] : null,
          name: cyParts.length > 1 ? cyParts[1] : null,
          anonymous: h['sfzm'] == yes,
        ),
        description: apiDetail['description']?.toString() ??
            pageDetail['description']?.toString(),
        attachment: pageDetail['attachment'] as RemoteFile?,
        answerContent: pageDetail['answerContent']?.toString(),
        answerAttachment: pageDetail['answerAttachment'] as RemoteFile?,
        submittedContent: pageDetail['submittedContent']?.toString(),
        submittedAttachment: pageDetail['submittedAttachment'] as RemoteFile?,
        gradeAttachment: pageDetail['gradeAttachment'] as RemoteFile?,
      );

      map.putIfAbsent(baseId, () => []).add(excellent);
    }
    return map;
  }

  // -------------------------------------------------------------------
  // parseDiscussionBase
  // -------------------------------------------------------------------

  Map<String, String?> _parseDiscussionBase(dynamic d) {
    return {
      'id': d['id']?.toString() ?? '',
      'title': decodeHTML(d['bt']?.toString()),
      'publisherName': d['fbrxm']?.toString() ?? '',
      'publishTime': d['fbsj']?.toString() ?? '',
      'lastReplyTime': d['zhhfsj']?.toString() ?? '',
      'lastReplierName': d['zhhfrxm']?.toString() ?? '',
      'visitCount': (d['djs'] ?? 0).toString(),
      'replyCount': (d['hfcs'] ?? 0).toString(),
      'isFavorite': (d['sfsc'] == yes).toString(),
      'comment': d['bznr']?.toString(),
    };
  }

  // -------------------------------------------------------------------
  // SM2 Encryption stub
  // -------------------------------------------------------------------

  /// SM2 encryption for login password.
  ///
  /// The original library uses the `sm-crypto` npm package.
  /// In Dart, you need a SM2 implementation. This is a placeholder
  /// that should be replaced with a real SM2 implementation
  /// (e.g. using pointycastle or a dedicated SM2 package).
  ///
  /// For now, the app can:
  /// 1. Use WebView-based SSO login (bypasses this)
  /// 2. Provide a native SM2 implementation via FFI/plugin
  String _sm2Encrypt(String data, String publicKey) {
    // TODO: Implement SM2 encryption
    // Options:
    //   1. Use pointycastle with SM2 support
    //   2. Use a Dart SM2 package (e.g. sm_crypto)
    //   3. Call native code via platform channel
    //   4. Use the WebView SSO flow instead (recommended for v1)
    throw UnimplementedError(
      'SM2 encryption not yet implemented. '
      'Use WebView-based SSO login flow instead.',
    );
  }

  // -------------------------------------------------------------------
  // Type conversion helpers
  // -------------------------------------------------------------------

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double? _toDoubleOrNull(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String _base64Decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return '';
    try {
      return utf8.decode(base64Decode(encoded));
    } catch (_) {
      return encoded;
    }
  }
}
