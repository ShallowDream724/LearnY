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

/// Server dates take precedence. Maintained entries only fill missing metadata.
/// Add confirmed dates here when Learn has not supplied that semester's bounds.
const maintainedAcademicTerms = <AcademicTermDates>[
  AcademicTermDates(id: '2025-2026-3', start: '2026-06-29', end: '2026-09-13'),
  // Official calendar: https://www.tsinghua.edu.cn/xl/2026qiuji.jpg
  AcademicTermDates(id: '2026-2027-1', start: '2026-09-14', end: '2027-01-17'),
];

class AcademicCalendar {
  const AcademicCalendar({this.supplement = maintainedAcademicTerms});
  final List<AcademicTermDates> supplement;

  AcademicTermDates? datesFor(Semester semester) {
    final maintained = supplement
        .where((term) => term.id == semester.id)
        .firstOrNull;
    final start = _date(semester.startDate) ?? _date(maintained?.start);
    final end = _date(semester.endDate) ?? _date(maintained?.end);
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
