import '../database/database.dart';
import '../semester/academic_calendar.dart';

/// Browsing policy only. Persisting the learning semester belongs to its owner.
class ScheduleSemesterNavigation {
  const ScheduleSemesterNavigation(this.semesters, this.calendar);
  final List<Semester> semesters;
  final AcademicCalendar calendar;

  AcademicTermDates? datesFor(String? id) {
    final semester = semesters.where((item) => item.id == id).firstOrNull;
    return semester == null ? null : calendar.datesFor(semester);
  }

  AcademicTermDates? termOn(DateTime date) => calendar.termOn(date, semesters);

  Semester? adjacent(String id, int direction) {
    final ordered = [...semesters]..sort((a, b) => a.id.compareTo(b.id));
    final index = ordered.indexWhere((item) => item.id == id);
    final next = index + direction;
    return index < 0 || next < 0 || next >= ordered.length
        ? null
        : ordered[next];
  }

  DateTime initialDate(AcademicTermDates term, DateTime today) =>
      term.contains(today) ? today : DateTime.parse(term.start);

  DateTime boundaryDate(AcademicTermDates term, int direction) =>
      DateTime.parse(direction > 0 ? term.start : term.end);
}
