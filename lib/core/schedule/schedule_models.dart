import 'package:intl/intl.dart';

class TodayScheduleItem {
  const TodayScheduleItem({
    this.courseId,
    required this.courseName,
    required this.startTime,
    required this.endTime,
    required this.location,
  });

  final String? courseId;
  final String courseName;
  final String startTime;
  final String endTime;
  final String location;

  String get timeLabel {
    if (startTime.isEmpty && endTime.isEmpty) {
      return '时间待定';
    }
    if (endTime.isEmpty) {
      return startTime;
    }
    return '$startTime-$endTime';
  }
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
  });

  final List<HomeScheduleDayOption> days;
  final Map<String, List<TodayScheduleItem>> itemsByDateKey;

  List<TodayScheduleItem> itemsFor(HomeScheduleDayOption day) {
    return itemsByDateKey[day.dateKey] ?? const <TodayScheduleItem>[];
  }
}

class HomeScheduleRemoteRefreshState {
  const HomeScheduleRemoteRefreshState({
    required this.semesterId,
    required this.lastAttemptAt,
    required this.hasSuccessfulRefresh,
  });

  final String semesterId;
  final DateTime lastAttemptAt;
  final bool hasSuccessfulRefresh;
}

enum ScheduleFailure { network, timeout, sessionExpired, storage }

class ScheduleState {
  const ScheduleState({
    required this.semesterId,
    required this.snapshot,
    this.isRefreshing = false,
    this.hasCalendarData = false,
    this.failure,
  });

  final String? semesterId;
  final HomeScheduleSnapshot snapshot;
  final bool isRefreshing;
  final bool hasCalendarData;
  final ScheduleFailure? failure;
}
