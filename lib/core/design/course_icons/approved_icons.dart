import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'course_icon_canvas.dart';
import 'course_icon_definition.dart';

const approvedCourseIcons = <CourseIconOption>[
  CourseIconOption(
    key: 'systems',
    label: '系统',
    group: '工程',
    draw: _systems,
    keywords: ['工业', '系统工程', 'system'],
  ),
  CourseIconOption(
    key: 'finite-element',
    label: '曲面',
    group: '工程',
    draw: _mesh,
    keywords: ['有限元', '网格', '力学', 'mesh'],
  ),
  CourseIconOption(
    key: 'chemistry',
    label: '化学',
    group: '生命科学',
    draw: _flask,
    keywords: ['生化', '试剂', '烧瓶', 'chemistry'],
  ),
  CourseIconOption(
    key: 'fluid',
    label: '流体',
    group: '工程',
    draw: _flow,
    keywords: ['流线', '仿真', 'fluid'],
  ),
  CourseIconOption(
    key: 'engineering',
    label: '工程',
    group: '工程',
    draw: _project,
    keywords: ['工程项目', '管理', 'project'],
  ),
  CourseIconOption(
    key: 'computer',
    label: '计算机',
    group: '计算机',
    draw: _chip,
    keywords: ['处理器', '组成原理', 'cpu'],
  ),
  CourseIconOption(
    key: 'lab',
    label: '实验',
    group: '实验研究',
    draw: _vials,
    keywords: ['试管', '研究', 'laboratory'],
  ),
  CourseIconOption(
    key: 'cell',
    label: '细胞',
    group: '生命科学',
    draw: _cell,
    keywords: ['医学', '细胞核', 'cell'],
  ),
  CourseIconOption(
    key: 'law',
    label: '法律',
    group: '人文社科',
    draw: _balance,
    keywords: ['法学', '天平', 'law'],
  ),
  CourseIconOption(
    key: 'swim',
    label: '游泳',
    group: '运动生活',
    draw: _swim,
    keywords: ['体育', '泳池', 'swimming'],
  ),
  CourseIconOption(
    key: 'music',
    label: '音乐',
    group: '艺术',
    draw: _lyre,
    keywords: ['音乐剧', '乐器', '琴', 'music'],
  ),
  CourseIconOption(
    key: 'geology',
    label: '地学',
    group: '数理',
    draw: _strata,
    keywords: ['土力学', '地质', '地层', '土壤'],
  ),
  CourseIconOption(
    key: 'biology',
    label: '生物',
    group: '生命科学',
    draw: _helix,
    keywords: ['分子', 'DNA', '生命', 'biology'],
  ),
  CourseIconOption(
    key: 'clinical',
    label: '临床',
    group: '生命科学',
    draw: _care,
    keywords: ['医学', '听诊器', 'clinical'],
  ),
];

void _systems(CourseIconCanvas g) {
  final top = Path()
    ..moveTo(24, 7)
    ..lineTo(40, 16)
    ..lineTo(24, 25)
    ..lineTo(8, 16)
    ..close();
  final left = Path()
    ..moveTo(8, 16)
    ..lineTo(24, 25)
    ..lineTo(24, 42)
    ..lineTo(8, 33)
    ..close();
  final right = Path()
    ..moveTo(24, 25)
    ..lineTo(40, 16)
    ..lineTo(40, 33)
    ..lineTo(24, 42)
    ..close();
  g.area(top, .09);
  g.area(left, .18);
  g.area(right, .04);
  g.outline(top);
  g.outline(left);
  g.outline(right);
  g.line(16, 11.5, 32, 20.5, secondary: true);
  g.line(16, 20.5, 32, 11.5, secondary: true);
  g.line(16, 20.5, 16, 37.5, secondary: true);
  g.line(32, 20.5, 32, 37.5, secondary: true);
  g.line(8, 24.5, 24, 33.5, secondary: true);
  g.line(24, 33.5, 40, 24.5, secondary: true);
}

void _mesh(CourseIconCanvas g) {
  Offset point(double u, double v) =>
      Offset(24 + 16 * u + 5 * v, 25 + 9 * v - 7 * u * u + 5 * v * v);
  Path curve(bool alongU, double fixed) {
    final path = Path();
    for (var i = 0; i <= 32; i++) {
      final t = -1 + i / 16;
      final p = alongU ? point(t, fixed) : point(fixed, t);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }

  final field = curve(true, -1);
  for (var i = 0; i <= 32; i++) {
    final p = point(1 - i / 16, 1);
    field.lineTo(p.dx, p.dy);
  }
  field.close();
  g.area(field, .09);
  for (var i = 0; i < 5; i++) {
    final v = -1 + i * .5;
    g.outline(curve(true, v), secondary: i > 0 && i < 4);
    g.outline(curve(false, v), secondary: i > 0 && i < 4);
  }
}

void _flask(CourseIconCanvas g) {
  final body = Path()
    ..moveTo(19, 8)
    ..lineTo(19, 18)
    ..cubicTo(18, 22, 9, 30, 10, 35)
    ..quadraticBezierTo(11, 40, 17, 40)
    ..lineTo(31, 40)
    ..quadraticBezierTo(37, 40, 38, 35)
    ..cubicTo(39, 30, 30, 22, 29, 18)
    ..lineTo(29, 8);
  final liquid = Path()
    ..moveTo(12, 30)
    ..cubicTo(19, 25, 29, 34, 36, 29)
    ..quadraticBezierTo(41, 40, 31, 40)
    ..lineTo(17, 40)
    ..quadraticBezierTo(8, 40, 12, 30)
    ..close();
  g.area(liquid, .18);
  g.outline(body);
  g.line(17, 8, 31, 8);
  g.outline(
    Path()
      ..moveTo(12, 30)
      ..cubicTo(19, 25, 29, 34, 36, 29),
    secondary: true,
  );
  g.dot(20, 34, 1.4);
  g.dot(27, 24, 1.2, secondary: true);
  g.line(24, 11, 24, 18, secondary: true);
}

void _flow(CourseIconCanvas g) {
  final wing = Path()
    ..moveTo(15, 26)
    ..cubicTo(19, 19, 30, 20, 37, 24)
    ..cubicTo(29, 28, 20, 30, 15, 26)
    ..close();
  g.area(wing, .2);
  g.outline(wing);
  g.outline(
    Path()
      ..moveTo(6, 14)
      ..cubicTo(17, 14, 22, 9, 42, 14),
  );
  g.outline(
    Path()
      ..moveTo(6, 22)
      ..cubicTo(15, 22, 12, 11, 42, 19),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(6, 30)
      ..cubicTo(13, 30, 15, 38, 42, 30),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(6, 38)
      ..cubicTo(21, 38, 25, 38, 42, 36),
  );
}

void _project(CourseIconCanvas g) {
  final bridge = Path()
    ..moveTo(7, 38)
    ..lineTo(7, 26)
    ..lineTo(16, 26)
    ..lineTo(16, 17)
    ..lineTo(26, 17)
    ..lineTo(26, 8)
    ..lineTo(39, 8)
    ..lineTo(39, 38)
    ..close();
  g.area(bridge, .1);
  g.outline(bridge);
  g.line(16, 26, 16, 38, secondary: true);
  g.line(26, 17, 26, 38, secondary: true);
  g.line(7, 38, 39, 8, secondary: true);
  g.dot(16, 29.6, 2);
  g.dot(26, 20.2, 2);
}

void _chip(CourseIconCanvas g) {
  final face = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(12, 12, 24, 24),
        const Radius.circular(5),
      ),
    );
  g.area(face, .12);
  g.outline(face);
  for (var i = 0; i < 4; i++) {
    final t = 16.5 + i * 5;
    g.line(t, 7, t, 12);
    g.line(t, 36, t, 41);
    g.line(7, t, 12, t);
    g.line(36, t, 41, t);
  }
  final die = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 18, 12, 12),
        const Radius.circular(2),
      ),
    );
  g.area(die, .13);
  g.outline(die, secondary: true);
  g.line(24, 18, 24, 30, secondary: true);
  g.line(18, 24, 30, 24, secondary: true);
}

void _vials(CourseIconCanvas g) {
  final a = Path()
    ..moveTo(10, 11)
    ..lineTo(10, 32)
    ..cubicTo(10, 41, 21, 41, 21, 32)
    ..lineTo(21, 11);
  final b = Path()
    ..moveTo(28, 7)
    ..lineTo(28, 28)
    ..cubicTo(28, 37, 39, 37, 39, 28)
    ..lineTo(39, 7);
  final liquidA = Path()
    ..moveTo(10, 24)
    ..quadraticBezierTo(15, 21, 21, 25)
    ..lineTo(21, 32)
    ..cubicTo(21, 41, 10, 41, 10, 32)
    ..close();
  final liquidB = Path()
    ..moveTo(28, 19)
    ..quadraticBezierTo(34, 22, 39, 18)
    ..lineTo(39, 28)
    ..cubicTo(39, 37, 28, 37, 28, 28)
    ..close();
  g.area(liquidA, .2);
  g.area(liquidB, .09);
  g.outline(a);
  g.outline(b);
  g.line(8, 11, 23, 11);
  g.line(26, 7, 41, 7);
  g.line(10, 19, 14, 19, secondary: true);
  g.line(28, 15, 32, 15, secondary: true);
  g.dot(16, 30, 1.3);
  g.dot(33, 25, 1.2, secondary: true);
}

void _cell(CourseIconCanvas g) {
  final shell = Path()
    ..moveTo(24, 7)
    ..cubicTo(37, 6, 43, 14, 41, 25)
    ..cubicTo(40, 36, 33, 42, 21, 41)
    ..cubicTo(9, 39, 4, 30, 7, 20)
    ..cubicTo(10, 11, 15, 8, 24, 7)
    ..close();
  g.area(shell, .07);
  g.outline(shell);
  final nucleus = Path()
    ..moveTo(24, 16)
    ..cubicTo(33, 14, 33, 24, 29, 29)
    ..cubicTo(25, 34, 16, 31, 17, 24)
    ..cubicTo(18, 20, 19, 17, 24, 16)
    ..close();
  g.area(nucleus, .19);
  g.outline(nucleus, secondary: true);
  g.dot(25, 24, 2);
  g.dot(13, 20, 1.3, secondary: true);
  g.outline(
    Path()
      ..moveTo(13, 30)
      ..quadraticBezierTo(12, 35, 17, 35),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(32, 12)
      ..quadraticBezierTo(37, 14, 36, 18),
    secondary: true,
  );
  g.line(32, 33, 35, 29, secondary: true);
}

void _balance(CourseIconCanvas g) {
  g.line(24, 10, 24, 39);
  g.line(16, 40, 32, 40);
  g.outline(
    Path()
      ..moveTo(8, 17)
      ..quadraticBezierTo(24, 7, 40, 17),
  );
  g.dot(24, 10, 2.1);
  for (final x in [12.0, 36.0]) {
    g.line(x, 15, x - 6, 27, secondary: true);
    g.line(x, 15, x + 6, 27, secondary: true);
    final bowl = Path()
      ..moveTo(x - 7, 27)
      ..quadraticBezierTo(x, 37, x + 7, 27)
      ..close();
    g.area(bowl, .15);
    g.outline(bowl);
  }
}

void _swim(CourseIconCanvas g) {
  g.dot(32, 19, 3.2);
  g.outline(
    Path()
      ..moveTo(8, 26)
      ..lineTo(17, 20)
      ..quadraticBezierTo(20, 18, 23, 22)
      ..lineTo(28, 27),
  );
  g.outline(
    Path()
      ..moveTo(17, 20)
      ..lineTo(12, 15)
      ..quadraticBezierTo(11, 13, 14, 11)
      ..lineTo(21, 7),
  );
  for (final y in [30.0, 38.0]) {
    g.outline(
      Path()
        ..moveTo(6, y)
        ..cubicTo(12, y - 6, 18, y + 6, 24, y)
        ..cubicTo(30, y - 6, 36, y + 6, 42, y),
      secondary: y == 38,
    );
  }
}

void _lyre(CourseIconCanvas g) {
  final frame = Path()
    ..moveTo(12, 8)
    ..cubicTo(5, 8, 7, 18, 12, 20)
    ..cubicTo(16, 23, 12, 34, 20, 38)
    ..lineTo(28, 38)
    ..cubicTo(36, 34, 32, 23, 36, 20)
    ..cubicTo(41, 18, 43, 8, 36, 8);
  g.outline(frame);
  g.line(12, 12, 36, 12);
  final foot = Path()
    ..moveTo(20, 36)
    ..lineTo(28, 36)
    ..lineTo(31, 41)
    ..lineTo(17, 41)
    ..close();
  g.area(foot, .18);
  g.outline(foot, secondary: true);
  for (var i = 0; i < 5; i++) {
    final x = 16.0 + i * 4;
    g.line(x, 12, 20 + i * 2.0, 35, secondary: true);
  }
}

void _strata(CourseIconCanvas g) {
  final face = Path()
    ..moveTo(7, 18)
    ..lineTo(26, 8)
    ..lineTo(42, 16)
    ..lineTo(23, 27)
    ..close();
  g.area(face, .13);
  g.outline(face);
  g.outline(
    Path()
      ..moveTo(7, 25)
      ..lineTo(23, 34)
      ..lineTo(42, 23),
  );
  g.outline(
    Path()
      ..moveTo(7, 32)
      ..lineTo(23, 41)
      ..lineTo(42, 30),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(15, 17)
      ..quadraticBezierTo(20, 19, 25, 15)
      ..quadraticBezierTo(29, 12, 34, 16),
    secondary: true,
  );
  g.line(23, 27, 23, 34, secondary: true);
}

void _helix(CourseIconCanvas g) {
  final left = Path();
  final right = Path();
  for (var i = 0; i <= 64; i++) {
    final y = 6 + i * 36 / 64;
    final offset = 10 * math.cos((y - 6) / 36 * math.pi * 2);
    if (i == 0) {
      left.moveTo(24 - offset, y);
      right.moveTo(24 + offset, y);
    } else {
      left.lineTo(24 - offset, y);
      right.lineTo(24 + offset, y);
    }
  }
  for (var i = 0; i <= 8; i++) {
    final y = 8 + i * 4.0;
    final offset = 10 * math.cos((y - 6) / 36 * math.pi * 2);
    g.line(24 - offset, y, 24 + offset, y, secondary: true);
  }
  g.outline(left);
  g.outline(right);
  g.dot(14, 6, 1.5);
  g.dot(34, 42, 1.5);
}

void _care(CourseIconCanvas g) {
  g.outline(
    Path()
      ..moveTo(10, 9)
      ..lineTo(10, 19)
      ..cubicTo(10, 31, 29, 31, 29, 19)
      ..lineTo(29, 9),
  );
  g.line(10, 9, 14, 9);
  g.line(25, 9, 29, 9);
  g.outline(
    Path()
      ..moveTo(19.5, 28)
      ..lineTo(19.5, 32)
      ..cubicTo(19.5, 44, 38, 44, 38, 32)
      ..lineTo(38, 29),
  );
  final disk = Path()
    ..addOval(Rect.fromCircle(center: const Offset(38, 24), radius: 5));
  g.area(disk, .17);
  g.outline(disk);
  g.dot(38, 24, 1.5, secondary: true);
  g.outline(
    Path()
      ..moveTo(14, 21)
      ..quadraticBezierTo(19, 27, 25, 21),
    secondary: true,
  );
}
