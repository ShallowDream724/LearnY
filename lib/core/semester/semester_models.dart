class SemesterIdentity implements Comparable<SemesterIdentity> {
  const SemesterIdentity({
    required this.id,
    required this.startYear,
    required this.endYear,
    required this.term,
  });

  final String id;
  final int startYear;
  final int endYear;
  final int term;

  static SemesterIdentity? tryParse(String raw) {
    final id = raw.trim();
    final match = RegExp(r'^(\d{4})-(\d{4})-([123])$').firstMatch(id);
    if (match == null) return null;
    final startYear = int.parse(match[1]!);
    final endYear = int.parse(match[2]!);
    if (endYear != startYear + 1) return null;
    return SemesterIdentity(
      id: id,
      startYear: startYear,
      endYear: endYear,
      term: int.parse(match[3]!),
    );
  }

  String get type => switch (term) {
    1 => 'fall',
    2 => 'spring',
    _ => 'summer',
  };
  String get termLabel => switch (term) {
    1 => '秋季',
    2 => '春季',
    _ => '夏季',
  };
  String get label => '$startYear-$endYear $termLabel学期';

  @override
  int compareTo(SemesterIdentity other) {
    final year = startYear.compareTo(other.startYear);
    return year == 0 ? term.compareTo(other.term) : year;
  }
}

String semesterLabel(String? id) =>
    id == null ? '选择学期' : SemesterIdentity.tryParse(id)?.label ?? id;

class SemesterCatalogRefresh {
  const SemesterCatalogRefresh({required this.currentId, this.warning});

  final String? currentId;
  final String? warning;
}
