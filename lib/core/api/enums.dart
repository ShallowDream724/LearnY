/// All enums used in the thu-learn-lib API.
///
/// Ported 1:1 from thu-learn-lib TypeScript types.
library;

// ---------------------------------------------------------------------------
// FailReason
// ---------------------------------------------------------------------------

/// Reasons why an API operation can fail.
enum FailReason {
  noCredential('no credential provided'),
  errorFetchFromId('could not fetch ticket from id.tsinghua.edu.cn'),
  badCredential('bad credential'),
  errorRoaming('could not roam to learn.tsinghua.edu.cn'),
  notLoggedIn('not logged in or login timeout'),
  notImplemented('not implemented'),
  invalidResponse('invalid response'),
  unexpectedStatus('unexpected status'),
  operationFailed('operation failed'),
  errorSettingCookies('could not set cookies');

  const FailReason(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// SemesterType
// ---------------------------------------------------------------------------

enum SemesterType {
  fall('fall'),
  spring('spring'),
  summer('summer'),
  unknown('');

  const SemesterType(this.value);
  final String value;
}

// ---------------------------------------------------------------------------
// ContentType
// ---------------------------------------------------------------------------

enum ContentType {
  notification('notification'),
  file('file'),
  homework('homework'),
  discussion('discussion'),
  question('question'),
  questionnaire('questionnaire');

  const ContentType(this.value);
  final String value;
}

// ---------------------------------------------------------------------------
// CourseType
// ---------------------------------------------------------------------------

enum CourseType {
  student('student'),
  teacher('teacher');

  const CourseType(this.value);
  final String value;
}

// ---------------------------------------------------------------------------
// HomeworkGradeLevel
// ---------------------------------------------------------------------------

/// All possible grade levels returned by the API.
///
/// The numeric codes (used in [gradeLevelMap]) come from the backend.
/// Many of these are rarely seen in practice — the most common are
/// [checked], [aPlus]–[d], [distinction], [pass], and [failure].
enum HomeworkGradeLevel {
  /// 已阅
  checked('checked'),
  aPlus('A+'),
  a('A'),
  aMinus('A-'),
  bPlus('B+'),
  /// 优秀
  distinction('distinction'),
  b('B'),
  bMinus('B-'),
  cPlus('C+'),
  c('C'),
  cMinus('C-'),
  g('G'),
  dPlus('D+'),
  d('D'),
  /// 免课
  exemptedCourse('exempted course'),
  p('P'),
  ex('EX'),
  /// 免修
  exemption('exemption'),
  /// 通过
  pass('pass'),
  /// 不通过
  failure('failure'),
  w('W'),
  i('I'),
  /// 缓考
  incomplete('incomplete'),
  na('NA'),
  f('F');

  const HomeworkGradeLevel(this.value);
  final String value;
}

// ---------------------------------------------------------------------------
// HomeworkCompletionType
// ---------------------------------------------------------------------------

enum HomeworkCompletionType {
  individual(1),
  group(2);

  const HomeworkCompletionType(this.value);
  final int value;

  static HomeworkCompletionType? fromValue(int? v) {
    if (v == null) return null;
    return HomeworkCompletionType.values.cast<HomeworkCompletionType?>().firstWhere(
      (e) => e!.value == v,
      orElse: () => null,
    );
  }
}

// ---------------------------------------------------------------------------
// HomeworkSubmissionType
// ---------------------------------------------------------------------------

enum HomeworkSubmissionType {
  webLearning(2),
  offline(0);

  const HomeworkSubmissionType(this.value);
  final int value;

  static HomeworkSubmissionType? fromValue(int? v) {
    if (v == null) return null;
    return HomeworkSubmissionType.values.cast<HomeworkSubmissionType?>().firstWhere(
      (e) => e!.value == v,
      orElse: () => null,
    );
  }
}

// ---------------------------------------------------------------------------
// QuestionnaireDetailType
// ---------------------------------------------------------------------------

enum QuestionnaireDetailType {
  single('dnx'),
  multi('dox'),
  text('wd');

  const QuestionnaireDetailType(this.value);
  final String value;
}

// ---------------------------------------------------------------------------
// QuestionnaireType
// ---------------------------------------------------------------------------

enum QuestionnaireType {
  vote('tp'),
  form('tb'),
  survey('wj');

  const QuestionnaireType(this.value);
  final String value;
}

// ---------------------------------------------------------------------------
// Language
// ---------------------------------------------------------------------------

enum Language {
  zh('zh'),
  en('en');

  const Language(this.value);
  final String value;
}
