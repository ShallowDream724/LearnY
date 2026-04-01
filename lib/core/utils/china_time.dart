const Duration _chinaOffset = Duration(hours: 8);

DateTime utcNow() => DateTime.now().toUtc();

DateTime nowInChinaTime() => asChinaWallClock(DateTime.now());

DateTime? tryParseEpochMillisToChinaWallClock(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }

  final ms = int.tryParse(raw);
  if (ms == null) {
    return null;
  }

  return asChinaWallClock(DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
}

DateTime asChinaWallClock(DateTime instant) {
  final china = instant.toUtc().add(_chinaOffset);
  return DateTime(
    china.year,
    china.month,
    china.day,
    china.hour,
    china.minute,
    china.second,
    china.millisecond,
    china.microsecond,
  );
}

String formatMonthDayHourMinuteInChina(DateTime instant) {
  final china = asChinaWallClock(instant);
  final mm = china.month.toString().padLeft(2, '0');
  final dd = china.day.toString().padLeft(2, '0');
  final hh = china.hour.toString().padLeft(2, '0');
  final minute = china.minute.toString().padLeft(2, '0');
  return '$mm-$dd $hh:$minute';
}
