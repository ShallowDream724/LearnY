/// URL builders ported 1:1 from thu-learn-lib/urls.ts.
///
/// Each constant/function mirrors the original JS exactly.
/// FormData helpers return `Map<String, String>` for use with Dio.
library;

import 'dart:convert';

import 'enums.dart';
import 'utils.dart';

// ---------------------------------------------------------------------------
// Domain prefixes
// ---------------------------------------------------------------------------

const String idPrefix = 'https://id.tsinghua.edu.cn';
const String learnPrefix = 'https://learn.tsinghua.edu.cn';
const String registrarPrefix = 'https://zhjw.cic.tsinghua.edu.cn';

/// Maximum list size used in paginated API calls.
const int _maxSize = 200;

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

String idLogin() =>
    '$idPrefix/do/off/ui/auth/login/form/bb5df85216504820be7bba2b0ae1535b/0';

String idLoginCheck() => '$idPrefix/do/off/ui/auth/login/check';

String learnAuthRoam(String ticket) =>
    '$learnPrefix/b/j_spring_security_thauth_roaming_entry?ticket=$ticket';

String learnLogout() => '$learnPrefix/f/j_spring_security_logout';

// ---------------------------------------------------------------------------
// Homepage / Course list page
// ---------------------------------------------------------------------------

String learnHomepage(CourseType courseType) =>
    '$learnPrefix/f/wlxt/index/course/${courseType.value}/';

String learnStudentCourseListPage() =>
    '$learnPrefix/f/wlxt/index/course/student/';

// ---------------------------------------------------------------------------
// Semester
// ---------------------------------------------------------------------------

String learnSemesterList() =>
    '$learnPrefix/b/wlxt/kc/v_wlkc_xs_xktjb_coassb/queryxnxq';

String learnCurrentSemester() =>
    '$learnPrefix/b/kc/zhjw_v_code_xnxq/getCurrentAndNextSemester';

// ---------------------------------------------------------------------------
// Course list
// ---------------------------------------------------------------------------

String learnCourseList(
  String semester,
  CourseType courseType,
  Language lang,
) {
  if (courseType == CourseType.student) {
    return '$learnPrefix/b/wlxt/kc/v_wlkc_xs_xkb_kcb_extend/student/loadCourseBySemesterId/$semester/${lang.value}';
  } else {
    return '$learnPrefix/b/kc/v_wlkc_kcb/queryAsorCoCourseList/$semester/0';
  }
}

String learnCoursePage(String courseID, CourseType courseType) =>
    '$learnPrefix/f/wlxt/index/course/${courseType.value}/course?wlkcid=$courseID';

String learnCourseTimeLocation(String courseID) =>
    '$learnPrefix/b/kc/v_wlkc_xk_sjddb/detail?id=$courseID';

// ---------------------------------------------------------------------------
// Files
// ---------------------------------------------------------------------------

String learnFileList(String courseID, CourseType courseType) {
  if (courseType == CourseType.student) {
    return '$learnPrefix/b/wlxt/kj/wlkc_kjxxb/student/kjxxbByWlkcidAndSizeForStudent?wlkcid=$courseID&size=$_maxSize';
  } else {
    return '$learnPrefix/b/wlxt/kj/v_kjxxb_wjwjb/teacher/queryByWlkcid?wlkcid=$courseID&size=$_maxSize';
  }
}

String learnFileCategoryList(String courseID, CourseType courseType) =>
    '$learnPrefix/b/wlxt/kj/wlkc_kjflb/${courseType.value}/pageList?wlkcid=$courseID';

String learnFileListByCategoryStudent(String courseID, String categoryId) =>
    '$learnPrefix/b/wlxt/kj/wlkc_kjxxb/student/kjxxb/$courseID/$categoryId';

const String learnFileListByCategoryTeacher =
    '$learnPrefix/b/wlxt/kj/v_kjxxb_wjwjb/teacher/pageList';

Map<String, String> learnFileListByCategoryTeacherFormData(
  String courseID,
  String categoryId,
) {
  return {
    'aoData': jsonEncode([
      {'name': 'wlkcid', 'value': courseID},
      {'name': 'kjflid', 'value': categoryId},
    ]),
  };
}

String learnFileDownload(String fileID, CourseType courseType) =>
    '$learnPrefix/b/wlxt/kj/wlkc_kjxxb/${courseType.value}/downloadFile?sfgk=0&wjid=$fileID';

String learnFilePreview(
  ContentType type,
  String fileID,
  CourseType courseType, {
  bool firstPageOnly = false,
}) =>
    '$learnPrefix/f/wlxt/kc/wj_wjb/${courseType.value}/beforePlay?wjid=$fileID&mk=${getMkFromType(type)}&browser=-1&sfgk=0&pageType=${firstPageOnly ? 'first' : 'all'}';

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

String learnNotificationList(CourseType courseType, bool expired) {
  final base = '$learnPrefix/b/wlxt/kcgg/wlkc_ggb/';
  final role = courseType == CourseType.student
      ? 'student/pageListXsby'
      : 'teacher/pageListby';
  final suffix = expired ? 'Ygq' : 'Wgq';
  return '$base$role$suffix';
}

String learnNotificationDetail(
  String courseID,
  String notificationID,
  CourseType courseType,
) {
  if (courseType == CourseType.student) {
    return '$learnPrefix/f/wlxt/kcgg/wlkc_ggb/student/beforeViewXs?wlkcid=$courseID&id=$notificationID';
  } else {
    return '$learnPrefix/f/wlxt/kcgg/wlkc_ggb/teacher/beforeViewJs?wlkcid=$courseID&id=$notificationID';
  }
}

String learnNotificationEdit(CourseType courseType) =>
    '$learnPrefix/b/wlxt/kcgg/wlkc_ggb/${courseType.value}/editKcgg';

// ---------------------------------------------------------------------------
// Homework
// ---------------------------------------------------------------------------

const String learnHomeworkListNew =
    '$learnPrefix/b/wlxt/kczy/zy/student/zyListWj';

const String learnHomeworkListSubmitted =
    '$learnPrefix/b/wlxt/kczy/zy/student/zyListYjwg';

const String learnHomeworkListGraded =
    '$learnPrefix/b/wlxt/kczy/zy/student/zyListYpg';

const String learnHomeworkListExcellent =
    '$learnPrefix/b/wlxt/kczy/zy/student/yxzylist';

/// The 3 homework list endpoints with their known status.
final List<({String url, bool submitted, bool graded})>
    learnHomeworkListSource = [
  (url: learnHomeworkListNew, submitted: false, graded: false),
  (url: learnHomeworkListSubmitted, submitted: true, graded: false),
  (url: learnHomeworkListGraded, submitted: true, graded: true),
];

String learnHomeworkPage(String courseID, String id) =>
    '$learnPrefix/f/wlxt/kczy/zy/student/viewCj?wlkcid=$courseID&xszyid=$id';

String learnHomeworkExcellentPage(String courseID, String id) =>
    '$learnPrefix/f/wlxt/kczy/zy/student/viewYxzy?wlkcid=$courseID&xszyid=$id';

const String learnHomeworkDetail =
    '$learnPrefix/b/wlxt/kczy/zy/student/detail';

Map<String, String> learnHomeworkDetailFormData(String baseId) {
  return {'id': baseId};
}

String learnHomeworkDownload(String courseID, String attachmentID) =>
    '$learnPrefix/b/wlxt/kczy/zy/student/downloadFile/$courseID/$attachmentID';

String learnHomeworkSubmitPage(String courseID, String id) =>
    '$learnPrefix/f/wlxt/kczy/zy/student/tijiao?wlkcid=$courseID&xszyid=$id';

String learnHomeworkSubmit() => '$learnPrefix/b/wlxt/kczy/zy/student/tjzy';

const String learnHomeworkListTeacher =
    '$learnPrefix/b/wlxt/kczy/zy/teacher/pageList';

String learnHomeworkDetailTeacher(String courseID, String homeworkID) =>
    '$learnPrefix/f/wlxt/kczy/xszy/teacher/beforePageList?zyid=$homeworkID&wlkcid=$courseID';

// ---------------------------------------------------------------------------
// Discussion
// ---------------------------------------------------------------------------

String learnDiscussionList(String courseID, CourseType courseType) =>
    '$learnPrefix/b/wlxt/bbs/bbs_tltb/${courseType.value}/kctlList?wlkcid=$courseID&size=$_maxSize';

String learnDiscussionDetail(
  String courseID,
  String boardID,
  String discussionID,
  CourseType courseType, {
  int tabId = 1,
}) =>
    '$learnPrefix/f/wlxt/bbs/bbs_tltb/${courseType.value}/viewTlById?wlkcid=$courseID&id=$discussionID&tabbh=$tabId&bqid=$boardID';

// ---------------------------------------------------------------------------
// Question (答疑)
// ---------------------------------------------------------------------------

String learnQuestionListAnswered(String courseID, CourseType courseType) =>
    '$learnPrefix/b/wlxt/bbs/bbs_tltb/${courseType.value}/kcdyList?wlkcid=$courseID&size=$_maxSize';

String learnQuestionDetail(
  String courseID,
  String questionID,
  CourseType courseType,
) {
  if (courseType == CourseType.student) {
    return '$learnPrefix/f/wlxt/bbs/bbs_kcdy/student/viewDyById?wlkcid=$courseID&id=$questionID';
  } else {
    return '$learnPrefix/f/wlxt/bbs/bbs_kcdy/teacher/beforeEditDy?wlkcid=$courseID&id=$questionID';
  }
}

// ---------------------------------------------------------------------------
// Questionnaire
// ---------------------------------------------------------------------------

const String learnQnrListOngoing =
    '$learnPrefix/b/wlxt/kcwj/wlkc_wjb/student/pageListWks';

const String learnQnrListEnded =
    '$learnPrefix/b/wlxt/kcwj/wlkc_wjb/student/pageListYjs';

String learnQnrSubmitPage(
  String courseID,
  String qnrID,
  QuestionnaireType type,
) =>
    '$learnPrefix/f/wlxt/kcwj/wlkc_wjb/student/beforeAdd?wlkcid=$courseID&wjid=$qnrID&wjlx=${type.value}&jswj=no';

const String learnQnrDetail =
    '$learnPrefix/b/wlxt/kcwj/wlkc_wjb/student/getWjnr';

Map<String, String> learnQnrDetailForm(String courseID, String qnrID) {
  return {'wlkcid': courseID, 'wjid': qnrID};
}

// ---------------------------------------------------------------------------
// Language
// ---------------------------------------------------------------------------

const Map<Language, String> _websiteShowLanguage = {
  Language.zh: 'zh_CN',
  Language.en: 'en_US',
};

String learnWebsiteLanguage(Language lang) =>
    '$learnPrefix/f/wlxt/common/language?websiteShowLanguage=${_websiteShowLanguage[lang]}';

// ---------------------------------------------------------------------------
// Favorites
// ---------------------------------------------------------------------------

String learnFavoriteAdd(ContentType type, String id) =>
    '$learnPrefix/b/xt/wlkc_xsscb/student/add?ywid=$id&ywlx=${contentTypeMap[type]}';

String learnFavoriteRemove(String id) =>
    '$learnPrefix/b/xt/wlkc_xsscb/student/delete?ywid=$id';

String learnFavoriteList({ContentType? type}) =>
    '$learnPrefix/b/xt/wlkc_xsscb/student/pageList?ywlx=${type != null ? contentTypeMap[type] : 'ALL'}';

const String learnFavoritePin =
    '$learnPrefix/b/xt/wlkc_xsscb/student/addZd';

const String learnFavoriteUnpin =
    '$learnPrefix/b/xt/wlkc_xsscb/student/delZd';

Map<String, String> learnFavoritePinUnpinFormData(String id) {
  return {'ywid': id};
}

// ---------------------------------------------------------------------------
// Comments
// ---------------------------------------------------------------------------

const String learnCommentSet =
    '$learnPrefix/b/wlxt/xt/wlkc_xsbjb/add';

Map<String, String> learnCommentSetFormData(
  ContentType type,
  String id,
  String content,
) {
  return {
    'ywlx': contentTypeMap[type] ?? '',
    'ywid': id,
    'bznr': content,
  };
}

String learnCommentList({ContentType? type}) =>
    '$learnPrefix/b/wlxt/xt/wlkc_xsbjb/student/pageList?ywlx=${type != null ? contentTypeMap[type] : 'ALL'}';

// ---------------------------------------------------------------------------
// Page list (common form data for paginated endpoints)
// ---------------------------------------------------------------------------

Map<String, String> learnPageListFormData({String? courseID}) {
  return {
    'aoData': jsonEncode(
      courseID != null
          ? [
              {'name': 'wlkcid', 'value': courseID},
            ]
          : [],
    ),
  };
}

// ---------------------------------------------------------------------------
// Sort courses
// ---------------------------------------------------------------------------

const String learnSortCourses =
    '$learnPrefix/b/wlxt/kc/wlkc_kcpxb/addorUpdate';

// ---------------------------------------------------------------------------
// Registrar (教务 — for calendar)
// ---------------------------------------------------------------------------

Map<String, String> registrarTicketFormData() {
  return {'appId': 'ALL_ZHJW'};
}

String registrarTicket() => '$learnPrefix/b/wlxt/common/auth/gnt';

String registrarAuth(String ticket) =>
    '$registrarPrefix/j_acegi_login.do?url=/&ticket=$ticket';

String registrarCalendar(
  String startDate,
  String endDate, {
  bool graduate = false,
  String callbackName = 'unknown',
}) =>
    '$registrarPrefix/jxmh_out.do?m=${graduate ? 'yjs' : 'bks'}_jxrl_all&p_start_date=$startDate&p_end_date=$endDate&jsoncallback=$callbackName';

// ---------------------------------------------------------------------------
// CSRF helper
// ---------------------------------------------------------------------------

/// Adds a `_csrf` query parameter to a URL.
String addCSRFTokenToUrl(String url, String token) {
  final uri = Uri.parse(url);
  final params = Map<String, String>.from(uri.queryParameters);
  params['_csrf'] = token;
  return uri.replace(queryParameters: params).toString();
}
