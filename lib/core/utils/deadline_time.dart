const Duration _shanghaiOffset = Duration(hours: 8);

String formatHourMinuteLabel(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime nowInShanghai() => _asShanghaiWallClock(DateTime.now());

DateTime? tryParseEpochMillisToLocal(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final ms = int.tryParse(raw);
  if (ms == null) {
    return null;
  }

  return _asShanghaiWallClock(
    DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
  );
}

DateTime _asShanghaiWallClock(DateTime instant) {
  final shanghai = instant.toUtc().add(_shanghaiOffset);
  return DateTime(
    shanghai.year,
    shanghai.month,
    shanghai.day,
    shanghai.hour,
    shanghai.minute,
    shanghai.second,
    shanghai.millisecond,
    shanghai.microsecond,
  );
}

int calendarDayDifference(DateTime from, DateTime to) {
  final fromDate = DateTime(from.year, from.month, from.day);
  final toDate = DateTime(to.year, to.month, to.day);
  return toDate.difference(fromDate).inDays;
}

String formatRelativeDeadlineLabel(DateTime deadline, {required DateTime now}) {
  final dayDiff = calendarDayDifference(now, deadline);
  final time = formatHourMinuteLabel(deadline);

  if (dayDiff == 0) return '今天 $time';
  if (dayDiff == 1) return '明天 $time';
  if (dayDiff == 2) return '后天 $time';

  const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
  final nowMonday = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  final deadlineMonday = DateTime(
    deadline.year,
    deadline.month,
    deadline.day,
  ).subtract(Duration(days: deadline.weekday - 1));
  final sameWeek = nowMonday == deadlineMonday;

  if (dayDiff < 14) {
    final prefix = sameWeek ? '本' : '下';
    return '$prefix${weekdays[deadline.weekday]} $time';
  }

  return '${deadline.month}/${deadline.day} $time';
}

String formatRelativeDayCountLabel(DateTime deadline, {required DateTime now}) {
  final dayDiff = calendarDayDifference(now, deadline);
  if (dayDiff <= 0) {
    return '今天';
  }
  if (dayDiff == 1) {
    return '明天';
  }
  if (dayDiff == 2) {
    return '后天';
  }
  return '$dayDiff天';
}
