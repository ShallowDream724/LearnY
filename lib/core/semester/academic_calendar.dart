import '../database/database.dart';

/// Inclusive calendar dates, separate from the user's selected Learn semester.
class AcademicTermDates {
  const AcademicTermDates({
    required this.id,
    required this.start,
    required this.end,
  });
  final String id;
  final String start;
  final String end;

  bool contains(DateTime date) =>
      !date.isBefore(DateTime.parse(start)) &&
      !date.isAfter(DateTime.parse(end));
}

class AcademicCalendar {
  const AcademicCalendar({this.supplement = const []});
  final List<AcademicTermDates> supplement;

  AcademicTermDates? datesFor(Semester semester) {
    final maintained = supplement
        .where((term) => term.id == semester.id)
        .firstOrNull;
    // Learn's semester activation window is not a teaching calendar. An
    // unmaintained term remains unknown instead of shifting all course weeks.
    final start = _date(maintained?.start);
    final end = _date(maintained?.end);
    if (start == null || end == null || end.isBefore(start)) return null;
    return AcademicTermDates(
      id: semester.id,
      start: _key(start),
      end: _key(end),
    );
  }

  AcademicTermDates? termOn(DateTime date, Iterable<Semester> semesters) {
    final matches = semesters
        .map(datesFor)
        .whereType<AcademicTermDates>()
        .where(
          (term) => term.contains(DateTime(date.year, date.month, date.day)),
        )
        .toList();
    return matches.length == 1 ? matches.single : null;
  }

  static DateTime? _date(String? value) {
    final parsed = DateTime.tryParse(value ?? '');
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
