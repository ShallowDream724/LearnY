import 'enums.dart';
import 'models.dart';

/// Learning data reads used by semester, synchronization, and schedule services.
abstract interface class LearningReadApi {
  Future<List<String>> getSemesterIdList();

  Future<SemesterInfo> getCurrentSemester();

  Future<List<CourseInfo>> getCourseList(
    String semesterID, {
    CourseType courseType = CourseType.student,
    Language? lang,
  });

  Future<List<Homework>> getHomeworkList(
    String courseID, {
    CourseType courseType = CourseType.student,
  });

  Future<List<Notification>> getNotificationList(
    String courseID, {
    CourseType courseType = CourseType.student,
  });

  Future<List<CourseFile>> getFileList(
    String courseID, {
    CourseType courseType = CourseType.student,
  });

  Future<List<CalendarEvent>> getCalendar(
    String startDate,
    String endDate, {
    bool graduate = false,
  });
}
