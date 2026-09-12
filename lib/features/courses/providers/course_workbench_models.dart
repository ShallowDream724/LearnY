import 'package:flutter/foundation.dart';

import '../../../core/database/database.dart' as db;
import 'course_color_assignment.dart';
import 'course_queries.dart';

@immutable
class CourseWorkbenchScope {
  const CourseWorkbenchScope({
    required this.ownerKey,
    required this.semesterId,
  });

  final String ownerKey;
  final String semesterId;

  static String normalizeOwner(String raw) {
    final normalized = raw.trim().toLowerCase();
    return normalized.isEmpty ? 'anonymous' : normalized;
  }
}

@immutable
class ResolvedCourseCardModel {
  const ResolvedCourseCardModel({
    required this.course,
    required this.unreadNotifications,
    required this.pendingHomeworks,
    required this.totalFiles,
    required this.defaultSortOrder,
    this.alias,
    this.iconKey,
    this.accentKey,
  });

  final db.Course course;
  final int unreadNotifications;
  final int pendingHomeworks;
  final int totalFiles;
  final int defaultSortOrder;
  final String? alias;
  final String? iconKey;
  final String? accentKey;

  String get displayTitle =>
      alias?.trim().isNotEmpty == true ? alias!.trim() : course.name;

  bool get hasCustomAlias => alias?.trim().isNotEmpty == true;
  bool get hasCustomIcon => iconKey?.trim().isNotEmpty == true;

  String get secondaryLabel {
    if (hasCustomAlias) {
      final fullName = course.name.trim();
      final teacherName = course.teacherName.trim();
      if (teacherName.isEmpty) {
        return fullName;
      }
      return '$fullName · $teacherName';
    }
    return course.teacherName.trim();
  }

  int get aggregateBadgeCount => unreadNotifications + pendingHomeworks;

  ResolvedCourseCardModel copyWith({
    db.Course? course,
    int? unreadNotifications,
    int? pendingHomeworks,
    int? totalFiles,
    int? defaultSortOrder,
    String? alias,
    bool clearAlias = false,
    String? iconKey,
    bool clearIconKey = false,
    String? accentKey,
    bool clearAccentKey = false,
  }) {
    return ResolvedCourseCardModel(
      course: course ?? this.course,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      pendingHomeworks: pendingHomeworks ?? this.pendingHomeworks,
      totalFiles: totalFiles ?? this.totalFiles,
      defaultSortOrder: defaultSortOrder ?? this.defaultSortOrder,
      alias: clearAlias ? null : (alias ?? this.alias),
      iconKey: clearIconKey ? null : (iconKey ?? this.iconKey),
      accentKey: clearAccentKey ? null : (accentKey ?? this.accentKey),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ResolvedCourseCardModel &&
        other.course == course &&
        other.unreadNotifications == unreadNotifications &&
        other.pendingHomeworks == pendingHomeworks &&
        other.totalFiles == totalFiles &&
        other.defaultSortOrder == defaultSortOrder &&
        other.alias == alias &&
        other.iconKey == iconKey &&
        other.accentKey == accentKey;
  }

  @override
  int get hashCode => Object.hash(
    course,
    unreadNotifications,
    pendingHomeworks,
    totalFiles,
    defaultSortOrder,
    alias,
    iconKey,
    accentKey,
  );
}

@immutable
class CourseWorkbenchState {
  const CourseWorkbenchState({
    this.isEditing = false,
    this.baselineCards = const <ResolvedCourseCardModel>[],
    this.draftCards = const <ResolvedCourseCardModel>[],
    this.draggingCourseId,
    this.hoverCourseId,
    this.hoverInsertIndex,
  });

  final bool isEditing;
  final List<ResolvedCourseCardModel> baselineCards;
  final List<ResolvedCourseCardModel> draftCards;
  final String? draggingCourseId;
  final String? hoverCourseId;
  final int? hoverInsertIndex;

  bool get hasChanges => !_sameCardDrafts(baselineCards, draftCards);

  CourseWorkbenchState copyWith({
    bool? isEditing,
    List<ResolvedCourseCardModel>? baselineCards,
    List<ResolvedCourseCardModel>? draftCards,
    String? draggingCourseId,
    String? hoverCourseId,
    int? hoverInsertIndex,
    bool clearDraggingCourseId = false,
    bool clearHoverCourseId = false,
    bool clearHoverInsertIndex = false,
  }) {
    return CourseWorkbenchState(
      isEditing: isEditing ?? this.isEditing,
      baselineCards: baselineCards ?? this.baselineCards,
      draftCards: draftCards ?? this.draftCards,
      draggingCourseId: clearDraggingCourseId
          ? null
          : (draggingCourseId ?? this.draggingCourseId),
      hoverCourseId: clearHoverCourseId
          ? null
          : (hoverCourseId ?? this.hoverCourseId),
      hoverInsertIndex: clearHoverInsertIndex
          ? null
          : (hoverInsertIndex ?? this.hoverInsertIndex),
    );
  }

  static bool _sameCardDrafts(
    List<ResolvedCourseCardModel> a,
    List<ResolvedCourseCardModel> b,
  ) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i += 1) {
      if (a[i].course.id != b[i].course.id ||
          a[i].alias != b[i].alias ||
          a[i].iconKey != b[i].iconKey ||
          a[i].accentKey != b[i].accentKey) {
        return false;
      }
    }
    return true;
  }
}

List<ResolvedCourseCardModel> buildResolvedCourseCards({
  required List<CourseStats> stats,
  required List<db.CourseDisplayPref> prefs,
}) {
  if (stats.isEmpty) {
    return const <ResolvedCourseCardModel>[];
  }

  final statsByCourseId = <String, CourseStats>{
    for (var index = 0; index < stats.length; index += 1)
      stats[index].course.id: stats[index],
  };
  final prefByCourseId = <String, db.CourseDisplayPref>{
    for (final pref in prefs) pref.courseId: pref,
  };
  final defaultSortOrderByCourseId = <String, int>{
    for (var index = 0; index < stats.length; index += 1)
      stats[index].course.id: index,
  };
  final orderedPrefs =
      prefs
          .where(
            (pref) =>
                pref.sortOrder >= 0 &&
                statsByCourseId.containsKey(pref.courseId),
          )
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final orderedIds = <String>[];
  final seenCourseIds = <String>{};

  for (final pref in orderedPrefs) {
    if (seenCourseIds.add(pref.courseId)) {
      orderedIds.add(pref.courseId);
    }
  }

  for (final stat in stats) {
    if (seenCourseIds.add(stat.course.id)) {
      orderedIds.add(stat.course.id);
    }
  }

  final colors = assignCourseColors(
    courseIds: statsByCourseId.keys,
    savedKeys: {for (final pref in prefs) pref.courseId: pref.accentKey},
  );
  return [
    for (var index = 0; index < orderedIds.length; index += 1)
      _toResolvedCourseCard(
        statsByCourseId[orderedIds[index]]!,
        prefByCourseId[orderedIds[index]],
        defaultSortOrder: defaultSortOrderByCourseId[orderedIds[index]]!,
      ).copyWith(
        accentKey:
            prefByCourseId[orderedIds[index]]?.accentKey ??
            colors[orderedIds[index]],
      ),
  ];
}

ResolvedCourseCardModel _toResolvedCourseCard(
  CourseStats stats,
  db.CourseDisplayPref? pref, {
  required int defaultSortOrder,
}) {
  return ResolvedCourseCardModel(
    course: stats.course,
    unreadNotifications: stats.unreadNotifications,
    pendingHomeworks: stats.pendingHomeworks,
    totalFiles: stats.totalFiles,
    defaultSortOrder: defaultSortOrder,
    alias: pref?.alias,
    iconKey: pref?.iconKey,
    accentKey: pref?.accentKey,
  );
}
