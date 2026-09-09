import 'package:flutter/material.dart';

import 'course_icon_canvas.dart';
import 'course_icon_definition.dart';

const scienceCourseIcons = <CourseIconOption>[
  CourseIconOption(
    key: 'math',
    label: '数学',
    group: '数理',
    draw: _drawMath,
    keywords: ['函数', '坐标', '抛物线', 'mathematics', 'function'],
  ),
  CourseIconOption(
    key: 'physics',
    label: '物理',
    group: '数理',
    draw: _drawPhysics,
    keywords: ['原子', '力学', '能量', 'physics', 'atom'],
  ),
  CourseIconOption(
    key: 'statistics',
    label: '统计',
    group: '数理',
    draw: _drawStatistics,
    keywords: ['柱状图', '分布', '数据', 'statistics', 'distribution'],
  ),
  CourseIconOption(
    key: 'analytics',
    label: '分析',
    group: '数理',
    draw: _drawAnalytics,
    keywords: ['趋势', '图表', '数据分析', 'analytics', 'trend'],
  ),
  CourseIconOption(
    key: 'astronomy',
    label: '天文',
    group: '数理',
    draw: _drawAstronomy,
    keywords: ['望远镜', '星空', '宇宙', 'astronomy', 'telescope'],
  ),
  CourseIconOption(
    key: 'medicine',
    label: '医学',
    group: '生命科学',
    draw: _drawMedicine,
    keywords: ['药物', '胶囊', '临床', 'medicine', 'capsule'],
  ),
  CourseIconOption(
    key: 'health',
    label: '健康',
    group: '生命科学',
    draw: _drawHealth,
    keywords: ['心脏', '心电', '护理', 'health', 'heartbeat'],
  ),
  CourseIconOption(
    key: 'experiment-data',
    label: '实验数据',
    group: '实验研究',
    draw: _drawExperimentData,
    keywords: ['试管', '记录', '测量', 'experiment', 'data'],
  ),
  CourseIconOption(
    key: 'geometry',
    label: '几何',
    group: '数理',
    draw: _drawGeometry,
    keywords: ['圆规', '三角形', '作图', 'geometry', 'compass'],
  ),
  CourseIconOption(
    key: 'calculus',
    label: '微积分',
    group: '数理',
    draw: _drawCalculus,
    keywords: ['积分', '导数', '曲线', 'calculus', 'integral'],
  ),
  CourseIconOption(
    key: 'algebra',
    label: '代数',
    group: '数理',
    draw: _drawAlgebra,
    keywords: ['方程', '未知数', '等式', 'algebra', 'equation'],
  ),
  CourseIconOption(
    key: 'probability',
    label: '概率',
    group: '数理',
    draw: _drawProbability,
    keywords: ['随机', '分布', '概率论', 'probability', 'random'],
  ),
  CourseIconOption(
    key: 'optics',
    label: '光学',
    group: '数理',
    draw: _drawOptics,
    keywords: ['透镜', '折射', '光线', 'optics', 'lens'],
  ),
  CourseIconOption(
    key: 'quantum',
    label: '量子',
    group: '数理',
    draw: _drawQuantum,
    keywords: ['量子态', '布洛赫球', '波函数', 'quantum', 'state'],
  ),
  CourseIconOption(
    key: 'magnetism',
    label: '磁学',
    group: '数理',
    draw: _drawMagnetism,
    keywords: ['磁铁', '磁场', '电磁学', 'magnetism', 'magnet'],
  ),
  CourseIconOption(
    key: 'waves',
    label: '波动',
    group: '数理',
    draw: _drawWaves,
    keywords: ['振幅', '频率', '正弦波', 'waves', 'frequency'],
  ),
  CourseIconOption(
    key: 'planet',
    label: '行星',
    group: '数理',
    draw: _drawPlanet,
    keywords: ['星球', '轨道', '太空', 'planet', 'orbit'],
  ),
  CourseIconOption(
    key: 'ecology',
    label: '生态',
    group: '生命科学',
    draw: _drawEcology,
    keywords: ['环境', '循环', '叶片', 'ecology', 'ecosystem'],
  ),
  CourseIconOption(
    key: 'botany',
    label: '植物学',
    group: '生命科学',
    draw: _drawBotany,
    keywords: ['植物', '叶片', '生长', 'botany', 'plant'],
  ),
  CourseIconOption(
    key: 'neuroscience',
    label: '神经科学',
    group: '生命科学',
    draw: _drawNeuroscience,
    keywords: ['大脑', '神经元', '脑科学', 'neuroscience', 'brain'],
  ),
  CourseIconOption(
    key: 'molecule',
    label: '分子',
    group: '实验研究',
    draw: _drawMolecule,
    keywords: ['化学键', '原子', '结构', 'molecule', 'chemistry'],
  ),
  CourseIconOption(
    key: 'genetics',
    label: '遗传学',
    group: '生命科学',
    draw: _drawGenetics,
    keywords: ['基因', '染色体', 'DNA', 'genetics', 'chromosome'],
  ),
  CourseIconOption(
    key: 'immunology',
    label: '免疫学',
    group: '生命科学',
    draw: _drawImmunology,
    keywords: ['抗体', '免疫', '防御', 'immunology', 'antibody'],
  ),
  CourseIconOption(
    key: 'microscope',
    label: '显微镜',
    group: '实验研究',
    draw: _drawMicroscope,
    keywords: ['观察', '镜片', '实验室', 'microscope', 'laboratory'],
  ),
  CourseIconOption(
    key: 'pipette',
    label: '移液',
    group: '实验研究',
    draw: _drawPipette,
    keywords: ['滴管', '取样', '液滴', 'pipette', 'sample'],
  ),
  CourseIconOption(
    key: 'petri',
    label: '培养皿',
    group: '实验研究',
    draw: _drawPetri,
    keywords: ['菌落', '培养', '微生物', 'petri', 'culture'],
  ),
  CourseIconOption(
    key: 'crystal',
    label: '晶体',
    group: '实验研究',
    draw: _drawCrystal,
    keywords: ['晶格', '矿物', '结晶', 'crystal', 'lattice'],
  ),
  CourseIconOption(
    key: 'thermodynamics',
    label: '热力学',
    group: '数理',
    draw: _drawThermodynamics,
    keywords: ['温度', '热量', '能量', 'thermodynamics', 'heat'],
  ),
  CourseIconOption(
    key: 'spectrum',
    label: '光谱',
    group: '实验研究',
    draw: _drawSpectrum,
    keywords: ['棱镜', '色散', '波长', 'spectrum', 'prism'],
  ),
];

void _drawMath(CourseIconCanvas g) {
  g.line(9, 39, 9, 9);
  g.line(7, 37, 41, 37);
  g.line(9, 9, 6.5, 13, secondary: true);
  g.line(9, 9, 11.5, 13, secondary: true);
  g.line(41, 37, 37, 34.5, secondary: true);
  g.line(41, 37, 37, 39.5, secondary: true);
  final area = Path()
    ..moveTo(12, 37)
    ..cubicTo(18, 37, 20, 16, 28, 16)
    ..cubicTo(34, 16, 35, 29, 39, 33)
    ..lineTo(39, 37)
    ..close();
  g.area(area, .09);
  g.outline(
    Path()
      ..moveTo(12, 35)
      ..cubicTo(18, 35, 20, 14, 28, 14)
      ..cubicTo(34, 14, 35, 27, 39, 31),
  );
  g.dot(28, 14, 1.7);
  g.line(17, 34, 17, 39, secondary: true);
  g.line(27, 34, 27, 39, secondary: true);
}

void _drawPhysics(CourseIconCanvas g) {
  final orbitA = Path()
    ..moveTo(7, 24)
    ..cubicTo(7, 16, 16, 11, 25, 12)
    ..cubicTo(35, 13, 42, 19, 41, 25)
    ..cubicTo(40, 32, 31, 36, 22, 35)
    ..cubicTo(13, 34, 7, 29, 7, 24)
    ..close();
  final orbitB = Path()
    ..moveTo(15, 8)
    ..cubicTo(21, 5, 31, 14, 36, 23)
    ..cubicTo(41, 33, 38, 41, 32, 41)
    ..cubicTo(24, 41, 15, 31, 12, 22)
    ..cubicTo(9, 14, 11, 10, 15, 8)
    ..close();
  final orbitC = Path()
    ..moveTo(34, 8)
    ..cubicTo(40, 12, 35, 24, 29, 32)
    ..cubicTo(22, 41, 13, 43, 10, 37)
    ..cubicTo(7, 31, 14, 20, 20, 14)
    ..cubicTo(26, 8, 31, 6, 34, 8)
    ..close();
  g.outline(orbitA);
  g.outline(orbitB, secondary: true);
  g.outline(orbitC, secondary: true);
  g.circle(24, 24, 3.2);
  g.dot(40, 25, 1.8);
  g.dot(15, 8, 1.5, secondary: true);
  g.dot(10, 37, 1.5, secondary: true);
}

void _drawStatistics(CourseIconCanvas g) {
  final bars = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(8, 29, 7, 11),
        const Radius.circular(1.5),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(20.5, 21, 7, 19),
        const Radius.circular(1.5),
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(33, 12, 7, 28),
        const Radius.circular(1.5),
      ),
    );
  g.area(bars, .12);
  g.outline(bars);
  g.line(6, 40, 42, 40);
  g.outline(
    Path()
      ..moveTo(7, 27)
      ..cubicTo(12, 25, 15, 18, 21, 16)
      ..cubicTo(27, 14, 31, 8, 40, 8),
    secondary: true,
  );
  g.dot(21, 16, 1.5);
  g.dot(40, 8, 1.5);
}

void _drawAnalytics(CourseIconCanvas g) {
  final trendArea = Path()
    ..moveTo(8, 37)
    ..lineTo(8, 31)
    ..lineTo(17, 25)
    ..lineTo(25, 28)
    ..lineTo(33, 16)
    ..lineTo(41, 10)
    ..lineTo(41, 37)
    ..close();
  g.area(trendArea, .1);
  g.line(7, 40, 42, 40);
  g.line(7, 40, 7, 9);
  g.outline(
    Path()
      ..moveTo(8, 31)
      ..lineTo(17, 25)
      ..lineTo(25, 28)
      ..lineTo(33, 16)
      ..lineTo(41, 10),
  );
  for (final point in const [
    Offset(8, 31),
    Offset(17, 25),
    Offset(25, 28),
    Offset(33, 16),
    Offset(41, 10),
  ]) {
    g.circle(point.dx, point.dy, 1.8);
  }
  g.line(12, 35, 39, 35, secondary: true);
  g.line(12, 20, 29, 20, secondary: true);
}

void _drawAstronomy(CourseIconCanvas g) {
  final barrel = Path()
    ..moveTo(11, 14)
    ..lineTo(30, 8)
    ..lineTo(35, 19)
    ..lineTo(16, 25)
    ..close();
  g.area(barrel, .12);
  g.outline(barrel);
  g.line(9, 12, 13, 26);
  g.line(29, 7, 34, 20, secondary: true);
  g.line(24, 23, 24, 29);
  g.line(24, 29, 15, 41);
  g.line(24, 29, 33, 41);
  g.line(24, 29, 24, 41, secondary: true);
  g.circle(39, 10, 3.5, secondary: true);
  g.outline(
    Path()
      ..moveTo(39, 5)
      ..lineTo(39, 7)
      ..moveTo(43, 10)
      ..lineTo(42.5, 10)
      ..moveTo(42.5, 6.5)
      ..lineTo(41.5, 7.5),
    secondary: true,
  );
}

void _drawMedicine(CourseIconCanvas g) {
  final capsule = Path()
    ..moveTo(10, 38)
    ..cubicTo(7, 35, 7, 31, 10, 28)
    ..lineTo(28, 10)
    ..cubicTo(31, 7, 35, 7, 38, 10)
    ..cubicTo(41, 13, 41, 17, 38, 20)
    ..lineTo(20, 38)
    ..cubicTo(17, 41, 13, 41, 10, 38)
    ..close();
  final medicineFill = Path()
    ..moveTo(10, 38)
    ..cubicTo(7, 35, 7, 31, 10, 28)
    ..lineTo(19, 19)
    ..lineTo(29, 29)
    ..lineTo(20, 38)
    ..cubicTo(17, 41, 13, 41, 10, 38)
    ..close();
  g.area(medicineFill, .15);
  g.outline(capsule);
  g.line(19, 19, 29, 29);

  final tablet = Path()
    ..addOval(Rect.fromCircle(center: const Offset(37, 36), radius: 4.5));
  g.area(tablet, .07);
  g.outline(tablet, secondary: true);
  g.line(33.5, 36, 40.5, 36, secondary: true);
  g.dot(34.5, 13.5, 1.1, secondary: true);
}

void _drawHealth(CourseIconCanvas g) {
  final heart = Path()
    ..moveTo(24, 41)
    ..cubicTo(19, 36, 8, 29, 8, 18)
    ..cubicTo(8, 8, 20, 6, 24, 15)
    ..cubicTo(28, 6, 40, 8, 40, 18)
    ..cubicTo(40, 29, 29, 36, 24, 41)
    ..close();
  g.area(heart, .08);
  g.outline(heart);
  g.outline(
    Path()
      ..moveTo(9, 24)
      ..lineTo(17, 24)
      ..lineTo(20, 18)
      ..lineTo(24, 31)
      ..lineTo(28, 22)
      ..lineTo(31, 24)
      ..lineTo(39, 24),
  );
  g.dot(24, 15, 1.3, secondary: true);
}

void _drawExperimentData(CourseIconCanvas g) {
  final tube = Path()
    ..moveTo(9, 8)
    ..lineTo(9, 29)
    ..cubicTo(9, 40, 22, 40, 22, 29)
    ..lineTo(22, 8);
  final liquid = Path()
    ..moveTo(9, 25)
    ..quadraticBezierTo(15, 21, 22, 25)
    ..lineTo(22, 30)
    ..cubicTo(22, 39, 9, 39, 9, 30)
    ..close();
  g.area(liquid, .16);
  g.outline(tube);
  g.line(7, 8, 24, 8);
  g.line(29, 39, 29, 17);
  g.line(27, 39, 42, 39);
  g.outline(
    Path()
      ..moveTo(30, 34)
      ..lineTo(34, 29)
      ..lineTo(37, 31)
      ..lineTo(41, 22),
  );
  g.circle(34, 29, 1.5, secondary: true);
  g.circle(41, 22, 1.5);
  g.dot(15, 30, 1.4, secondary: true);
  g.line(29, 19, 33, 19, secondary: true);
}

void _drawGeometry(CourseIconCanvas g) {
  g.circle(25, 28, 12, secondary: true);
  g.outline(
    Path()
      ..moveTo(24, 8)
      ..lineTo(13, 38)
      ..lineTo(36, 38)
      ..lineTo(24, 8)
      ..close(),
  );
  g.circle(24, 8, 2.2);
  g.line(19, 13, 29, 13, secondary: true);
  g.line(25, 28, 35, 35, secondary: true);
  g.dot(25, 28, 1.5);
  final angle = Path()
    ..moveTo(17, 37)
    ..quadraticBezierTo(18, 33, 21.5, 32);
  g.outline(angle, secondary: true);
}

void _drawCalculus(CourseIconCanvas g) {
  final integral = Path()
    ..moveTo(27, 7)
    ..cubicTo(19, 6, 19, 12, 18, 19)
    ..lineTo(15, 35)
    ..cubicTo(14, 41, 10, 43, 6, 40);
  g.outline(integral);
  g.dot(28, 7, 1.5);
  g.dot(6, 40, 1.5);
  final curve = Path()
    ..moveTo(21, 35)
    ..cubicTo(25, 34, 27, 20, 33, 20)
    ..cubicTo(37, 20, 39, 27, 42, 29);
  final area = Path()
    ..moveTo(21, 35)
    ..cubicTo(25, 34, 27, 20, 33, 20)
    ..cubicTo(37, 20, 39, 27, 42, 29)
    ..lineTo(42, 35)
    ..close();
  g.area(area, .11);
  g.outline(curve);
  g.line(21, 35, 43, 35, secondary: true);
  g.line(29, 21, 39, 21, secondary: true);
  g.line(25, 35, 25, 30, secondary: true);
  g.line(32, 35, 32, 21, secondary: true);
  g.line(39, 35, 39, 25, secondary: true);
}

void _drawAlgebra(CourseIconCanvas g) {
  final leftBracket = Path()
    ..moveTo(15, 7)
    ..lineTo(9, 7)
    ..lineTo(9, 41)
    ..lineTo(15, 41);
  final rightBracket = Path()
    ..moveTo(33, 7)
    ..lineTo(39, 7)
    ..lineTo(39, 41)
    ..lineTo(33, 41);
  g.outline(leftBracket);
  g.outline(rightBracket);
  g.outline(
    Path()
      ..moveTo(14, 36)
      ..lineTo(34, 11)
      ..moveTo(34, 11)
      ..lineTo(30, 12)
      ..moveTo(34, 11)
      ..lineTo(33, 15),
    secondary: true,
  );
  for (final point in const [
    Offset(16, 14),
    Offset(24, 14),
    Offset(32, 14),
    Offset(16, 24),
    Offset(24, 24),
    Offset(32, 24),
    Offset(16, 34),
    Offset(24, 34),
    Offset(32, 34),
  ]) {
    final onDiagonal =
        point.dx == point.dy ||
        (point.dx == 16 && point.dy == 14) ||
        (point.dx == 32 && point.dy == 34);
    if (onDiagonal) {
      g.circle(point.dx, point.dy, 1.8);
    } else {
      g.dot(point.dx, point.dy, 1.15, secondary: true);
    }
  }
}

void _drawProbability(CourseIconCanvas g) {
  final frame = Path()
    ..moveTo(24, 7)
    ..lineTo(7, 38)
    ..lineTo(41, 38)
    ..close();
  g.outline(frame);
  for (final point in const [
    Offset(24, 14),
    Offset(20, 20),
    Offset(28, 20),
    Offset(16, 26),
    Offset(24, 26),
    Offset(32, 26),
    Offset(12, 32),
    Offset(20, 32),
    Offset(28, 32),
    Offset(36, 32),
  ]) {
    g.dot(point.dx, point.dy, 1.25, secondary: point.dy < 26);
  }
  g.line(14, 38, 14, 42, secondary: true);
  g.line(21, 38, 21, 42, secondary: true);
  g.line(28, 38, 28, 42, secondary: true);
  g.line(35, 38, 35, 42, secondary: true);
  g.outline(
    Path()
      ..moveTo(18, 42)
      ..quadraticBezierTo(24, 35, 30, 42),
    secondary: true,
  );
}

void _drawOptics(CourseIconCanvas g) {
  final lens = Path()
    ..moveTo(24, 7)
    ..cubicTo(16, 13, 16, 35, 24, 41)
    ..cubicTo(32, 35, 32, 13, 24, 7)
    ..close();
  g.area(lens, .1);
  g.outline(lens);
  g.outline(
    Path()
      ..moveTo(6, 15)
      ..lineTo(24, 15)
      ..lineTo(40, 24),
    secondary: true,
  );
  g.line(6, 24, 42, 24, secondary: true);
  g.outline(
    Path()
      ..moveTo(6, 33)
      ..lineTo(24, 33)
      ..lineTo(40, 24),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(9, 13)
      ..lineTo(12, 15)
      ..lineTo(9, 17),
    secondary: true,
  );
  g.dot(40, 24, 1.4);
}

void _drawQuantum(CourseIconCanvas g) {
  final sphere = Path()
    ..addOval(Rect.fromCircle(center: const Offset(24, 24), radius: 17));
  g.area(sphere, .05);
  g.outline(sphere);
  g.outline(
    Path()
      ..moveTo(7, 24)
      ..cubicTo(15, 17, 33, 17, 41, 24)
      ..cubicTo(33, 31, 15, 31, 7, 24),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(24, 7)
      ..cubicTo(17, 14, 17, 34, 24, 41)
      ..cubicTo(31, 34, 31, 14, 24, 7),
    secondary: true,
  );
  g.line(24, 24, 34, 13);
  g.line(34, 13, 31, 14, secondary: true);
  g.line(34, 13, 33, 16, secondary: true);
  g.dot(24, 24, 2);
  g.circle(17, 30, 1.6, secondary: true);
}

void _drawMagnetism(CourseIconCanvas g) {
  final magnet = Path()
    ..moveTo(9, 10)
    ..lineTo(18, 10)
    ..lineTo(18, 27)
    ..cubicTo(18, 34, 30, 34, 30, 27)
    ..lineTo(30, 10)
    ..lineTo(39, 10)
    ..lineTo(39, 28)
    ..cubicTo(39, 43, 9, 43, 9, 28)
    ..close();
  g.area(magnet, .11);
  g.outline(magnet);
  g.line(9, 18, 18, 18, secondary: true);
  g.line(30, 18, 39, 18, secondary: true);
  g.outline(
    Path()
      ..moveTo(5, 12)
      ..cubicTo(2, 23, 3, 34, 10, 40),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(43, 12)
      ..cubicTo(43, 23, 43, 34, 38, 40),
    secondary: true,
  );
  g.dot(5, 12, 1.3, secondary: true);
  g.dot(43, 12, 1.3, secondary: true);
}

void _drawWaves(CourseIconCanvas g) {
  g.line(7, 9, 7, 39, secondary: true);
  g.line(5, 24, 43, 24, secondary: true);
  g.outline(
    Path()
      ..moveTo(7, 24)
      ..cubicTo(12, 8, 19, 8, 24, 24)
      ..cubicTo(29, 40, 36, 40, 41, 24),
  );
  g.outline(
    Path()
      ..moveTo(7, 30)
      ..cubicTo(12, 20, 17, 20, 22, 30)
      ..cubicTo(27, 40, 32, 40, 37, 30),
    secondary: true,
  );
  g.line(14, 11, 14, 24, secondary: true);
  g.line(14, 11, 11.5, 15, secondary: true);
  g.line(14, 11, 16.5, 15, secondary: true);
  g.line(14, 24, 11.5, 20, secondary: true);
  g.line(14, 24, 16.5, 20, secondary: true);
  g.dot(24, 24, 1.5);
}

void _drawPlanet(CourseIconCanvas g) {
  final globe = Path()
    ..addOval(Rect.fromCircle(center: const Offset(24, 24), radius: 12));
  g.area(globe, .1);
  g.outline(globe);
  g.outline(
    Path()
      ..moveTo(8, 30)
      ..cubicTo(4, 26, 11, 18, 22, 13)
      ..cubicTo(33, 8, 42, 8, 43, 12)
      ..cubicTo(43, 17, 34, 25, 23, 30)
      ..cubicTo(15, 34, 9, 34, 8, 30),
  );
  g.outline(
    Path()
      ..moveTo(17, 15)
      ..quadraticBezierTo(21, 20, 27, 17)
      ..quadraticBezierTo(31, 16, 34, 21),
    secondary: true,
  );
  g.dot(9, 9, 1.5);
  g.line(39, 34, 39, 40, secondary: true);
  g.line(36, 37, 42, 37, secondary: true);
}

void _drawEcology(CourseIconCanvas g) {
  final leaf = Path()
    ..moveTo(11, 30)
    ..cubicTo(10, 17, 20, 9, 37, 8)
    ..cubicTo(38, 24, 28, 35, 15, 34)
    ..close();
  g.area(leaf, .1);
  g.outline(leaf);
  g.outline(
    Path()
      ..moveTo(10, 41)
      ..cubicTo(17, 29, 25, 21, 37, 8),
  );
  g.outline(
    Path()
      ..moveTo(18, 31)
      ..quadraticBezierTo(16, 25, 17, 20)
      ..moveTo(24, 25)
      ..quadraticBezierTo(30, 24, 33, 20),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(8, 14)
      ..cubicTo(4, 19, 5, 26, 9, 30),
    secondary: true,
  );
  g.line(7, 14, 8, 19, secondary: true);
  g.line(7, 14, 12, 15, secondary: true);
  g.outline(
    Path()
      ..moveTo(22, 41)
      ..cubicTo(29, 43, 37, 41, 39, 34),
    secondary: true,
  );
  g.line(39, 34, 35, 37, secondary: true);
  g.line(39, 34, 40, 39, secondary: true);
}

void _drawBotany(CourseIconCanvas g) {
  g.outline(
    Path()
      ..moveTo(24, 41)
      ..cubicTo(24, 31, 22, 21, 24, 8),
  );
  final leftLeaf = Path()
    ..moveTo(23, 28)
    ..cubicTo(17, 19, 10, 19, 8, 20)
    ..cubicTo(9, 28, 15, 32, 23, 28)
    ..close();
  final rightLeaf = Path()
    ..moveTo(24, 19)
    ..cubicTo(29, 10, 37, 10, 40, 12)
    ..cubicTo(39, 20, 32, 24, 24, 19)
    ..close();
  g.area(leftLeaf, .13);
  g.area(rightLeaf, .07);
  g.outline(leftLeaf);
  g.outline(rightLeaf);
  g.line(11, 22, 23, 28, secondary: true);
  g.line(37, 13, 24, 19, secondary: true);
  final soil = Path()
    ..moveTo(14, 36)
    ..lineTo(34, 36)
    ..lineTo(31, 42)
    ..lineTo(17, 42)
    ..close();
  g.area(soil, .1);
  g.outline(soil);
}

void _drawNeuroscience(CourseIconCanvas g) {
  final brain = Path()
    ..moveTo(23, 9)
    ..cubicTo(18, 5, 12, 9, 13, 14)
    ..cubicTo(7, 15, 6, 22, 10, 25)
    ..cubicTo(6, 30, 10, 36, 15, 35)
    ..cubicTo(16, 41, 22, 42, 24, 37)
    ..cubicTo(27, 42, 34, 40, 33, 35)
    ..cubicTo(40, 35, 42, 28, 37, 25)
    ..cubicTo(42, 20, 39, 14, 34, 14)
    ..cubicTo(35, 8, 28, 5, 23, 9)
    ..close();
  g.area(brain, .07);
  g.outline(brain);
  g.outline(
    Path()
      ..moveTo(24, 10)
      ..cubicTo(21, 17, 27, 19, 24, 25)
      ..cubicTo(21, 31, 27, 34, 24, 38),
    secondary: true,
  );
  g.line(13, 18, 18, 22, secondary: true);
  g.line(18, 22, 15, 29, secondary: true);
  g.line(18, 22, 24, 25, secondary: true);
  g.line(30, 17, 34, 22, secondary: true);
  g.line(34, 22, 30, 29, secondary: true);
  for (final point in const [
    Offset(13, 18),
    Offset(18, 22),
    Offset(15, 29),
    Offset(30, 17),
    Offset(34, 22),
    Offset(30, 29),
  ]) {
    g.dot(point.dx, point.dy, 1.3, secondary: true);
  }
}

void _drawMolecule(CourseIconCanvas g) {
  g.line(13, 27, 23, 17);
  g.line(25, 17, 35, 25);
  g.line(14, 29, 21, 38);
  g.line(36, 27, 32, 37, secondary: true);
  g.line(23, 17, 20, 8, secondary: true);
  g.line(35, 25, 42, 17, secondary: true);
  g.circle(12, 28, 4.5);
  g.circle(24, 16, 5.5);
  g.circle(36, 26, 4);
  g.circle(22, 40, 3.5, secondary: true);
  g.circle(31, 39, 3, secondary: true);
  g.circle(19, 7, 2.5, secondary: true);
  g.circle(43, 16, 2.5, secondary: true);
  g.dot(24, 16, 1.5);
}

void _drawGenetics(CourseIconCanvas g) {
  final largeChromosome = Path()
    ..moveTo(10, 6)
    ..cubicTo(14, 10, 15, 16, 18, 20)
    ..cubicTo(21, 16, 22, 10, 26, 6)
    ..lineTo(31, 11)
    ..cubicTo(27, 16, 25, 20, 22, 24)
    ..cubicTo(25, 28, 28, 33, 31, 38)
    ..lineTo(26, 42)
    ..cubicTo(22, 37, 20, 32, 18, 28)
    ..cubicTo(16, 32, 14, 37, 10, 42)
    ..lineTo(5, 38)
    ..cubicTo(8, 33, 11, 28, 14, 24)
    ..cubicTo(11, 20, 9, 16, 5, 11)
    ..close();
  g.area(largeChromosome, .08);
  g.outline(largeChromosome);
  g.circle(18, 24, 2.2);
  g.line(8, 13, 13, 10, secondary: true);
  g.line(23, 10, 28, 13, secondary: true);
  g.line(8, 35, 13, 38, secondary: true);
  g.line(23, 38, 28, 35, secondary: true);

  g.outline(
    Path()
      ..moveTo(36, 13)
      ..cubicTo(36, 19, 41, 21, 41, 25)
      ..cubicTo(41, 29, 36, 31, 36, 36),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(42, 13)
      ..cubicTo(42, 19, 37, 21, 37, 25)
      ..cubicTo(37, 29, 42, 31, 42, 36),
    secondary: true,
  );
  g.circle(39, 25, 1.5, secondary: true);
}

void _drawImmunology(CourseIconCanvas g) {
  final shield = Path()
    ..moveTo(24, 6)
    ..lineTo(39, 12)
    ..lineTo(37, 28)
    ..cubicTo(36, 35, 30, 40, 24, 43)
    ..cubicTo(18, 40, 12, 35, 11, 28)
    ..lineTo(9, 12)
    ..close();
  g.area(shield, .08);
  g.outline(shield);
  g.outline(
    Path()
      ..moveTo(16, 17)
      ..lineTo(24, 25)
      ..lineTo(32, 17)
      ..moveTo(24, 25)
      ..lineTo(24, 35),
  );
  g.circle(16, 17, 2, secondary: true);
  g.circle(32, 17, 2, secondary: true);
  g.circle(24, 35, 2, secondary: true);
  g.circle(40.5, 8.5, 2.5, secondary: true);
  g.line(40.5, 5, 40.5, 6, secondary: true);
  g.line(43, 8.5, 42.5, 8.5, secondary: true);
}

void _drawMicroscope(CourseIconCanvas g) {
  final foot = Path()
    ..moveTo(10, 42)
    ..quadraticBezierTo(10, 37, 17, 37)
    ..lineTo(31, 37)
    ..quadraticBezierTo(37, 37, 39, 42)
    ..close();
  g.area(foot, .12);
  g.outline(foot);
  final arm = Path()
    ..moveTo(27, 15)
    ..cubicTo(39, 15, 42, 29, 31, 37)
    ..lineTo(25, 37)
    ..cubicTo(34, 31, 36, 22, 27, 20)
    ..close();
  g.area(arm, .09);
  g.outline(arm);
  final tube = Path()
    ..moveTo(14, 8)
    ..lineTo(20, 5)
    ..lineTo(28, 19)
    ..lineTo(22, 22)
    ..close();
  g.area(tube, .14);
  g.outline(tube);
  g.line(13, 8, 21, 4);
  g.line(16, 11.5, 22, 8.5, secondary: true);
  g.outline(
    Path()
      ..moveTo(23, 22)
      ..lineTo(23, 25)
      ..lineTo(27, 25)
      ..lineTo(27, 20),
  );
  final stage = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 29, 20, 2.5),
        const Radius.circular(.8),
      ),
    );
  g.area(stage, .12);
  g.outline(stage);
  g.circle(34, 24, 2, secondary: true);
}

void _drawPipette(CourseIconCanvas g) {
  final plunger = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(21, 4, 8, 3.5),
        const Radius.circular(1),
      ),
    );
  g.area(plunger, .16);
  g.outline(plunger);
  g.line(25, 7.5, 25, 11);
  final body = Path()
    ..moveTo(23, 11)
    ..lineTo(27, 11)
    ..quadraticBezierTo(30, 11, 30, 14)
    ..lineTo(30, 23)
    ..quadraticBezierTo(30, 27, 27, 29)
    ..lineTo(23, 29)
    ..quadraticBezierTo(20, 27, 20, 24)
    ..lineTo(20, 14)
    ..quadraticBezierTo(20, 11, 23, 11)
    ..close();
  g.area(body, .1);
  g.outline(body);
  g.outline(
    Path()
      ..moveTo(20, 13)
      ..lineTo(16, 13)
      ..quadraticBezierTo(14, 13, 14, 16),
  );
  g.outline(
    Path()
      ..moveTo(17, 18)
      ..lineTo(17, 29)
      ..quadraticBezierTo(17, 32, 22, 32),
    secondary: true,
  );
  g.outline(
    Path()..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(23, 16, 4, 7),
        const Radius.circular(.8),
      ),
    ),
    secondary: true,
  );
  g.line(24, 19, 26, 19, secondary: true);
  g.outline(
    Path()
      ..moveTo(23, 29)
      ..lineTo(23, 33)
      ..lineTo(24.5, 38)
      ..lineTo(25.5, 38)
      ..lineTo(27, 33)
      ..lineTo(27, 29),
  );
  final drop = Path()
    ..moveTo(25, 40)
    ..cubicTo(24, 41.5, 22, 44, 25, 44)
    ..cubicTo(28, 44, 26, 41.5, 25, 40)
    ..close();
  g.area(drop, .16);
  g.outline(drop, secondary: true);
}

void _drawPetri(CourseIconCanvas g) {
  final dish = Path()
    ..moveTo(7, 22)
    ..cubicTo(7, 14, 15, 10, 24, 10)
    ..cubicTo(33, 10, 41, 14, 41, 22)
    ..lineTo(41, 31)
    ..cubicTo(41, 39, 33, 42, 24, 42)
    ..cubicTo(15, 42, 7, 39, 7, 31)
    ..close();
  g.area(dish, .07);
  g.outline(dish);
  g.outline(
    Path()
      ..moveTo(7, 22)
      ..cubicTo(7, 30, 15, 34, 24, 34)
      ..cubicTo(33, 34, 41, 30, 41, 22)
      ..cubicTo(41, 14, 33, 10, 24, 10)
      ..cubicTo(15, 10, 7, 14, 7, 22),
  );
  g.circle(16, 21, 2.2);
  g.circle(28, 18, 1.7, secondary: true);
  g.circle(33, 26, 2.5);
  g.circle(21, 27, 1.4, secondary: true);
  g.dot(12, 27, 1.1, secondary: true);
  g.dot(36, 17, 1.1, secondary: true);
}

void _drawCrystal(CourseIconCanvas g) {
  final center = Path()
    ..moveTo(24, 6)
    ..lineTo(34, 17)
    ..lineTo(31, 40)
    ..lineTo(17, 40)
    ..lineTo(14, 17)
    ..close();
  final left = Path()
    ..moveTo(14, 17)
    ..lineTo(8, 23)
    ..lineTo(11, 40)
    ..lineTo(17, 40)
    ..close();
  final right = Path()
    ..moveTo(34, 17)
    ..lineTo(41, 22)
    ..lineTo(37, 40)
    ..lineTo(31, 40)
    ..close();
  g.area(center, .09);
  g.area(left, .16);
  g.area(right, .04);
  g.outline(center);
  g.outline(left);
  g.outline(right);
  g.line(14, 17, 24, 22, secondary: true);
  g.line(34, 17, 24, 22, secondary: true);
  g.line(24, 6, 24, 22, secondary: true);
  g.line(24, 22, 31, 40, secondary: true);
  g.line(24, 22, 17, 40, secondary: true);
}

void _drawThermodynamics(CourseIconCanvas g) {
  final thermometer = Path()
    ..moveTo(18, 8)
    ..lineTo(18, 30)
    ..cubicTo(12, 37, 17, 43, 23, 43)
    ..cubicTo(30, 43, 34, 36, 28, 30)
    ..lineTo(28, 8)
    ..cubicTo(28, 3, 18, 3, 18, 8)
    ..close();
  g.area(thermometer, .06);
  g.outline(thermometer);
  g.line(23, 12, 23, 34);
  g.circle(23, 36, 4);
  g.line(28, 13, 33, 13, secondary: true);
  g.line(28, 20, 32, 20, secondary: true);
  g.line(28, 27, 33, 27, secondary: true);
  g.outline(
    Path()
      ..moveTo(37, 9)
      ..cubicTo(43, 14, 33, 19, 39, 24)
      ..cubicTo(43, 29, 35, 34, 40, 39),
    secondary: true,
  );
  g.line(40, 39, 36, 37, secondary: true);
  g.line(40, 39, 40, 35, secondary: true);
}

void _drawSpectrum(CourseIconCanvas g) {
  final prism = Path()
    ..moveTo(23, 8)
    ..lineTo(10, 38)
    ..lineTo(37, 38)
    ..close();
  g.area(prism, .09);
  g.outline(prism);
  g.line(5, 21, 18, 24);
  g.line(18, 24, 38, 15);
  g.line(18, 24, 41, 21, secondary: true);
  g.line(18, 24, 42, 27, secondary: true);
  g.line(18, 24, 40, 33, secondary: true);
  g.line(18, 24, 36, 40);
  g.dot(18, 24, 1.5);
  g.line(5, 21, 8, 19, secondary: true);
  g.line(5, 21, 7, 24, secondary: true);
}
