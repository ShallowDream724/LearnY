import '../../../core/design/app_materials.dart';

/// Retain saved identities; assign new courses the least-used palette slot.
/// IDs, rather than display order or homework counts, break ties consistently.
Map<String, String> assignCourseColors({
  required Iterable<String> courseIds,
  required Map<String, String?> savedKeys,
}) {
  final ids = courseIds.toSet().toList()..sort();
  final result = <String, String>{};
  final usage = {for (final tone in StudyTone.values) tone: 0};
  final inactiveUsage = {for (final tone in StudyTone.values) tone: 0};
  final activeIds = ids.toSet();
  for (final entry in savedKeys.entries) {
    final tone = StudyTone.fromKey(entry.value);
    if (!activeIds.contains(entry.key) && tone != null) {
      inactiveUsage[tone] = inactiveUsage[tone]! + 1;
    }
  }
  for (final id in ids) {
    final key = savedKeys[id];
    final tone = StudyTone.fromKey(key);
    if (tone != null) {
      result[id] = key!;
      usage[tone] = usage[tone]! + 1;
    }
  }
  for (final id in ids) {
    if (result.containsKey(id)) continue;
    final start = StudyPalette.fallbackCourse(id).index;
    var best = StudyTone.values[start];
    for (var offset = 1; offset < StudyTone.values.length; offset++) {
      final candidate =
          StudyTone.values[(start + offset) % StudyTone.values.length];
      if (usage[candidate]! < usage[best]! ||
          (usage[candidate] == usage[best] &&
              inactiveUsage[candidate]! < inactiveUsage[best]!)) {
        best = candidate;
      }
    }
    result[id] = 'auto:${best.name}';
    usage[best] = usage[best]! + 1;
  }
  return result;
}
