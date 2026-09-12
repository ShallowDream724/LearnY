import 'dart:convert';

import 'enums.dart';
import 'models.dart';

ApiError _incomplete() => const ApiError(reason: FailReason.invalidResponse);

/// Preserve the server's normal full-list response, following explicit totals
/// only when it actually returns a page. Never publish a partial deletion set.
Future<List<dynamic>> loadSchoolTable(
  Future<dynamic> Function(int? offset, int? length) fetch,
) async {
  final rows = <dynamic>[];
  final seen = <String>{};
  int? expected;
  for (var page = 0; page < 50; page++) {
    final json = await fetch(
      page == 0 ? null : rows.length,
      page == 0 ? null : 200,
    );
    if (json is! Map || json['result'] != 'success' || json['object'] is! Map) {
      throw _incomplete();
    }
    final object = json['object'] as Map;
    final batch = object['aaData'] ?? object['resultsList'];
    if (batch is! List) throw _incomplete();
    final rawTotal = object['iTotalDisplayRecords'] ?? object['iTotalRecords'];
    final total = rawTotal == null ? null : int.tryParse(rawTotal.toString());
    if (rawTotal != null && (total == null || total < 0)) throw _incomplete();
    if (page > 0 && total != expected) throw _incomplete();
    expected = total;
    for (final row in batch) {
      if (!seen.add(jsonEncode(row))) throw _incomplete();
      rows.add(row);
    }
    if (total == null || rows.length == total) return rows;
    if (rows.length > total || batch.isEmpty) throw _incomplete();
  }
  throw _incomplete();
}

/// The file endpoint has a size parameter, not a page offset or a total.
/// Increase the limit only when the returned list fills it.
Future<List<dynamic>> loadSchoolSizedList(
  Future<dynamic> Function(int size) fetch,
) async {
  for (var size = 200; size <= 12800; size *= 2) {
    final json = await fetch(size);
    if (json is! Map || json['result'] != 'success') throw _incomplete();
    final object = json['object'];
    final rows = object is List
        ? object
        : object is Map
        ? object['resultsList']
        : null;
    if (rows is! List || rows.length > size) throw _incomplete();
    if (rows.length < size) return rows;
  }
  throw _incomplete();
}
