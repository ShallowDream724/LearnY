import 'package:intl/intl.dart';

enum ScheduleItemSource { registrar, routine, legacy }

class TodayScheduleItem {
  const TodayScheduleItem({
    this.courseId,
    required this.courseName,
    required this.startTime,
    required this.endTime,
    required this.location,
    this.source = ScheduleItemSource.registrar,
    this.endTimeInferred = false,
    this.periodLabel = '',
  });

  final String? courseId;
  final String courseName;
  final String startTime;
  final String endTime;
  final String location;
  final ScheduleItemSource source;
  final bool endTimeInferred;
  final String periodLabel;

  String get timeLabel {
    if (endTimeInferred && startTime.isNotEmpty) return '$startTime 起';
    if (startTime.isEmpty && endTime.isEmpty) {
      return '时间待定';
    }
    if (endTime.isEmpty) {
      return startTime;
    }
    return '$startTime-$endTime';
  }
}

class UnscheduledCourse {
  const UnscheduledCourse({
    required this.courseId,
    required this.courseName,
    required this.details,
    this.semesterId,
  });
  final String courseId;
  final String courseName;
  final List<String> details;
  final String? semesterId;
}

class HomeScheduleDayOption {
  const HomeScheduleDayOption({
    required this.date,
    required this.label,
    required this.weekdayLabel,
    required this.shortDateLabel,
    required this.isToday,
  });

  final DateTime date;
  final String label;
  final String weekdayLabel;
  final String shortDateLabel;
  final bool isToday;

  String get dateKey => DateFormat('yyyy-MM-dd').format(date);
}

class HomeScheduleSnapshot {
  const HomeScheduleSnapshot({
    required this.days,
    required this.itemsByDateKey,
    this.authoritativeDateKeys = const {},
    this.hasRoutineData = false,
    this.unscheduledCourses = const [],
  });

  final List<HomeScheduleDayOption> days;
  final Map<String, List<TodayScheduleItem>> itemsByDateKey;

  /// Dates covered by a successful registrar query, including empty dates.
  final Set<String> authoritativeDateKeys;
  final bool hasRoutineData;
  final List<UnscheduledCourse> unscheduledCourses;

  bool get hasEstimatedItems =>
      itemsByDateKey.values
          .expand((items) => items)
          .any((item) => item.source == ScheduleItemSource.routine) ||
      (hasRoutineData && itemsByDateKey.values.every((items) => items.isEmpty));

  bool get hasLegacyItems => itemsByDateKey.values
      .expand((items) => items)
      .any((item) => item.source == ScheduleItemSource.legacy);

  List<TodayScheduleItem> itemsFor(HomeScheduleDayOption day) {
    return itemsByDateKey[day.dateKey] ?? const <TodayScheduleItem>[];
  }
}

class HomeScheduleRemoteRefreshState {
  const HomeScheduleRemoteRefreshState({
    required this.semesterId,
    required this.lastAttemptAt,
    required this.hasSuccessfulRefresh,
    this.failure,
  });

  final String semesterId;
  final DateTime lastAttemptAt;
  final bool hasSuccessfulRefresh;
  final ScheduleFailure? failure;
}

enum ScheduleFailure {
  network,
  timeout,
  sessionExpired,
  storage,
  registrarAuthorization,
  campusAccess,
  identityVerification,
  registrarUnavailable,
  invalidCalendar,
}

class ScheduleState {
  const ScheduleState({
    required this.snapshot,
    this.isRefreshing = false,
    this.hasCalendarData = false,
    this.failure,
  });

  final HomeScheduleSnapshot snapshot;
  final bool isRefreshing;
  final bool hasCalendarData;
  final ScheduleFailure? failure;
}
