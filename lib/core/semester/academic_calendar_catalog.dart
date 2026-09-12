import 'dart:convert';

import 'academic_calendar.dart';
import 'semester_models.dart';

enum CalendarAudience { undergraduate, graduate }

/// A future school API can implement this contract without changing browsing,
/// recurrence projection or calendar caching.
abstract interface class AcademicCalendarSource {
  Future<AcademicCalendarCatalog> load();
}

class AcademicCalendarEntry {
  const AcademicCalendarEntry({
    required this.dates,
    required this.audience,
    required this.source,
    required this.verifiedOn,
    required this.note,
  });

  final AcademicTermDates dates;
  final CalendarAudience audience;
  final Uri source;
  final String verifiedOn;
  final String note;
}

/// Versioned teaching-calendar data, separate from Learn activation metadata.
class AcademicCalendarCatalog {
  AcademicCalendarCatalog._(this.entries);

  final List<AcademicCalendarEntry> entries;

  factory AcademicCalendarCatalog.parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map ||
        decoded['schemaVersion'] != 1 ||
        decoded['terms'] is! List) {
      throw const FormatException('Unsupported academic calendar schema');
    }
    final entries = <AcademicCalendarEntry>[];
    final identities = <String>{};
    for (final value in decoded['terms'] as List) {
      if (value is! Map) throw const FormatException('Invalid calendar entry');
      final id = value['id'] as String? ?? '';
      if (SemesterIdentity.tryParse(id) == null) {
        throw FormatException('Invalid academic semester: $id');
      }
      final audience = CalendarAudience.values
          .where((item) => item.name == value['audience'])
          .firstOrNull;
      if (audience == null || !identities.add('${audience.name}:$id')) {
        throw FormatException('Invalid or duplicate calendar audience: $id');
      }
      final start = _date(value['start']);
      final end = _date(value['end']);
      final verifiedOn = _date(value['verifiedOn']);
      if (end.isBefore(start) || end.difference(start).inDays > 366) {
        throw FormatException('Invalid semester range: $id');
      }
      final uri = Uri.tryParse(value['source'] as String? ?? '');
      if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
        throw FormatException('Calendar source must be an HTTPS URL: $id');
      }
      final entry = AcademicCalendarEntry(
        dates: AcademicTermDates(
          id: id,
          start: value['start'],
          end: value['end'],
        ),
        audience: audience,
        source: uri,
        verifiedOn: verifiedOn.toIso8601String().substring(0, 10),
        note: value['note'] as String? ?? '',
      );
      if (entries.any(
        (other) =>
            other.audience == audience &&
            !end.isBefore(DateTime.parse(other.dates.start)) &&
            !start.isAfter(DateTime.parse(other.dates.end)),
      )) {
        throw FormatException('Overlapping teaching semesters: $id');
      }
      entries.add(entry);
    }
    return AcademicCalendarCatalog._(List.unmodifiable(entries));
  }

  AcademicCalendar forAudience(CalendarAudience audience) => AcademicCalendar(
    supplement: List.unmodifiable(
      entries
          .where((entry) => entry.audience == audience)
          .map((entry) => entry.dates),
    ),
  );

  static DateTime _date(Object? value) {
    final date = value is String ? DateTime.tryParse(value) : null;
    if (value is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) ||
        date == null ||
        date.toIso8601String().substring(0, 10) != value) {
      throw const FormatException(
        'Calendar dates must be valid YYYY-MM-DD values',
      );
    }
    return date;
  }
}
