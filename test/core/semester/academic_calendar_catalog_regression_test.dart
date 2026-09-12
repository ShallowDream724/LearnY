import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/schedule/semester_schedule_cache.dart';
import 'package:learn_y/core/semester/academic_calendar_catalog.dart';

import '../../support/academic_calendar_fixture.dart';

void main() {
  test('bundled undergraduate calendar has verified boundaries only', () async {
    final catalog = await loadAcademicCalendarCatalogFixture();
    final undergraduate = catalog.forAudience(CalendarAudience.undergraduate);
    final graduate = catalog.forAudience(CalendarAudience.graduate);
    const autumn = Semester(
      id: '2026-2027-1',
      startDate: '2026-09-12',
      endDate: '2027-02-14',
      startYear: 2026,
      endYear: 2027,
      type: 'fall',
    );

    expect(undergraduate.supplement, hasLength(6));
    expect(undergraduate.datesFor(autumn)?.start, '2026-09-14');
    expect(undergraduate.datesFor(autumn)?.end, '2027-01-17');
    expect(graduate.datesFor(autumn), isNull);
  });

  test('catalog rejects duplicate, invalid and overlapping entries', () {
    final first = _entry(
      id: '2025-2026-1',
      start: '2025-09-15',
      end: '2026-01-18',
    );
    expect(
      () => AcademicCalendarCatalog.parse(_catalog([first, first])),
      throwsFormatException,
    );
    expect(
      () => AcademicCalendarCatalog.parse(
        _catalog([
          _entry(id: '2025-2026-1', start: '2025-02-30', end: '2026-01-18'),
        ]),
      ),
      throwsFormatException,
    );
    expect(
      () => AcademicCalendarCatalog.parse(
        _catalog([
          first,
          _entry(id: '2025-2026-2', start: '2026-01-18', end: '2026-06-28'),
        ]),
      ),
      throwsFormatException,
    );
  });

  test(
    'Wednesday spring opening is week one without inventing Monday classes',
    () {
      const cache = SemesterScheduleCache(
        semesterId: '2025-2026-2',
        semesterStartDate: '2026-02-25',
        courses: [
          SemesterScheduleCourse(
            courseId: 'week-one',
            courseName: 'Week one',
            meetings: [
              SemesterScheduleMeeting(
                dayOfWeek: DateTime.wednesday,
                periods: [1],
                location: '',
                activeWeeks: {1},
                usesTeachingBlockClock: true,
              ),
              SemesterScheduleMeeting(
                dayOfWeek: DateTime.monday,
                periods: [1],
                location: '',
                activeWeeks: {1},
                usesTeachingBlockClock: true,
              ),
            ],
          ),
        ],
      );

      final resolved = resolveSemesterScheduleItemsByDateKey(
        cache: cache,
        dates: [
          DateTime(2026, 2, 23),
          DateTime(2026, 2, 25),
          DateTime(2026, 3, 2),
        ],
      );
      expect(resolved['2026-02-23'], isEmpty);
      expect(resolved['2026-02-25'], hasLength(1));
      expect(resolved['2026-03-02'], isEmpty);
    },
  );
}

Map<String, Object?> _entry({
  required String id,
  required String start,
  required String end,
}) => {
  'id': id,
  'audience': 'undergraduate',
  'start': start,
  'end': end,
  'source': 'https://example.edu/calendar',
  'verifiedOn': '2026-09-12',
  'note': '',
};

String _catalog(List<Map<String, Object?>> terms) =>
    jsonEncode({'schemaVersion': 1, 'terms': terms});
