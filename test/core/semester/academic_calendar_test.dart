import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/semester/academic_calendar.dart';

import '../../support/academic_calendar_fixture.dart';

void main() {
  test('verified teaching dates take priority over Learn activation dates', () {
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
    expect(
      calendar.termOn(DateTime(2047, 9, 15, 22), [semester])?.id,
      semester.id,
    );
    expect(calendar.termOn(DateTime(2047, 9, 16), [semester]), isNull);
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
  });
  test(
    'autumn starts on teaching Monday despite Learn activating on Saturday',
    () async {
      const semester = Semester(
        id: '2026-2027-1',
        startDate: '2026-09-12',
        endDate: '2027-02-14',
        startYear: 2026,
        endYear: 2027,
        type: 'fall',
      );
      final calendar = await loadUndergraduateAcademicCalendarFixture();
      final term = calendar.datesFor(semester)!;
      expect(term.start, '2026-09-14');
      expect(term.end, '2027-01-17');
      expect(
        DateTime.parse(term.end).difference(DateTime.parse(term.start)).inDays +
            1,
        18 * 7,
      );
    },
  );
}
