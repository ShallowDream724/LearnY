import 'approved_icons.dart';
import 'course_icon_definition.dart';
import 'humanities_icons.dart';
import 'science_icons.dart';
import 'technology_icons.dart';

export 'course_icon_definition.dart';

/// Stable keys are persisted in CourseDisplayPrefs. Existing keys remain valid
/// when the drawing changes; adding artwork requires no database migration.
const courseIconOptions = <CourseIconOption>[
  ...approvedCourseIcons,
  ...scienceCourseIcons,
  ...technologyCourseIcons,
  ...humanitiesCourseIcons,
];

const courseIconGroups = [
  '通用',
  '数理',
  '生命科学',
  '实验研究',
  '工程',
  '计算机',
  '人文社科',
  '艺术',
  '运动生活',
];

final _iconsByKey = {for (final icon in courseIconOptions) icon.key: icon};

CourseIconOption? resolveCourseIconOption(String? key) =>
    _iconsByKey[key?.trim()];

CourseIconOption courseIconFor({String? key, String courseName = ''}) =>
    resolveCourseIconOption(key) ?? defaultCourseIcon(courseName);

/// Conservative title matches provide an initial suggestion. A student's
/// explicit choice always wins; unrecognized courses receive the classroom mark.
CourseIconOption defaultCourseIcon(String courseName) {
  final title = courseName.toLowerCase();
  for (final rule in _defaultRules) {
    if (rule.$1.any(title.contains)) return _iconsByKey[rule.$2]!;
  }
  return _iconsByKey['general-class']!;
}

const _defaultRules = <(List<String>, String)>[
  (['有限元'], 'finite-element'),
  (['流体'], 'fluid'),
  (['细胞'], 'cell'),
  (['生物化学'], 'chemistry'),
  (['实验'], 'lab'),
  (['分子生物', '遗传'], 'biology'),
  (['工业系统'], 'systems'),
  (['工程项目'], 'engineering'),
  (['组成原理', '计算机'], 'computer'),
  (['软件'], 'software'),
  (['人工智能', '机器学习'], 'ai'),
  (['数据结构', '算法'], 'algorithm'),
  (['数据库'], 'database'),
  (['网络'], 'network'),
  (['编程', '程序设计'], 'code'),
  (['电路'], 'circuit'),
  (['电子'], 'electronics'),
  (['建筑'], 'structure'),
  (['土力学', '地质'], 'geology'),
  (['土木'], 'civil'),
  (['机械'], 'mechanical'),
  (['材料'], 'material'),
  (['热力'], 'thermodynamics'),
  (['光学'], 'optics'),
  (['量子'], 'quantum'),
  (['天文'], 'astronomy'),
  (['微积分', '高等数学'], 'calculus'),
  (['代数'], 'algebra'),
  (['概率'], 'probability'),
  (['统计'], 'statistics'),
  (['数学'], 'math'),
  (['物理'], 'physics'),
  (['化学'], 'chemistry'),
  (['生物'], 'biology'),
  (['医学', '临床'], 'clinical'),
  (['法律', '法学'], 'law'),
  (['经济'], 'economics'),
  (['金融'], 'finance'),
  (['管理'], 'management'),
  (['心理'], 'psychology'),
  (['哲学'], 'philosophy'),
  (['文学'], 'literature'),
  (['音乐'], 'music'),
  (['戏剧'], 'theatre'),
  (['美术', '艺术'], 'art'),
  (['设计'], 'design'),
  (['历史'], 'history'),
  (['英语', '法语', '日语', '德语', '语言'], 'language'),
  (['游泳'], 'swim'),
  (['篮球'], 'basketball'),
  (['网球'], 'tennis'),
  (['体育'], 'sports'),
];
