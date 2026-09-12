import 'dart:io';

import 'package:learn_y/core/semester/academic_calendar.dart';
import 'package:learn_y/core/semester/academic_calendar_catalog.dart';

const academicCalendarAssetPath = 'assets/calendar/academic_terms.json';

Future<AcademicCalendarCatalog> loadAcademicCalendarCatalogFixture() async {
  final source = await File(academicCalendarAssetPath).readAsString();
  return AcademicCalendarCatalog.parse(source);
}

Future<AcademicCalendar> loadUndergraduateAcademicCalendarFixture() async =>
    (await loadAcademicCalendarCatalogFixture()).forAudience(
      CalendarAudience.undergraduate,
    );
