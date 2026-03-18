/// Utility functions ported 1:1 from thu-learn-lib/utils.ts.
library;

import 'dart:convert';

import 'enums.dart';
import 'models.dart';

// ---------------------------------------------------------------------------
// Grade level map  (API numeric code → HomeworkGradeLevel)
// ---------------------------------------------------------------------------

const Map<int, HomeworkGradeLevel> gradeLevelMap = {
  -100: HomeworkGradeLevel.checked,
  -99: HomeworkGradeLevel.aPlus,
  -98: HomeworkGradeLevel.a,
  -92: HomeworkGradeLevel.aMinus,
  -87: HomeworkGradeLevel.bPlus,
  -85: HomeworkGradeLevel.distinction,
  -82: HomeworkGradeLevel.b,
  -78: HomeworkGradeLevel.bMinus,
  -74: HomeworkGradeLevel.cPlus,
  -71: HomeworkGradeLevel.c,
  -68: HomeworkGradeLevel.cMinus,
  -67: HomeworkGradeLevel.g,
  -66: HomeworkGradeLevel.dPlus,
  -64: HomeworkGradeLevel.d,
  -65: HomeworkGradeLevel.exemptedCourse,
  -63: HomeworkGradeLevel.pass,
  -62: HomeworkGradeLevel.ex,
  -61: HomeworkGradeLevel.exemption,
  -60: HomeworkGradeLevel.pass, // duplicate intentional — matches original
  -59: HomeworkGradeLevel.failure,
  -55: HomeworkGradeLevel.w,
  -51: HomeworkGradeLevel.i,
  -50: HomeworkGradeLevel.incomplete,
  -31: HomeworkGradeLevel.na,
  -30: HomeworkGradeLevel.f,
};

// ---------------------------------------------------------------------------
// Content type maps
// ---------------------------------------------------------------------------

const Map<ContentType, String> contentTypeMap = {
  ContentType.notification: 'KCGG',
  ContentType.file: 'KCKJ',
  ContentType.homework: 'KCZY',
  ContentType.discussion: 'KCTL',
  ContentType.question: 'KCDY',
  ContentType.questionnaire: 'KCWJ',
};

final Map<String, ContentType> contentTypeMapReverse = {
  for (final entry in contentTypeMap.entries) entry.value: entry.key,
};

const Map<ContentType, String> _contentTypeMkMap = {
  ContentType.notification: 'kcgg',
  ContentType.file: 'kcwj',
  ContentType.homework: 'kczy',
  ContentType.discussion: '',
  ContentType.question: '',
  ContentType.questionnaire: '',
};

String getMkFromType(ContentType type) {
  return 'mk_${_contentTypeMkMap[type] ?? "UNKNOWN"}';
}

// ---------------------------------------------------------------------------
// Questionnaire type map
// ---------------------------------------------------------------------------

const Map<String, QuestionnaireType> qnrTypeMap = {
  '投票': QuestionnaireType.vote,
  '填表': QuestionnaireType.form,
  '问卷': QuestionnaireType.survey,
};

// ---------------------------------------------------------------------------
// SemesterType parser
// ---------------------------------------------------------------------------

SemesterType parseSemesterType(int n) {
  switch (n) {
    case 1:
      return SemesterType.fall;
    case 2:
      return SemesterType.spring;
    case 3:
      return SemesterType.summer;
    default:
      return SemesterType.unknown;
  }
}

// ---------------------------------------------------------------------------
// HTML decode with strange prefix removal
// ---------------------------------------------------------------------------

/// Decodes HTML entities and strips the strange prefixes that the web learning
/// backend sometimes prepends to text fields.
///
/// We use a simple entity replacement approach instead of pulling in a
/// full HTML parser dependency.
String decodeHTML(String? html) {
  if (html == null || html.isEmpty) return '';
  String text = html;

  // Decode common HTML entities
  text = text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');

  // Decode numeric entities: &#NNN; and &#xHHHH;
  text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1)!);
    return code != null ? String.fromCharCode(code) : m.group(0)!;
  });
  text = text.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (m) {
    final code = int.tryParse(m.group(1)!, radix: 16);
    return code != null ? String.fromCharCode(code) : m.group(0)!;
  });

  // Remove strange prefixes returned by web learning.
  // Original JS checks for byte sequences that appear as mojibake.
  if (text.length >= 5 &&
      text.codeUnitAt(0) == 0xC2 &&
      text.codeUnitAt(1) == 0x9E &&
      text.codeUnitAt(2) == 0xC3 &&
      text.codeUnitAt(3) == 0xA9 &&
      text.codeUnitAt(4) == 0x65) {
    return text.substring(5);
  }
  if (text.length >= 3 &&
      text.codeUnitAt(0) == 0x9E &&
      text.codeUnitAt(1) == 0xE9 &&
      text.codeUnitAt(2) == 0x65) {
    return text.substring(3);
  }
  if (text.length >= 2 &&
      text.codeUnitAt(0) == 0xE9 &&
      text.codeUnitAt(1) == 0x65) {
    return text.substring(2);
  }
  return text;
}

// ---------------------------------------------------------------------------
// trimAndDefine
// ---------------------------------------------------------------------------

/// Trims the string and returns `null` if it's empty or was already null.
/// Also runs [decodeHTML] on the result.
String? trimAndDefine(dynamic text) {
  if (text == null) return null;
  final str = text.toString().trim();
  return str.isEmpty ? null : decodeHTML(str);
}

// ---------------------------------------------------------------------------
// JSONP extractor
// ---------------------------------------------------------------------------

const String jsonpExtractorName = 'thu_learn_lib_jsonp_extractor';

/// Extracts the result from a JSONP response.
///
/// Expected format: `thu_learn_lib_jsonp_extractor([...])`.
/// The original JS uses `eval()` — we do simple string extraction + JSON parse.
dynamic extractJSONPResult(String jsonp) {
  if (!jsonp.startsWith(jsonpExtractorName)) {
    throw const ApiError(reason: FailReason.invalidResponse);
  }
  // Extract the content between the first '(' and the last ')'
  final start = jsonp.indexOf('(');
  final end = jsonp.lastIndexOf(')');
  if (start == -1 || end == -1 || start >= end) {
    throw const ApiError(reason: FailReason.invalidResponse);
  }
  return jsonDecode(jsonp.substring(start + 1, end));
}

// ---------------------------------------------------------------------------
// File size formatting
// ---------------------------------------------------------------------------

/// Formats a file size in bytes to a human-readable string.
/// Logic extracted from `judgeSize` function in the Web Learning frontend.
String formatFileSize(int size) {
  if (size < 1024) return '${size}B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)}K';
  if (size < 1024 * 1024 * 1024) {
    return '${(size / 1024 / 1024).toStringAsFixed(2)}M';
  }
  return '${(size / 1024 / 1024 / 1024).toStringAsFixed(2)}G';
}

// ---------------------------------------------------------------------------
// Yes constant
// ---------------------------------------------------------------------------

/// The Chinese character "是" used in many API boolean comparisons.
const String yes = '是';
