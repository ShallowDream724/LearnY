import 'package:flutter/material.dart';

import 'course_icon_canvas.dart';
import 'course_icon_definition.dart';

const technologyCourseIcons = <CourseIconOption>[
  CourseIconOption(
    key: 'civil',
    label: '土木',
    group: '工程',
    draw: _drawCivil,
    keywords: ['土木工程', 'civil', 'construction', 'survey'],
  ),
  CourseIconOption(
    key: 'structure',
    label: '结构',
    group: '工程',
    draw: _drawStructure,
    keywords: ['结构工程', '结构力学', 'structure', 'truss'],
  ),
  CourseIconOption(
    key: 'mechanical',
    label: '机械',
    group: '工程',
    draw: _drawMechanical,
    keywords: ['机械工程', 'mechanical', 'machinery', 'gear'],
  ),
  CourseIconOption(
    key: 'material',
    label: '材料',
    group: '工程',
    draw: _drawMaterial,
    keywords: ['材料科学', 'material', 'crystal', 'lattice'],
  ),
  CourseIconOption(
    key: 'electronics',
    label: '电子',
    group: '工程',
    draw: _drawElectronics,
    keywords: ['电子工程', 'electronics', 'signal', 'oscilloscope'],
  ),
  CourseIconOption(
    key: 'energy',
    label: '能源',
    group: '工程',
    draw: _drawEnergy,
    keywords: ['能源工程', 'energy', 'power', 'generator'],
  ),
  CourseIconOption(
    key: 'environment',
    label: '环境',
    group: '工程',
    draw: _drawEnvironment,
    keywords: ['环境工程', 'environment', 'ecology', 'leaf'],
  ),
  CourseIconOption(
    key: 'transport',
    label: '交通',
    group: '工程',
    draw: _drawTransport,
    keywords: ['交通工程', 'transport', 'transportation', 'road'],
  ),
  CourseIconOption(
    key: 'aerospace',
    label: '航空',
    group: '工程',
    draw: _drawAerospace,
    keywords: ['航空航天', 'aerospace', 'aircraft', 'flight'],
  ),
  CourseIconOption(
    key: 'code',
    label: '编程',
    group: '计算机',
    draw: _drawCode,
    keywords: ['程序设计', 'code', 'coding', 'programming'],
  ),
  CourseIconOption(
    key: 'chip',
    label: '芯片',
    group: '计算机',
    draw: _drawChip,
    keywords: ['微电子', 'chip', 'semiconductor', 'pcb'],
  ),
  CourseIconOption(
    key: 'network',
    label: '网络',
    group: '计算机',
    draw: _drawNetwork,
    keywords: ['计算机网络', 'network', 'topology', 'communication'],
  ),
  CourseIconOption(
    key: 'ai',
    label: '智能',
    group: '计算机',
    draw: _drawAi,
    keywords: ['人工智能', '机器学习', 'ai', 'machine learning'],
  ),
  CourseIconOption(
    key: 'software',
    label: '软件',
    group: '计算机',
    draw: _drawSoftware,
    keywords: ['软件工程', 'software', 'application', 'app'],
  ),
  CourseIconOption(
    key: 'data',
    label: '数据',
    group: '计算机',
    draw: _drawData,
    keywords: ['数据科学', '数据分析', 'data', 'analytics'],
  ),
  CourseIconOption(
    key: 'robot',
    label: '机器人',
    group: '工程',
    draw: _drawRobot,
    keywords: ['机器人学', 'robot', 'robotics', 'automation'],
  ),
  CourseIconOption(
    key: 'control',
    label: '控制',
    group: '工程',
    draw: _drawControl,
    keywords: ['自动控制', '控制工程', 'control', 'feedback'],
  ),
  CourseIconOption(
    key: 'satellite',
    label: '卫星',
    group: '工程',
    draw: _drawSatellite,
    keywords: ['卫星通信', '航天', 'satellite', 'space'],
  ),
  CourseIconOption(
    key: 'manufacturing',
    label: '制造',
    group: '工程',
    draw: _drawManufacturing,
    keywords: ['智能制造', '工业', 'manufacturing', 'factory'],
  ),
  CourseIconOption(
    key: 'circuit',
    label: '电路',
    group: '工程',
    draw: _drawCircuit,
    keywords: ['电路原理', 'circuit', 'schematic', 'electronics'],
  ),
  CourseIconOption(
    key: 'battery',
    label: '电池',
    group: '工程',
    draw: _drawBattery,
    keywords: ['储能', '电化学', 'battery', 'storage'],
  ),
  CourseIconOption(
    key: 'solar',
    label: '光伏',
    group: '工程',
    draw: _drawSolar,
    keywords: ['太阳能', '光伏工程', 'solar', 'photovoltaic'],
  ),
  CourseIconOption(
    key: 'wind',
    label: '风能',
    group: '工程',
    draw: _drawWind,
    keywords: ['风力发电', '新能源', 'wind', 'turbine'],
  ),
  CourseIconOption(
    key: 'bridge',
    label: '桥梁',
    group: '工程',
    draw: _drawBridge,
    keywords: ['桥梁工程', 'bridge', 'civil', 'crossing'],
  ),
  CourseIconOption(
    key: 'architecture',
    label: '建筑',
    group: '工程',
    draw: _drawArchitecture,
    keywords: ['建筑学', '建筑设计', 'architecture', 'building'],
  ),
  CourseIconOption(
    key: 'security',
    label: '安全',
    group: '计算机',
    draw: _drawSecurity,
    keywords: ['网络安全', '信息安全', 'security', 'cybersecurity'],
  ),
  CourseIconOption(
    key: 'algorithm',
    label: '算法',
    group: '计算机',
    draw: _drawAlgorithm,
    keywords: ['算法设计', 'algorithm', 'flowchart', 'logic'],
  ),
  CourseIconOption(
    key: 'database',
    label: '数据库',
    group: '计算机',
    draw: _drawDatabase,
    keywords: ['数据库系统', 'database', 'storage', 'sql'],
  ),
  CourseIconOption(
    key: 'interaction',
    label: '交互',
    group: '计算机',
    draw: _drawInteraction,
    keywords: ['人机交互', '交互设计', 'interaction', 'hci', 'interface'],
  ),
];

void _drawCivil(CourseIconCanvas g) {
  final telescope = Path()
    ..moveTo(9, 16)
    ..lineTo(29, 11)
    ..lineTo(33, 17)
    ..lineTo(12, 22)
    ..close();
  g.area(telescope, .12);
  g.outline(telescope);
  g.line(32, 12, 36, 18);
  g.line(15, 15, 17, 21, secondary: true);
  g.dot(22, 23, 2);
  g.line(22, 25, 12, 41);
  g.line(22, 25, 24, 41);
  g.line(22, 25, 34, 41);
  g.line(16, 34, 30, 34, secondary: true);
}

void _drawStructure(CourseIconCanvas g) {
  final frame = Path()
    ..moveTo(6, 39)
    ..lineTo(24, 8)
    ..lineTo(42, 39)
    ..close();
  g.area(frame, .08);
  g.outline(frame);
  g.line(12, 29, 36, 29);
  g.line(17, 20, 31, 20);
  g.line(6, 39, 31, 20, secondary: true);
  g.line(42, 39, 17, 20, secondary: true);
  g.line(12, 29, 24, 8, secondary: true);
  g.line(36, 29, 24, 8, secondary: true);
  for (final point in [
    (24.0, 8.0),
    (17.0, 20.0),
    (31.0, 20.0),
    (12.0, 29.0),
    (36.0, 29.0),
  ]) {
    g.dot(point.$1, point.$2, 1.45);
  }
}

void _drawMechanical(CourseIconCanvas g) {
  g.circle(19, 27, 10);
  g.circle(19, 27, 3, secondary: true);
  g.circle(34, 16, 6.5);
  g.circle(34, 16, 2, secondary: true);
  for (final line in [
    (19.0, 13.0, 19.0, 17.0),
    (19.0, 37.0, 19.0, 41.0),
    (5.0, 27.0, 9.0, 27.0),
    (29.0, 27.0, 33.0, 27.0),
    (9.0, 17.0, 12.0, 20.0),
    (26.0, 34.0, 29.0, 37.0),
    (9.0, 37.0, 12.0, 34.0),
    (26.0, 20.0, 29.0, 17.0),
    (34.0, 6.0, 34.0, 9.5),
    (34.0, 22.5, 34.0, 26.0),
    (24.0, 16.0, 27.5, 16.0),
    (40.5, 16.0, 43.0, 16.0),
  ]) {
    g.line(line.$1, line.$2, line.$3, line.$4);
  }
  g.line(12, 27, 26, 27, secondary: true);
  g.line(19, 20, 19, 34, secondary: true);
}

void _drawMaterial(CourseIconCanvas g) {
  final top = Path()
    ..moveTo(10, 15)
    ..lineTo(19, 8)
    ..lineTo(36, 8)
    ..lineTo(27, 15)
    ..close();
  final side = Path()
    ..moveTo(27, 15)
    ..lineTo(36, 8)
    ..lineTo(36, 26)
    ..lineTo(27, 33)
    ..close();
  final front = Path()
    ..moveTo(10, 15)
    ..lineTo(27, 15)
    ..lineTo(27, 33)
    ..lineTo(10, 33)
    ..close();
  g.area(top, .08);
  g.area(side, .15);
  g.outline(top);
  g.outline(side);
  g.outline(front);
  g.line(10, 33, 19, 26, secondary: true);
  g.line(19, 8, 19, 26, secondary: true);
  g.line(19, 26, 36, 26, secondary: true);
  g.line(10, 15, 36, 26, secondary: true);
  g.line(27, 15, 19, 26, secondary: true);
  for (final point in [
    (10.0, 15.0),
    (19.0, 8.0),
    (36.0, 8.0),
    (27.0, 15.0),
    (10.0, 33.0),
    (19.0, 26.0),
    (36.0, 26.0),
    (27.0, 33.0),
  ]) {
    g.dot(point.$1, point.$2, 1.35);
  }
  g.circle(23, 21, 2.5, secondary: true);
}

void _drawElectronics(CourseIconCanvas g) {
  final screen = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 8, 36, 27),
        const Radius.circular(4),
      ),
    );
  g.area(screen, .07);
  g.outline(screen);
  g.outline(
    Path()
      ..moveTo(10, 23)
      ..lineTo(15, 23)
      ..lineTo(19, 15)
      ..lineTo(24, 29)
      ..lineTo(28, 20)
      ..lineTo(32, 23)
      ..lineTo(38, 23),
  );
  g.line(12, 39, 36, 39);
  g.line(18, 35, 18, 39, secondary: true);
  g.line(30, 35, 30, 39, secondary: true);
  g.dot(35, 13, 1.4, secondary: true);
}

void _drawEnergy(CourseIconCanvas g) {
  final rotor = Path()
    ..addOval(Rect.fromCircle(center: const Offset(24, 25), radius: 14));
  g.area(rotor, .08);
  g.outline(rotor);
  g.outline(
    Path()
      ..moveTo(27, 8)
      ..lineTo(17, 25)
      ..lineTo(24, 25)
      ..lineTo(20, 41)
      ..lineTo(33, 21)
      ..lineTo(26, 21)
      ..close(),
  );
  g.outline(
    Path()
      ..moveTo(9, 13)
      ..quadraticBezierTo(5, 18, 6, 25),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(39, 36)
      ..quadraticBezierTo(43, 31, 42, 24),
    secondary: true,
  );
}

void _drawEnvironment(CourseIconCanvas g) {
  final leaf = Path()
    ..moveTo(8, 34)
    ..cubicTo(8, 18, 21, 8, 40, 8)
    ..cubicTo(39, 25, 29, 38, 14, 38)
    ..cubicTo(11, 38, 9, 36, 8, 34)
    ..close();
  g.area(leaf, .12);
  g.outline(leaf);
  g.outline(
    Path()
      ..moveTo(9, 39)
      ..cubicTo(18, 29, 27, 20, 39, 9),
  );
  g.line(18, 29, 17, 19, secondary: true);
  g.line(24, 23, 34, 23, secondary: true);
  g.outline(
    Path()
      ..moveTo(15, 42)
      ..cubicTo(20, 39, 25, 43, 30, 41)
      ..cubicTo(34, 39, 38, 42, 42, 40),
    secondary: true,
  );
}

void _drawTransport(CourseIconCanvas g) {
  final road = Path()
    ..moveTo(18, 6)
    ..lineTo(30, 6)
    ..lineTo(42, 42)
    ..lineTo(6, 42)
    ..close();
  g.area(road, .09);
  g.outline(road);
  g.line(18, 6, 6, 42);
  g.line(30, 6, 42, 42);
  for (final segment in [
    (24.0, 8.0, 24.0, 13.0),
    (24.0, 18.0, 24.0, 25.0),
    (24.0, 31.0, 24.0, 40.0),
  ]) {
    g.line(segment.$1, segment.$2, segment.$3, segment.$4, secondary: true);
  }
  g.line(11, 34, 37, 34, secondary: true);
}

void _drawAerospace(CourseIconCanvas g) {
  final aircraft = Path()
    ..moveTo(24, 5)
    ..cubicTo(27, 10, 27, 16, 27, 22)
    ..lineTo(42, 29)
    ..lineTo(42, 33)
    ..lineTo(27, 29)
    ..lineTo(27, 38)
    ..lineTo(34, 42)
    ..lineTo(34, 43)
    ..lineTo(24, 40)
    ..lineTo(14, 43)
    ..lineTo(14, 42)
    ..lineTo(21, 38)
    ..lineTo(21, 29)
    ..lineTo(6, 33)
    ..lineTo(6, 29)
    ..lineTo(21, 22)
    ..cubicTo(21, 16, 21, 10, 24, 5)
    ..close();
  g.area(aircraft, .12);
  g.outline(aircraft);
  g.line(24, 10, 24, 37, secondary: true);
  g.line(17, 40, 31, 40, secondary: true);
}

void _drawCode(CourseIconCanvas g) {
  g.outline(
    Path()
      ..moveTo(17, 11)
      ..lineTo(7, 24)
      ..lineTo(17, 37),
  );
  g.outline(
    Path()
      ..moveTo(31, 11)
      ..lineTo(41, 24)
      ..lineTo(31, 37),
  );
  g.line(28, 7, 20, 41);
  g.line(13, 42, 35, 42, secondary: true);
}

void _drawChip(CourseIconCanvas g) {
  final board = Path()
    ..moveTo(7, 8)
    ..lineTo(36, 8)
    ..lineTo(41, 13)
    ..lineTo(41, 40)
    ..lineTo(7, 40)
    ..close();
  final package = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 17, 13, 13),
        const Radius.circular(2),
      ),
    );
  g.area(board, .06);
  g.area(package, .15);
  g.outline(board);
  g.outline(package);
  g.line(18, 20, 12, 20, secondary: true);
  g.line(12, 20, 12, 13, secondary: true);
  g.line(18, 27, 13, 27, secondary: true);
  g.line(13, 27, 13, 35, secondary: true);
  g.line(31, 20, 36, 20, secondary: true);
  g.line(36, 20, 36, 13, secondary: true);
  g.line(31, 27, 36, 27, secondary: true);
  g.line(36, 27, 36, 35, secondary: true);
  for (final point in [
    (12.0, 13.0),
    (13.0, 35.0),
    (36.0, 13.0),
    (36.0, 35.0),
  ]) {
    g.circle(point.$1, point.$2, 1.5, secondary: true);
  }
  g.line(21, 20, 28, 27, secondary: true);
  g.line(28, 20, 21, 27, secondary: true);
}

void _drawNetwork(CourseIconCanvas g) {
  for (final edge in [
    (24.0, 23.0, 12.0, 11.0),
    (24.0, 23.0, 37.0, 12.0),
    (24.0, 23.0, 9.0, 34.0),
    (24.0, 23.0, 26.0, 40.0),
    (24.0, 23.0, 40.0, 34.0),
    (12.0, 11.0, 37.0, 12.0),
    (9.0, 34.0, 26.0, 40.0),
    (26.0, 40.0, 40.0, 34.0),
  ]) {
    g.line(edge.$1, edge.$2, edge.$3, edge.$4, secondary: true);
  }
  for (final node in [
    (12.0, 11.0, 3.0),
    (37.0, 12.0, 3.0),
    (9.0, 34.0, 3.0),
    (26.0, 40.0, 3.0),
    (40.0, 34.0, 3.0),
  ]) {
    g.circle(node.$1, node.$2, node.$3);
  }
  final hub = Path()
    ..addOval(Rect.fromCircle(center: const Offset(24, 23), radius: 5));
  g.area(hub, .16);
  g.outline(hub);
  g.dot(24, 23, 1.5);
}

void _drawAi(CourseIconCanvas g) {
  final brain = Path()
    ..moveTo(24, 10)
    ..cubicTo(20, 5, 13, 8, 13, 13)
    ..cubicTo(7, 13, 6, 21, 10, 24)
    ..cubicTo(6, 29, 10, 36, 15, 35)
    ..cubicTo(16, 42, 22, 42, 24, 37)
    ..cubicTo(26, 42, 32, 42, 33, 35)
    ..cubicTo(39, 36, 42, 29, 38, 24)
    ..cubicTo(42, 20, 40, 13, 35, 13)
    ..cubicTo(35, 8, 28, 5, 24, 10)
    ..close();
  g.area(brain, .08);
  g.outline(brain);
  g.line(24, 10, 24, 37, secondary: true);
  for (final edge in [
    (15.0, 17.0, 21.0, 22.0),
    (21.0, 22.0, 16.0, 30.0),
    (21.0, 22.0, 24.0, 28.0),
    (33.0, 17.0, 28.0, 23.0),
    (28.0, 23.0, 34.0, 30.0),
    (28.0, 23.0, 24.0, 28.0),
  ]) {
    g.line(edge.$1, edge.$2, edge.$3, edge.$4, secondary: true);
  }
  for (final node in [
    (15.0, 17.0),
    (21.0, 22.0),
    (16.0, 30.0),
    (33.0, 17.0),
    (28.0, 23.0),
    (34.0, 30.0),
    (24.0, 28.0),
  ]) {
    g.dot(node.$1, node.$2, 1.35);
  }
}

void _drawSoftware(CourseIconCanvas g) {
  final window = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 8, 34, 29),
        const Radius.circular(4),
      ),
    );
  g.area(window, .07);
  g.outline(window);
  g.line(7, 15, 41, 15);
  g.dot(12, 11.5, 1.1, secondary: true);
  g.dot(16, 11.5, 1.1, secondary: true);
  final sidebar = Path()..addRect(const Rect.fromLTWH(11, 20, 8, 12));
  final module = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(23, 20, 13, 7),
        const Radius.circular(1.5),
      ),
    );
  g.area(sidebar, .14);
  g.outline(sidebar, secondary: true);
  g.area(module, .1);
  g.outline(module, secondary: true);
  g.line(24, 31, 35, 31, secondary: true);
  g.line(12, 41, 36, 41);
  g.line(16, 37, 16, 41, secondary: true);
  g.line(32, 37, 32, 41, secondary: true);
}

void _drawData(CourseIconCanvas g) {
  g.line(8, 8, 8, 40);
  g.line(8, 40, 42, 40);
  final area = Path()
    ..moveTo(9, 35)
    ..cubicTo(16, 34, 17, 25, 23, 27)
    ..cubicTo(30, 29, 31, 14, 40, 11)
    ..lineTo(40, 40)
    ..lineTo(9, 40)
    ..close();
  g.area(area, .1);
  g.outline(
    Path()
      ..moveTo(9, 35)
      ..cubicTo(16, 34, 17, 25, 23, 27)
      ..cubicTo(30, 29, 31, 14, 40, 11),
  );
  for (final point in [
    (12.0, 32.0),
    (17.0, 29.0),
    (23.0, 28.0),
    (28.0, 25.0),
    (33.0, 17.0),
    (40.0, 11.0),
  ]) {
    g.dot(point.$1, point.$2, 1.65);
  }
  g.line(8, 31, 12, 31, secondary: true);
  g.line(17, 40, 17, 36, secondary: true);
}

void _drawRobot(CourseIconCanvas g) {
  final head = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 12, 26, 22),
        const Radius.circular(5),
      ),
    );
  g.area(head, .11);
  g.outline(head);
  g.line(24, 12, 24, 8);
  g.circle(24, 6.5, 1.5);
  g.circle(18, 22, 2);
  g.circle(30, 22, 2);
  g.outline(
    Path()
      ..moveTo(17, 28)
      ..quadraticBezierTo(24, 33, 31, 28),
    secondary: true,
  );
  g.line(11, 20, 7, 20);
  g.line(37, 20, 41, 20);
  g.line(17, 34, 17, 40);
  g.line(31, 34, 31, 40);
  g.line(13, 41, 21, 41);
  g.line(27, 41, 35, 41);
}

void _drawControl(CourseIconCanvas g) {
  g.outline(
    Path()
      ..moveTo(9, 25)
      ..cubicTo(9, 15, 17, 8, 27, 9)
      ..cubicTo(33, 9, 37, 12, 40, 17),
  );
  g.outline(
    Path()
      ..moveTo(39, 12)
      ..lineTo(40, 17)
      ..lineTo(35, 18),
  );
  g.outline(
    Path()
      ..moveTo(39, 23)
      ..cubicTo(39, 33, 31, 40, 21, 39)
      ..cubicTo(15, 39, 11, 36, 8, 31),
  );
  g.outline(
    Path()
      ..moveTo(9, 36)
      ..lineTo(8, 31)
      ..lineTo(13, 30),
  );
  g.circle(24, 24, 7);
  g.circle(24, 24, 2, secondary: true);
  g.line(24, 17, 24, 13, secondary: true);
  g.line(31, 24, 35, 24, secondary: true);
  g.line(24, 31, 24, 35, secondary: true);
  g.line(17, 24, 13, 24, secondary: true);
}

void _drawSatellite(CourseIconCanvas g) {
  final body = Path()
    ..moveTo(19, 17)
    ..lineTo(30, 14)
    ..lineTo(33, 27)
    ..lineTo(22, 30)
    ..close();
  final leftPanel = Path()
    ..moveTo(8, 18)
    ..lineTo(18, 16)
    ..lineTo(21, 29)
    ..lineTo(11, 32)
    ..close();
  final rightPanel = Path()
    ..moveTo(31, 15)
    ..lineTo(40, 12)
    ..lineTo(43, 25)
    ..lineTo(33, 28)
    ..close();
  g.area(body, .16);
  g.area(leftPanel, .07);
  g.area(rightPanel, .07);
  g.outline(body);
  g.outline(leftPanel);
  g.outline(rightPanel);
  g.line(13, 17, 16, 30, secondary: true);
  g.line(36, 14, 39, 26, secondary: true);
  g.line(21, 22, 32, 19, secondary: true);
  g.outline(
    Path()
      ..moveTo(21, 14)
      ..quadraticBezierTo(24, 7, 31, 8),
  );
  g.line(24, 13, 19, 8, secondary: true);
  g.dot(19, 8, 1.6);
  g.outline(
    Path()
      ..moveTo(12, 38)
      ..quadraticBezierTo(25, 45, 39, 36),
    secondary: true,
  );
}

void _drawManufacturing(CourseIconCanvas g) {
  final factory = Path()
    ..moveTo(7, 40)
    ..lineTo(7, 22)
    ..lineTo(16, 17)
    ..lineTo(16, 23)
    ..lineTo(25, 17)
    ..lineTo(25, 23)
    ..lineTo(34, 17)
    ..lineTo(34, 40)
    ..close();
  g.area(factory, .1);
  g.outline(factory);
  final chimney = Path()
    ..moveTo(10, 20)
    ..lineTo(11, 7)
    ..lineTo(18, 7)
    ..lineTo(19, 19);
  g.outline(chimney);
  g.outline(
    Path()
      ..moveTo(13, 7)
      ..cubicTo(11, 5, 18, 5, 16, 8),
    secondary: true,
  );
  for (final x in [12.0, 20.0, 28.0]) {
    final window = Path()..addRect(Rect.fromLTWH(x, 29, 5, 5));
    g.area(window, .16);
    g.outline(window, secondary: true);
  }
  g.line(5, 40, 43, 40);
}

void _drawCircuit(CourseIconCanvas g) {
  g.line(8, 12, 14, 12);
  final resistor = Path()
    ..moveTo(14, 12)
    ..lineTo(17, 8)
    ..lineTo(21, 16)
    ..lineTo(25, 8)
    ..lineTo(29, 16)
    ..lineTo(32, 12);
  g.outline(resistor);
  g.line(32, 12, 40, 12);
  g.line(40, 12, 40, 24);
  g.line(36, 24, 43, 24);
  g.line(36, 28, 43, 28);
  g.line(40, 28, 40, 37);
  g.line(40, 37, 29, 37);
  g.circle(24, 37, 5);
  g.line(19, 37, 8, 37);
  g.line(8, 37, 8, 28);
  g.circle(8, 24, 1.5);
  g.circle(17, 20, 1.5);
  g.line(9, 23, 16, 20);
  g.line(17, 20, 17, 24, secondary: true);
  g.line(8, 12, 8, 22);
  g.line(21, 34, 27, 40, secondary: true);
  g.line(27, 34, 21, 40, secondary: true);
}

void _drawBattery(CourseIconCanvas g) {
  final body = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(11, 9, 26, 33),
        const Radius.circular(5),
      ),
    );
  final charge = Path()
    ..moveTo(11, 30)
    ..quadraticBezierTo(18, 27, 24, 30)
    ..quadraticBezierTo(31, 33, 37, 29)
    ..lineTo(37, 37)
    ..quadraticBezierTo(37, 42, 32, 42)
    ..lineTo(16, 42)
    ..quadraticBezierTo(11, 42, 11, 37)
    ..close();
  g.area(charge, .18);
  g.outline(body);
  g.line(19, 6, 29, 6);
  g.line(21, 6, 21, 9);
  g.line(27, 6, 27, 9);
  g.outline(
    Path()
      ..moveTo(27, 14)
      ..lineTo(20, 24)
      ..lineTo(25, 24)
      ..lineTo(21, 32),
    secondary: true,
  );
  g.line(14, 30, 34, 30, secondary: true);
}

void _drawSolar(CourseIconCanvas g) {
  g.circle(36, 11, 5);
  for (final ray in [
    (36.0, 5.0, 36.0, 6.0),
    (36.0, 16.0, 36.0, 18.0),
    (29.0, 11.0, 31.0, 11.0),
    (41.0, 11.0, 43.0, 11.0),
    (31.0, 6.0, 32.5, 7.5),
    (39.5, 14.5, 41.0, 16.0),
  ]) {
    g.line(ray.$1, ray.$2, ray.$3, ray.$4, secondary: true);
  }
  final panel = Path()
    ..moveTo(8, 18)
    ..lineTo(32, 18)
    ..lineTo(39, 36)
    ..lineTo(13, 36)
    ..close();
  g.area(panel, .12);
  g.outline(panel);
  g.line(20, 18, 25, 36, secondary: true);
  g.line(27, 18, 32, 36, secondary: true);
  g.line(10, 24, 35, 24, secondary: true);
  g.line(12, 30, 37, 30, secondary: true);
  g.line(25, 36, 25, 42);
  g.line(17, 42, 33, 42);
}

void _drawWind(CourseIconCanvas g) {
  g.circle(24, 20, 2.5);
  final bladeA = Path()
    ..moveTo(24, 17.5)
    ..cubicTo(23, 12, 24, 7, 28, 5)
    ..cubicTo(32, 10, 30, 16, 26, 20);
  final bladeB = Path()
    ..moveTo(26, 21.5)
    ..cubicTo(31, 21, 37, 23, 39, 27)
    ..cubicTo(34, 31, 28, 28, 24, 22.5);
  final bladeC = Path()
    ..moveTo(22, 21.5)
    ..cubicTo(19, 26, 14, 29, 9, 27)
    ..cubicTo(10, 21, 16, 18, 22, 19);
  g.area(bladeA, .1);
  g.area(bladeB, .16);
  g.area(bladeC, .07);
  g.outline(bladeA);
  g.outline(bladeB);
  g.outline(bladeC);
  g.line(24, 22.5, 21, 41);
  g.line(24, 22.5, 29, 41);
  g.line(16, 41, 34, 41);
}

void _drawBridge(CourseIconCanvas g) {
  g.line(6, 39, 42, 39);
  g.line(6, 33, 42, 33);
  g.line(12, 14, 12, 39);
  g.line(36, 14, 36, 39);
  g.line(9, 14, 15, 14);
  g.line(33, 14, 39, 14);
  g.outline(
    Path()
      ..moveTo(6, 17)
      ..cubicTo(16, 17, 15, 29, 24, 29)
      ..cubicTo(33, 29, 32, 17, 42, 17),
  );
  for (final x in [8.0, 18.0, 24.0, 30.0, 40.0]) {
    final top = x == 24 ? 29.0 : (x == 18 || x == 30 ? 25.0 : 18.0);
    g.line(x, top, x, 33, secondary: true);
  }
  g.outline(
    Path()
      ..moveTo(6, 39)
      ..quadraticBezierTo(12, 43, 18, 39)
      ..quadraticBezierTo(24, 35, 30, 39)
      ..quadraticBezierTo(36, 43, 42, 39),
    secondary: true,
  );
}

void _drawArchitecture(CourseIconCanvas g) {
  final facade = Path()
    ..moveTo(8, 20)
    ..lineTo(24, 8)
    ..lineTo(40, 20)
    ..lineTo(40, 41)
    ..lineTo(8, 41)
    ..close();
  g.area(facade, .08);
  g.outline(facade);
  g.line(6, 20, 42, 20);
  g.line(12, 20, 12, 41, secondary: true);
  g.line(36, 20, 36, 41, secondary: true);
  final door = Path()
    ..moveTo(19, 41)
    ..lineTo(19, 32)
    ..quadraticBezierTo(24, 24, 29, 32)
    ..lineTo(29, 41);
  g.outline(door);
  for (final x in [16.0, 32.0]) {
    final window = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 3, 24, 6, 6),
          const Radius.circular(1),
        ),
      );
    g.area(window, .15);
    g.outline(window, secondary: true);
  }
  g.line(6, 41, 42, 41);
}

void _drawSecurity(CourseIconCanvas g) {
  final shield = Path()
    ..moveTo(24, 6)
    ..cubicTo(30, 11, 36, 12, 41, 12)
    ..lineTo(39, 27)
    ..cubicTo(38, 35, 31, 40, 24, 43)
    ..cubicTo(17, 40, 10, 35, 9, 27)
    ..lineTo(7, 12)
    ..cubicTo(13, 12, 19, 11, 24, 6)
    ..close();
  g.area(shield, .1);
  g.outline(shield);
  g.circle(24, 23, 5);
  g.line(24, 28, 24, 34);
  g.dot(24, 23, 1.7);
  g.outline(
    Path()
      ..moveTo(14, 18)
      ..quadraticBezierTo(24, 15, 34, 18),
    secondary: true,
  );
}

void _drawAlgorithm(CourseIconCanvas g) {
  final start = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 6, 14, 7),
        const Radius.circular(3.5),
      ),
    );
  final decision = Path()
    ..moveTo(24, 18)
    ..lineTo(33, 25)
    ..lineTo(24, 32)
    ..lineTo(15, 25)
    ..close();
  final finish = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(17, 36, 14, 7),
        const Radius.circular(3.5),
      ),
    );
  g.area(start, .1);
  g.area(decision, .15);
  g.outline(start);
  g.outline(decision);
  g.outline(finish);
  g.line(24, 13, 24, 18);
  g.line(24, 32, 24, 36);
  g.line(33, 25, 40, 25);
  g.line(40, 25, 40, 40, secondary: true);
  g.line(40, 40, 31, 40, secondary: true);
  g.outline(
    Path()
      ..moveTo(28, 15)
      ..lineTo(24, 18)
      ..lineTo(20, 15),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(28, 33)
      ..lineTo(24, 36)
      ..lineTo(20, 33),
    secondary: true,
  );
}

void _drawDatabase(CourseIconCanvas g) {
  final top = Path()
    ..moveTo(9, 12)
    ..cubicTo(9, 7, 39, 7, 39, 12)
    ..cubicTo(39, 17, 9, 17, 9, 12)
    ..close();
  final body = Path()
    ..moveTo(9, 12)
    ..lineTo(9, 36)
    ..cubicTo(9, 42, 39, 42, 39, 36)
    ..lineTo(39, 12);
  g.area(top, .15);
  g.outline(top);
  g.outline(body);
  g.outline(
    Path()
      ..moveTo(9, 20)
      ..cubicTo(9, 26, 39, 26, 39, 20),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(9, 28)
      ..cubicTo(9, 34, 39, 34, 39, 28),
    secondary: true,
  );
  g.dot(15, 36, 1.4, secondary: true);
  g.line(20, 36, 33, 36, secondary: true);
}

void _drawInteraction(CourseIconCanvas g) {
  final panel = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 7, 36, 27),
        const Radius.circular(4),
      ),
    );
  g.area(panel, .07);
  g.outline(panel);
  g.line(6, 14, 42, 14);
  g.dot(11, 10.5, 1.1, secondary: true);
  final button = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 19, 13, 7),
        const Radius.circular(3.5),
      ),
    );
  g.area(button, .15);
  g.outline(button, secondary: true);
  final cursor = Path()
    ..moveTo(25, 23)
    ..lineTo(38, 37)
    ..lineTo(32, 38)
    ..lineTo(29, 43)
    ..lineTo(25, 42)
    ..lineTo(28, 36)
    ..lineTo(22, 34)
    ..close();
  g.area(cursor, .18);
  g.outline(cursor);
  g.outline(
    Path()
      ..moveTo(30, 19)
      ..quadraticBezierTo(37, 19, 38, 26),
    secondary: true,
  );
}
