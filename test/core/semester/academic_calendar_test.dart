import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/semester/academic_calendar.dart';

void main() {
  test(
    'server dates take priority over maintained dates and the end is inclusive',
    () {
      const calendar = AcademicCalendar(
        supplement: [
          AcademicTermDates(
            id: '2046-2047-3',
            start: '2047-06-24',
            end: '2047-09-15',
          ),
        ],
      );
      const semester = Semester(
        id: '2046-2047-3',
        startDate: '2047-06-24',
        endDate: '2047-09-13',
        startYear: 2046,
        endYear: 2047,
        type: 'summer',
      );
      expect(
        calendar.termOn(DateTime(2047, 9, 13, 22), [semester])?.id,
        semester.id,
      );
      expect(calendar.termOn(DateTime(2047, 9, 14), [semester]), isNull);
      expect(
        calendar.datesFor(semester.copyWith(startDate: '', endDate: ''))?.end,
        '2047-09-15',
      );
      expect(
        const AcademicCalendar(
          supplement: [],
        ).datesFor(semester.copyWith(endDate: '')),
        isNull,
      );
    },
  );
}
