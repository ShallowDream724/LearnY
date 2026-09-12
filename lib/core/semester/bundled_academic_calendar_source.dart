import 'package:flutter/services.dart';

import 'academic_calendar_catalog.dart';

class BundledAcademicCalendarSource implements AcademicCalendarSource {
  BundledAcademicCalendarSource({AssetBundle? bundle})
    : _bundle = bundle ?? rootBundle;
  final AssetBundle _bundle;

  @override
  Future<AcademicCalendarCatalog> load() async => AcademicCalendarCatalog.parse(
    await _bundle.loadString('assets/calendar/academic_terms.json'),
  );
}
