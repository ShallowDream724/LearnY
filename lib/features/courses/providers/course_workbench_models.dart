import 'package:flutter/material.dart';

import '../../../core/database/database.dart' as db;
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

@immutable
class CourseIconOption {
  const CourseIconOption({
    required this.key,
    required this.label,
    required this.icon,
    required this.group,
  });

  final String key;
  final String label;
  final IconData icon;
  final String group;
}

const courseIconOptions = <CourseIconOption>[
  CourseIconOption(
    key: 'general-class',
    label: '课堂',
    icon: Icons.school_rounded,
    group: '通用',
  ),
  CourseIconOption(
    key: 'general-seminar',
    label: '研讨',
    icon: Icons.forum_rounded,
    group: '通用',
  ),
  CourseIconOption(
    key: 'general-lecture',
    label: '讲座',
    icon: Icons.campaign_rounded,
    group: '通用',
  ),
  CourseIconOption(
    key: 'math',
    label: '数学',
    icon: Icons.calculate_rounded,
    group: '数理',
  ),
  CourseIconOption(
    key: 'physics',
    label: '物理',
    icon: Icons.track_changes_rounded,
    group: '数理',
  ),
  CourseIconOption(
    key: 'statistics',
    label: '统计',
    icon: Icons.query_stats_rounded,
    group: '数理',
  ),
  CourseIconOption(
    key: 'analytics',
    label: '分析',
    icon: Icons.analytics_rounded,
    group: '数理',
  ),
  CourseIconOption(
    key: 'astronomy',
    label: '天文',
    icon: Icons.nights_stay_rounded,
    group: '数理',
  ),
  CourseIconOption(
    key: 'geology',
    label: '地学',
    icon: Icons.terrain_rounded,
    group: '数理',
  ),
  CourseIconOption(
    key: 'chemistry',
    label: '化学',
    icon: Icons.science_rounded,
    group: '化生医',
  ),
  CourseIconOption(
    key: 'biology',
    label: '生物',
    icon: Icons.biotech_rounded,
    group: '化生医',
  ),
  CourseIconOption(
    key: 'medicine',
    label: '医学',
    icon: Icons.medication_rounded,
    group: '化生医',
  ),
  CourseIconOption(
    key: 'clinical',
    label: '临床',
    icon: Icons.local_hospital_rounded,
    group: '化生医',
  ),
  CourseIconOption(
    key: 'health',
    label: '健康',
    icon: Icons.favorite_rounded,
    group: '化生医',
  ),
  CourseIconOption(
    key: 'lab',
    label: '实验',
    icon: Icons.science_rounded,
    group: '实验',
  ),
  CourseIconOption(
    key: 'experiment-data',
    label: '数据实验',
    icon: Icons.science_outlined,
    group: '实验',
  ),
  CourseIconOption(
    key: 'engineering',
    label: '工程',
    icon: Icons.precision_manufacturing_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'civil',
    label: '土木',
    icon: Icons.foundation_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'structure',
    label: '建筑',
    icon: Icons.architecture_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'mechanical',
    label: '机械',
    icon: Icons.handyman_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'material',
    label: '材料',
    icon: Icons.blur_on_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'electronics',
    label: '电子',
    icon: Icons.electrical_services_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'energy',
    label: '能源',
    icon: Icons.bolt_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'environment',
    label: '环境',
    icon: Icons.eco_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'transport',
    label: '交通',
    icon: Icons.train_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'aerospace',
    label: '航空',
    icon: Icons.flight_rounded,
    group: '工程',
  ),
  CourseIconOption(
    key: 'computer',
    label: '计算机',
    icon: Icons.memory_rounded,
    group: '计算机',
  ),
  CourseIconOption(
    key: 'code',
    label: '代码',
    icon: Icons.code_rounded,
    group: '计算机',
  ),
  CourseIconOption(
    key: 'chip',
    label: '芯片',
    icon: Icons.developer_board_rounded,
    group: '计算机',
  ),
  CourseIconOption(
    key: 'network',
    label: '网络',
    icon: Icons.lan_rounded,
    group: '计算机',
  ),
  CourseIconOption(
    key: 'ai',
    label: '智能',
    icon: Icons.psychology_alt_rounded,
    group: '计算机',
  ),
  CourseIconOption(
    key: 'software',
    label: '软件',
    icon: Icons.terminal_rounded,
    group: '计算机',
  ),
  CourseIconOption(
    key: 'data',
    label: '数据',
    icon: Icons.storage_rounded,
    group: '计算机',
  ),
  CourseIconOption(
    key: 'law',
    label: '法律',
    icon: Icons.gavel_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'economics',
    label: '经济',
    icon: Icons.account_balance_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'literature',
    label: '文学',
    icon: Icons.auto_stories_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'music',
    label: '音乐',
    icon: Icons.music_note_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'language',
    label: '语言',
    icon: Icons.translate_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'history',
    label: '历史',
    icon: Icons.history_edu_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'management',
    label: '管理',
    icon: Icons.groups_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'art',
    label: '艺术',
    icon: Icons.palette_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'finance',
    label: '金融',
    icon: Icons.payments_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'philosophy',
    label: '哲学',
    icon: Icons.lightbulb_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'theatre',
    label: '戏剧',
    icon: Icons.theaters_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'media',
    label: '传播',
    icon: Icons.mic_rounded,
    group: '人文社科',
  ),
  CourseIconOption(
    key: 'sports',
    label: '体育',
    icon: Icons.sports_score_rounded,
    group: '生活',
  ),
  CourseIconOption(
    key: 'swim',
    label: '游泳',
    icon: Icons.pool_rounded,
    group: '生活',
  ),
  CourseIconOption(
    key: 'global',
    label: '通识',
    icon: Icons.public_rounded,
    group: '生活',
  ),
];

List<String> get courseIconGroups => {
  for (final option in courseIconOptions) option.group,
}.toList(growable: false);

CourseIconOption? resolveCourseIconOption(String? key) {
  if (key == null || key.trim().isEmpty) {
    return null;
  }
  for (final option in courseIconOptions) {
    if (option.key == key) {
      return option;
    }
  }
  return null;
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
      prefs.where((pref) => statsByCourseId.containsKey(pref.courseId)).toList()
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

  return [
    for (var index = 0; index < orderedIds.length; index += 1)
      _toResolvedCourseCard(
        statsByCourseId[orderedIds[index]]!,
        prefByCourseId[orderedIds[index]],
        defaultSortOrder: defaultSortOrderByCourseId[orderedIds[index]]!,
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
