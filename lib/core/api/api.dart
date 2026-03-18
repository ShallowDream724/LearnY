/// thu-learn-lib Dart port — barrel export.
///
/// ```dart
/// import 'package:learn_y/core/api/api.dart';
///
/// final helper = Learn2018Helper(config: HelperConfig(
///   provider: () async => Credential(
///     username: 'student_id',
///     password: 'password',
///     fingerPrint: 'device_fingerprint',
///   ),
/// ));
///
/// await helper.login();
/// final user = await helper.getUserInfo();
/// final semester = await helper.getCurrentSemester();
/// final courses = await helper.getCourseList(semester.id);
/// ```
library;

export 'enums.dart';
export 'models.dart';
export 'urls.dart';
export 'utils.dart' hide yes;
export 'learn_api.dart';
