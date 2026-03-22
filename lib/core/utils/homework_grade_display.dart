import '../api/enums.dart';
import '../api/utils.dart';

class HomeworkGradeDisplay {
  const HomeworkGradeDisplay({
    required this.numericGrade,
    required this.gradeLevelKey,
    required this.gradeLevelLabel,
  });

  final double? numericGrade;
  final String? gradeLevelKey;
  final String? gradeLevelLabel;

  bool get hasDisplayValue =>
      numericGrade != null ||
      (gradeLevelLabel != null && gradeLevelLabel!.isNotEmpty);

  bool get isNumeric => numericGrade != null;

  String? get primaryLabel {
    if (numericGrade != null) {
      final grade = numericGrade!;
      return grade == grade.roundToDouble()
          ? grade.toInt().toString()
          : grade.toStringAsFixed(1);
    }
    return gradeLevelLabel;
  }

  String? get compactBadgeLabel {
    final label = primaryLabel;
    if (label == null || label.isEmpty) {
      return null;
    }
    if (numericGrade != null || label.runes.length <= 4) {
      return label;
    }
    return '已批';
  }
}

HomeworkGradeDisplay resolveHomeworkGradeDisplay({
  required double? grade,
  required String? gradeLevel,
}) {
  final normalizedLevelKey = _resolveGradeLevelKey(
    grade: grade,
    gradeLevel: gradeLevel,
  );
  return HomeworkGradeDisplay(
    numericGrade: _resolveNumericGrade(grade, normalizedLevelKey),
    gradeLevelKey: normalizedLevelKey,
    gradeLevelLabel: _gradeLevelDisplay(normalizedLevelKey),
  );
}

double? _resolveNumericGrade(double? grade, String? normalizedLevelKey) {
  if (grade == null) {
    return null;
  }
  if (grade.isNaN || grade.isInfinite) {
    return null;
  }
  if (grade < 0 && normalizedLevelKey != null) {
    return null;
  }
  return grade;
}

String? _resolveGradeLevelKey({
  required double? grade,
  required String? gradeLevel,
}) {
  final rawLevel = gradeLevel?.trim();
  if (rawLevel != null && rawLevel.isNotEmpty) {
    return rawLevel;
  }

  if (grade == null || grade > 0 || grade != grade.roundToDouble()) {
    return null;
  }

  final mapped = gradeLevelMap[grade.toInt()];
  return mapped?.value;
}

String? _gradeLevelDisplay(String? levelKey) {
  if (levelKey == null || levelKey.isEmpty) {
    return null;
  }

  return switch (_resolveGradeLevelEnum(levelKey)) {
    HomeworkGradeLevel.checked => '已阅',
    HomeworkGradeLevel.distinction => '优秀',
    HomeworkGradeLevel.pass => '通过',
    HomeworkGradeLevel.failure => '不及格',
    HomeworkGradeLevel.exemptedCourse => '免课',
    HomeworkGradeLevel.exemption => '免修',
    HomeworkGradeLevel.incomplete => '缓考',
    HomeworkGradeLevel.aPlus => 'A+',
    HomeworkGradeLevel.a => 'A',
    HomeworkGradeLevel.aMinus => 'A-',
    HomeworkGradeLevel.bPlus => 'B+',
    HomeworkGradeLevel.b => 'B',
    HomeworkGradeLevel.bMinus => 'B-',
    HomeworkGradeLevel.cPlus => 'C+',
    HomeworkGradeLevel.c => 'C',
    HomeworkGradeLevel.cMinus => 'C-',
    HomeworkGradeLevel.dPlus => 'D+',
    HomeworkGradeLevel.d => 'D',
    HomeworkGradeLevel.g => 'G',
    HomeworkGradeLevel.p => 'P',
    HomeworkGradeLevel.ex => 'EX',
    HomeworkGradeLevel.w => 'W',
    HomeworkGradeLevel.i => 'I',
    HomeworkGradeLevel.na => 'NA',
    HomeworkGradeLevel.f => 'F',
    null => levelKey,
  };
}

HomeworkGradeLevel? _resolveGradeLevelEnum(String levelKey) {
  for (final value in HomeworkGradeLevel.values) {
    if (value.value == levelKey) {
      return value;
    }
  }
  return null;
}
