import 'package:flutter/material.dart';

import 'course_icon_canvas.dart';
import 'course_icon_definition.dart';

/// Course symbols for general study, humanities, arts and active life.
const humanitiesCourseIcons = <CourseIconOption>[
  CourseIconOption(
    key: 'general-class',
    label: '课堂',
    group: '通用',
    draw: _generalClass,
    keywords: ['上课', '教室', '黑板', 'class', 'classroom'],
  ),
  CourseIconOption(
    key: 'general-seminar',
    label: '研讨',
    group: '通用',
    draw: _generalSeminar,
    keywords: ['讨论', '交流', '小组', 'seminar', 'discussion'],
  ),
  CourseIconOption(
    key: 'general-lecture',
    label: '讲座',
    group: '通用',
    draw: _generalLecture,
    keywords: ['演讲', '报告', '讲台', 'lecture', 'talk'],
  ),
  CourseIconOption(
    key: 'economics',
    label: '经济',
    group: '人文社科',
    draw: _economics,
    keywords: ['经济学', '市场', '供需', 'economics', 'market'],
  ),
  CourseIconOption(
    key: 'literature',
    label: '文学',
    group: '人文社科',
    draw: _literature,
    keywords: ['阅读', '书籍', '小说', 'literature', 'reading'],
  ),
  CourseIconOption(
    key: 'language',
    label: '语言',
    group: '人文社科',
    draw: _language,
    keywords: ['外语', '口语', '交流', 'language', 'linguistics'],
  ),
  CourseIconOption(
    key: 'history',
    label: '历史',
    group: '人文社科',
    draw: _history,
    keywords: ['文明', '古代', '年代', 'history', 'civilization'],
  ),
  CourseIconOption(
    key: 'management',
    label: '管理',
    group: '人文社科',
    draw: _management,
    keywords: ['组织', '运营', '团队', 'management', 'organization'],
  ),
  CourseIconOption(
    key: 'art',
    label: '艺术',
    group: '艺术',
    draw: _art,
    keywords: ['美术', '绘画', '创作', 'art', 'painting'],
  ),
  CourseIconOption(
    key: 'finance',
    label: '金融',
    group: '人文社科',
    draw: _finance,
    keywords: ['投资', '货币', '银行', 'finance', 'investment'],
  ),
  CourseIconOption(
    key: 'philosophy',
    label: '哲学',
    group: '人文社科',
    draw: _philosophy,
    keywords: ['思想', '思辨', '伦理', 'philosophy', 'thought'],
  ),
  CourseIconOption(
    key: 'theatre',
    label: '戏剧',
    group: '艺术',
    draw: _theatre,
    keywords: ['舞台', '表演', '话剧', 'theatre', 'drama'],
  ),
  CourseIconOption(
    key: 'media',
    label: '传媒',
    group: '人文社科',
    draw: _media,
    keywords: ['传播', '新闻', '广播', 'media', 'communication'],
  ),
  CourseIconOption(
    key: 'sports',
    label: '体育',
    group: '运动生活',
    draw: _sports,
    keywords: ['运动', '竞技', '奖杯', 'sports', 'athletics'],
  ),
  CourseIconOption(
    key: 'global',
    label: '国际',
    group: '人文社科',
    draw: _global,
    keywords: ['世界', '全球', '国际关系', 'global', 'international'],
  ),
  CourseIconOption(
    key: 'sociology',
    label: '社会学',
    group: '人文社科',
    draw: _sociology,
    keywords: ['社会', '群体', '关系', 'sociology', 'society'],
  ),
  CourseIconOption(
    key: 'psychology',
    label: '心理学',
    group: '人文社科',
    draw: _psychology,
    keywords: ['心理', '认知', '心智', 'psychology', 'mind'],
  ),
  CourseIconOption(
    key: 'education',
    label: '教育',
    group: '人文社科',
    draw: _education,
    keywords: ['教学', '学习', '培养', 'education', 'teaching'],
  ),
  CourseIconOption(
    key: 'writing',
    label: '写作',
    group: '人文社科',
    draw: _writing,
    keywords: ['作文', '创作', '笔记', 'writing', 'composition'],
  ),
  CourseIconOption(
    key: 'photography',
    label: '摄影',
    group: '艺术',
    draw: _photography,
    keywords: ['相机', '镜头', '照片', 'photography', 'camera'],
  ),
  CourseIconOption(
    key: 'film',
    label: '电影',
    group: '艺术',
    draw: _film,
    keywords: ['影视', '影片', '胶片', 'film', 'cinema'],
  ),
  CourseIconOption(
    key: 'design',
    label: '设计',
    group: '艺术',
    draw: _design,
    keywords: ['构成', '创意', '视觉', 'design', 'creative'],
  ),
  CourseIconOption(
    key: 'calligraphy',
    label: '书法',
    group: '艺术',
    draw: _calligraphy,
    keywords: ['毛笔', '国画', '笔墨', 'calligraphy', 'brush'],
  ),
  CourseIconOption(
    key: 'basketball',
    label: '篮球',
    group: '运动生活',
    draw: _basketball,
    keywords: ['球类', '篮筐', 'basketball', 'hoop'],
  ),
  CourseIconOption(
    key: 'tennis',
    label: '网球',
    group: '运动生活',
    draw: _tennis,
    keywords: ['球拍', '球类', 'tennis', 'racket'],
  ),
  CourseIconOption(
    key: 'running',
    label: '跑步',
    group: '运动生活',
    draw: _running,
    keywords: ['田径', '慢跑', '健身', 'running', 'jogging'],
  ),
  CourseIconOption(
    key: 'mountain',
    label: '登山',
    group: '运动生活',
    draw: _mountain,
    keywords: ['山峰', '徒步', '户外', 'mountain', 'hiking'],
  ),
  CourseIconOption(
    key: 'compass',
    label: '探索',
    group: '运动生活',
    draw: _compass,
    keywords: ['指南针', '方向', '户外', 'compass', 'navigation'],
  ),
];

void _generalClass(CourseIconCanvas g) {
  final board = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 9, 34, 25),
        const Radius.circular(2),
      ),
    );
  g.area(board, .08);
  g.outline(board);
  g.line(13, 16, 29, 16, secondary: true);
  g.line(13, 21, 24, 21, secondary: true);
  g.outline(
    Path()
      ..moveTo(30, 27)
      ..lineTo(36, 19)
      ..lineTo(34, 30),
    secondary: true,
  );
  g.line(11, 39, 37, 39);
  g.line(17, 34, 15, 39, secondary: true);
  g.line(31, 34, 33, 39, secondary: true);
}

void _generalSeminar(CourseIconCanvas g) {
  final table = Path()..addOval(const Rect.fromLTWH(11, 17, 26, 14));
  g.area(table, .11);
  g.outline(table);
  g.circle(24, 8, 3.2);
  g.circle(9, 25, 3.2);
  g.circle(39, 25, 3.2);
  g.outline(
    Path()
      ..moveTo(18, 14)
      ..quadraticBezierTo(24, 11, 30, 14),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(6, 33)
      ..quadraticBezierTo(9, 37, 14, 37),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(34, 37)
      ..quadraticBezierTo(39, 37, 42, 33),
    secondary: true,
  );
  g.line(18, 23, 30, 23, secondary: true);
}

void _generalLecture(CourseIconCanvas g) {
  final lectern = Path()
    ..moveTo(14, 24)
    ..lineTo(34, 24)
    ..lineTo(31, 40)
    ..lineTo(17, 40)
    ..close();
  g.area(lectern, .12);
  g.outline(lectern);
  g.line(11, 21, 37, 21);
  g.circle(18, 10, 3.5);
  g.outline(
    Path()
      ..moveTo(19, 14)
      ..quadraticBezierTo(22, 16, 23, 21),
  );
  g.outline(
    Path()
      ..moveTo(29, 20)
      ..quadraticBezierTo(30, 14, 35, 12)
      ..lineTo(38, 15),
    secondary: true,
  );
  g.line(24, 27, 24, 36, secondary: true);
}

void _economics(CourseIconCanvas g) {
  g.line(9, 39, 9, 9);
  g.line(9, 39, 41, 39);
  g.outline(
    Path()
      ..moveTo(12, 14)
      ..cubicTo(20, 15, 29, 23, 39, 36),
  );
  g.outline(
    Path()
      ..moveTo(12, 34)
      ..cubicTo(21, 31, 29, 23, 39, 11),
  );
  final lens = Path()
    ..moveTo(20, 24)
    ..quadraticBezierTo(25, 18, 30, 24)
    ..quadraticBezierTo(25, 30, 20, 24)
    ..close();
  g.area(lens, .16);
  g.outline(lens, secondary: true);
  g.dot(25, 24, 1.3);
}

void _literature(CourseIconCanvas g) {
  final left = Path()
    ..moveTo(6, 11)
    ..quadraticBezierTo(15, 8, 24, 15)
    ..lineTo(24, 39)
    ..quadraticBezierTo(15, 32, 6, 35)
    ..close();
  final right = Path()
    ..moveTo(42, 11)
    ..quadraticBezierTo(33, 8, 24, 15)
    ..lineTo(24, 39)
    ..quadraticBezierTo(33, 32, 42, 35)
    ..close();
  g.area(left, .08);
  g.area(right, .15);
  g.outline(left);
  g.outline(right);
  g.outline(
    Path()
      ..moveTo(10, 17)
      ..quadraticBezierTo(16, 15, 21, 19),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(27, 19)
      ..quadraticBezierTo(33, 15, 39, 17),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(10, 24)
      ..quadraticBezierTo(16, 22, 21, 26),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(27, 26)
      ..quadraticBezierTo(33, 22, 39, 24),
    secondary: true,
  );
}

void _language(CourseIconCanvas g) {
  final first = Path()
    ..moveTo(7, 10)
    ..quadraticBezierTo(7, 7, 10, 7)
    ..lineTo(31, 7)
    ..quadraticBezierTo(34, 7, 34, 10)
    ..lineTo(34, 23)
    ..quadraticBezierTo(34, 26, 31, 26)
    ..lineTo(20, 26)
    ..lineTo(13, 32)
    ..lineTo(14, 26)
    ..lineTo(10, 26)
    ..quadraticBezierTo(7, 26, 7, 23)
    ..close();
  g.area(first, .1);
  g.outline(first);
  g.outline(
    Path()
      ..moveTo(26, 31)
      ..lineTo(31, 31)
      ..lineTo(38, 38)
      ..lineTo(37, 31)
      ..quadraticBezierTo(41, 31, 41, 27)
      ..lineTo(41, 19),
  );
  g.line(13, 14, 28, 14, secondary: true);
  g.line(13, 20, 23, 20, secondary: true);
  g.dot(28, 20, 1.2, secondary: true);
}

void _history(CourseIconCanvas g) {
  final pediment = Path()
    ..moveTo(6, 16)
    ..lineTo(24, 7)
    ..lineTo(42, 16)
    ..close();
  g.area(pediment, .12);
  g.outline(pediment);
  g.line(8, 19, 40, 19);
  for (final x in [12.0, 20.0, 28.0, 36.0]) {
    g.line(x, 20, x, 36, secondary: true);
  }
  g.line(7, 37, 41, 37);
  g.line(5, 41, 43, 41);
  g.outline(
    Path()
      ..moveTo(18, 14)
      ..quadraticBezierTo(24, 10, 30, 14),
    secondary: true,
  );
}

void _management(CourseIconCanvas g) {
  final top = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(18, 6, 12, 8),
        const Radius.circular(2),
      ),
    );
  g.area(top, .15);
  g.outline(top);
  g.line(24, 14, 24, 22);
  g.line(10, 22, 38, 22);
  for (final x in [10.0, 24.0, 38.0]) {
    g.line(x, 22, x, 29, secondary: true);
    final node = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x - 5, 29, 10, 9),
          const Radius.circular(2),
        ),
      );
    g.area(node, x == 24 ? .14 : .07);
    g.outline(node, secondary: x != 24);
  }
  g.line(19, 42, 29, 42, secondary: true);
}

void _art(CourseIconCanvas g) {
  final palette = Path()
    ..moveTo(25, 7)
    ..cubicTo(14, 6, 6, 14, 6, 24)
    ..cubicTo(6, 34, 14, 41, 24, 41)
    ..cubicTo(29, 41, 31, 37, 28, 34)
    ..cubicTo(25, 31, 29, 27, 34, 29)
    ..cubicTo(42, 32, 44, 25, 41, 18)
    ..cubicTo(38, 11, 32, 7, 25, 7)
    ..close();
  g.area(palette, .09);
  g.outline(palette);
  g.dot(17, 15, 2);
  g.dot(11.5, 24, 1.7, secondary: true);
  g.dot(18, 33, 1.8, secondary: true);
  g.dot(28, 14, 1.7, secondary: true);
  g.outline(
    Path()
      ..moveTo(31, 36)
      ..lineTo(39, 14)
      ..quadraticBezierTo(40, 11, 42, 10),
  );
}

void _finance(CourseIconCanvas g) {
  final wallet = Path()
    ..moveTo(8, 15)
    ..quadraticBezierTo(8, 11, 12, 11)
    ..lineTo(36, 11)
    ..quadraticBezierTo(40, 11, 40, 15)
    ..lineTo(40, 36)
    ..quadraticBezierTo(40, 40, 36, 40)
    ..lineTo(12, 40)
    ..quadraticBezierTo(8, 40, 8, 36)
    ..close();
  g.area(wallet, .08);
  g.outline(wallet);
  final clasp = Path()
    ..moveTo(27, 22)
    ..lineTo(42, 22)
    ..lineTo(42, 32)
    ..lineTo(27, 32)
    ..quadraticBezierTo(23, 27, 27, 22)
    ..close();
  g.area(clasp, .16);
  g.outline(clasp);
  g.dot(32, 27, 1.5);
  g.circle(19, 14, 7, secondary: true);
  g.line(16, 14, 22, 14, secondary: true);
}

void _philosophy(CourseIconCanvas g) {
  final ribbon = Path()
    ..moveTo(6, 24)
    ..cubicTo(10, 10, 19, 9, 25, 20)
    ..cubicTo(31, 31, 36, 34, 42, 24)
    ..cubicTo(38, 38, 29, 39, 23, 28)
    ..cubicTo(17, 17, 12, 14, 6, 24)
    ..close();
  g.area(ribbon, .12);
  g.outline(ribbon);
  g.outline(
    Path()
      ..moveTo(7.5, 24)
      ..cubicTo(12, 33, 18, 33, 23, 28),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(25, 20)
      ..cubicTo(30, 15, 36, 15, 40.5, 24),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(18, 12.5)
      ..cubicTo(22, 15, 24, 19, 27, 24)
      ..cubicTo(30, 30, 34, 34, 38, 34),
    secondary: true,
  );
}

void _theatre(CourseIconCanvas g) {
  g.outline(
    Path()
      ..moveTo(6, 8)
      ..quadraticBezierTo(13, 13, 18, 13)
      ..lineTo(18, 38)
      ..quadraticBezierTo(12, 35, 8, 40),
  );
  g.outline(
    Path()
      ..moveTo(42, 8)
      ..quadraticBezierTo(35, 13, 30, 13)
      ..lineTo(30, 38)
      ..quadraticBezierTo(36, 35, 40, 40),
  );
  final canopy = Path()
    ..moveTo(6, 8)
    ..quadraticBezierTo(24, 15, 42, 8)
    ..lineTo(42, 14)
    ..quadraticBezierTo(24, 21, 6, 14)
    ..close();
  g.area(canopy, .14);
  g.outline(canopy);
  g.outline(
    Path()
      ..moveTo(18, 38)
      ..quadraticBezierTo(24, 33, 30, 38),
    secondary: true,
  );
  g.line(24, 19, 24, 33, secondary: true);
}

void _media(CourseIconCanvas g) {
  final mast = Path()
    ..moveTo(24, 14)
    ..lineTo(15, 40)
    ..lineTo(33, 40)
    ..close();
  g.area(mast, .09);
  g.outline(mast);
  g.dot(24, 13, 2.2);
  g.line(19, 29, 29, 29, secondary: true);
  g.line(17, 35, 31, 35, secondary: true);
  g.outline(
    Path()
      ..moveTo(16, 17)
      ..quadraticBezierTo(10, 22, 16, 27),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(32, 17)
      ..quadraticBezierTo(38, 22, 32, 27),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(11, 12)
      ..quadraticBezierTo(2, 22, 11, 32),
  );
  g.outline(
    Path()
      ..moveTo(37, 12)
      ..quadraticBezierTo(46, 22, 37, 32),
  );
}

void _sports(CourseIconCanvas g) {
  final cup = Path()
    ..moveTo(14, 9)
    ..lineTo(34, 9)
    ..lineTo(32, 22)
    ..quadraticBezierTo(31, 29, 24, 31)
    ..quadraticBezierTo(17, 29, 16, 22)
    ..close();
  g.area(cup, .13);
  g.outline(cup);
  g.outline(
    Path()
      ..moveTo(14, 13)
      ..lineTo(8, 13)
      ..quadraticBezierTo(8, 24, 18, 24),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(34, 13)
      ..lineTo(40, 13)
      ..quadraticBezierTo(40, 24, 30, 24),
    secondary: true,
  );
  g.line(24, 31, 24, 38);
  g.line(16, 40, 32, 40);
  g.outline(
    Path()
      ..moveTo(19, 16)
      ..quadraticBezierTo(24, 12, 29, 16)
      ..quadraticBezierTo(24, 22, 19, 16),
    secondary: true,
  );
}

void _global(CourseIconCanvas g) {
  g.circle(24, 24, 17);
  g.outline(
    Path()
      ..moveTo(24, 7)
      ..cubicTo(15, 14, 15, 34, 24, 41),
  );
  g.outline(
    Path()
      ..moveTo(24, 7)
      ..cubicTo(33, 14, 33, 34, 24, 41),
  );
  g.outline(
    Path()
      ..moveTo(9, 16)
      ..quadraticBezierTo(24, 22, 39, 16),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(9, 32)
      ..quadraticBezierTo(24, 26, 39, 32),
    secondary: true,
  );
  g.line(7, 24, 41, 24, secondary: true);
}

void _sociology(CourseIconCanvas g) {
  for (final x in [12.0, 36.0]) {
    g.circle(x, 12, 3.5, secondary: true);
    final figure = Path()
      ..moveTo(x - 7, 28)
      ..lineTo(x - 7, 24)
      ..cubicTo(x - 7, 17, x + 7, 17, x + 7, 24)
      ..lineTo(x + 7, 28)
      ..close();
    g.area(figure, .06);
    g.outline(figure, secondary: true);
  }
  g.circle(24, 23, 4);
  final figure = Path()
    ..moveTo(16, 40)
    ..lineTo(16, 35)
    ..cubicTo(16, 28, 32, 28, 32, 35)
    ..lineTo(32, 40)
    ..close();
  g.area(figure, .14);
  g.outline(figure);
}

void _psychology(CourseIconCanvas g) {
  final head = Path()
    ..moveTo(25, 7)
    ..cubicTo(15, 7, 9, 14, 9, 23)
    ..cubicTo(9, 29, 13, 34, 18, 36)
    ..lineTo(18, 42)
    ..lineTo(31, 42)
    ..lineTo(31, 35)
    ..quadraticBezierTo(36, 32, 35, 27)
    ..lineTo(41, 24)
    ..lineTo(36, 19)
    ..cubicTo(35, 11, 31, 7, 25, 7);
  g.area(head, .07);
  g.outline(head);
  final brain = Path()
    ..moveTo(17, 23)
    ..cubicTo(13, 18, 17, 14, 21, 16)
    ..cubicTo(22, 11, 29, 12, 29, 17)
    ..cubicTo(34, 17, 34, 24, 30, 26)
    ..cubicTo(28, 31, 21, 29, 21, 26)
    ..cubicTo(18, 28, 15, 26, 17, 23)
    ..close();
  g.area(brain, .14);
  g.outline(brain);
  g.outline(
    Path()
      ..moveTo(21, 16)
      ..quadraticBezierTo(25, 19, 22, 23)
      ..quadraticBezierTo(26, 25, 30, 22),
    secondary: true,
  );
}

void _education(CourseIconCanvas g) {
  final cap = Path()
    ..moveTo(5, 17)
    ..lineTo(24, 8)
    ..lineTo(43, 17)
    ..lineTo(24, 26)
    ..close();
  g.area(cap, .14);
  g.outline(cap);
  g.outline(
    Path()
      ..moveTo(13, 22)
      ..lineTo(13, 31)
      ..quadraticBezierTo(24, 39, 35, 31)
      ..lineTo(35, 22),
  );
  g.line(43, 17, 43, 31, secondary: true);
  g.dot(43, 34, 2);
  g.outline(
    Path()
      ..moveTo(18, 30)
      ..quadraticBezierTo(24, 34, 30, 30),
    secondary: true,
  );
}

void _writing(CourseIconCanvas g) {
  final page = Path()
    ..moveTo(9, 7)
    ..lineTo(34, 7)
    ..lineTo(39, 12)
    ..lineTo(39, 41)
    ..lineTo(9, 41)
    ..close();
  g.area(page, .06);
  g.outline(page);
  g.line(14, 15, 31, 15, secondary: true);
  g.line(14, 21, 28, 21, secondary: true);
  g.line(14, 27, 24, 27, secondary: true);
  final nib = Path()
    ..moveTo(33, 19)
    ..lineTo(43, 29)
    ..lineTo(31, 39)
    ..lineTo(26, 38)
    ..lineTo(27, 33)
    ..close();
  g.area(nib, .16);
  g.outline(nib);
  g.line(28, 37, 37, 28, secondary: true);
  g.dot(34, 31, 1.2);
}

void _photography(CourseIconCanvas g) {
  final camera = Path()
    ..moveTo(7, 16)
    ..lineTo(15, 16)
    ..lineTo(19, 11)
    ..lineTo(29, 11)
    ..lineTo(33, 16)
    ..lineTo(41, 16)
    ..lineTo(41, 38)
    ..lineTo(7, 38)
    ..close();
  g.area(camera, .07);
  g.outline(camera);
  g.circle(24, 27, 8);
  final aperture = Path()
    ..moveTo(24, 19)
    ..lineTo(28, 26)
    ..lineTo(24, 35)
    ..moveTo(32, 27)
    ..lineTo(24, 27)
    ..lineTo(16, 23)
    ..moveTo(20, 34)
    ..lineTo(20, 25)
    ..lineTo(26, 19);
  g.outline(aperture, secondary: true);
  g.line(11, 20, 15, 20, secondary: true);
}

void _film(CourseIconCanvas g) {
  final board = Path()
    ..moveTo(8, 19)
    ..lineTo(41, 19)
    ..lineTo(41, 37)
    ..quadraticBezierTo(41, 40, 38, 40)
    ..lineTo(11, 40)
    ..quadraticBezierTo(8, 40, 8, 37)
    ..close();
  g.area(board, .06);
  g.outline(board);
  final clap = Path()
    ..moveTo(6, 11)
    ..lineTo(38, 5)
    ..lineTo(40, 12)
    ..lineTo(8, 18)
    ..close();
  g.area(clap, .14);
  g.outline(clap);
  for (final x in [14.0, 23.0, 32.0]) {
    g.line(
      x,
      11 - (x - 6) * 6 / 32,
      x + 4,
      18 - (x - 4) * 6 / 32,
      secondary: true,
    );
  }
  final frame = Path()
    ..moveTo(21, 25)
    ..lineTo(29, 30)
    ..lineTo(21, 35)
    ..close();
  g.area(frame, .17);
  g.outline(frame);
}

void _design(CourseIconCanvas g) {
  final square = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(7, 7, 17, 17),
        const Radius.circular(2),
      ),
    );
  final circle = Path()..addOval(const Rect.fromLTWH(26, 8, 14, 14));
  final triangle = Path()
    ..moveTo(15, 29)
    ..lineTo(24, 41)
    ..lineTo(6, 41)
    ..close();
  g.area(square, .08);
  g.area(circle, .15);
  g.area(triangle, .1);
  g.outline(square);
  g.outline(circle);
  g.outline(triangle);
  g.outline(
    Path()
      ..moveTo(30, 39)
      ..lineTo(40, 29)
      ..lineTo(43, 32)
      ..lineTo(33, 42)
      ..lineTo(29, 43)
      ..close(),
  );
  g.line(31, 37, 35, 41, secondary: true);
}

void _calligraphy(CourseIconCanvas g) {
  final brush = Path()
    ..moveTo(32, 7)
    ..lineTo(40, 15)
    ..lineTo(22, 33)
    ..lineTo(15, 35)
    ..lineTo(17, 28)
    ..close();
  g.area(brush, .12);
  g.outline(brush);
  g.line(29, 11, 36, 18, secondary: true);
  g.outline(
    Path()
      ..moveTo(15, 35)
      ..cubicTo(10, 35, 8, 39, 6, 42)
      ..cubicTo(12, 42, 17, 40, 18, 35),
  );
  final stone = Path()
    ..moveTo(22, 34)
    ..quadraticBezierTo(31, 31, 40, 35)
    ..lineTo(38, 41)
    ..quadraticBezierTo(30, 43, 21, 40)
    ..close();
  g.area(stone, .16);
  g.outline(stone, secondary: true);
  g.outline(
    Path()
      ..moveTo(25, 37)
      ..quadraticBezierTo(31, 35, 36, 38),
    secondary: true,
  );
}

void _basketball(CourseIconCanvas g) {
  final ball = Path()..addOval(const Rect.fromLTWH(7, 7, 34, 34));
  g.area(ball, .08);
  g.outline(ball);
  g.outline(
    Path()
      ..moveTo(11, 13)
      ..cubicTo(19, 18, 29, 28, 37, 35),
  );
  g.outline(
    Path()
      ..moveTo(35, 10)
      ..cubicTo(27, 18, 19, 29, 13, 37),
  );
  g.outline(
    Path()
      ..moveTo(7, 24)
      ..cubicTo(17, 20, 31, 20, 41, 24),
    secondary: true,
  );
  g.outline(
    Path()
      ..moveTo(24, 7)
      ..cubicTo(20, 17, 20, 31, 24, 41),
    secondary: true,
  );
}

void _tennis(CourseIconCanvas g) {
  final racket = Path()
    ..moveTo(26, 7)
    ..cubicTo(37, 5, 42, 14, 38, 24)
    ..cubicTo(34, 34, 24, 37, 18, 30)
    ..cubicTo(12, 23, 15, 10, 26, 7)
    ..close();
  g.area(racket, .08);
  g.outline(racket);
  g.line(19, 30, 8, 41);
  g.line(16, 28, 7, 37, secondary: true);
  for (final x in [20.0, 25.0, 30.0, 35.0]) {
    g.line(x, 10, x - 3, 30, secondary: true);
  }
  g.line(17, 15, 36, 15, secondary: true);
  g.line(16, 22, 38, 22, secondary: true);
  g.line(17, 29, 34, 29, secondary: true);
  g.circle(40, 38, 3);
}

void _running(CourseIconCanvas g) {
  g.dot(30, 9, 3.2);
  g.outline(
    Path()
      ..moveTo(25, 16)
      ..lineTo(19, 25)
      ..lineTo(28, 29)
      ..lineTo(35, 39),
  );
  g.outline(
    Path()
      ..moveTo(24, 17)
      ..lineTo(32, 22)
      ..lineTo(39, 19),
  );
  g.outline(
    Path()
      ..moveTo(19, 25)
      ..lineTo(13, 34)
      ..lineTo(6, 39),
  );
  g.outline(
    Path()
      ..moveTo(25, 16)
      ..lineTo(20, 14)
      ..lineTo(14, 20),
  );
  g.line(6, 17, 17, 17, secondary: true);
  g.line(9, 23, 15, 23, secondary: true);
}

void _mountain(CourseIconCanvas g) {
  final range = Path()
    ..moveTo(5, 40)
    ..lineTo(18, 19)
    ..lineTo(24, 27)
    ..lineTo(31, 10)
    ..lineTo(43, 40)
    ..close();
  g.area(range, .08);
  g.outline(range);
  final snow = Path()
    ..moveTo(25, 25)
    ..lineTo(31, 10)
    ..lineTo(37, 25)
    ..lineTo(33, 22)
    ..lineTo(30, 26)
    ..close();
  g.area(snow, .16);
  g.outline(snow, secondary: true);
  g.outline(
    Path()
      ..moveTo(10, 40)
      ..cubicTo(17, 35, 23, 38, 27, 31)
      ..quadraticBezierTo(30, 27, 34, 30),
    secondary: true,
  );
  g.dot(27, 31, 1.4);
}

void _compass(CourseIconCanvas g) {
  final dial = Path()..addOval(const Rect.fromLTWH(7, 7, 34, 34));
  g.area(dial, .06);
  g.outline(dial);
  final needle = Path()
    ..moveTo(29, 14)
    ..lineTo(26, 26)
    ..lineTo(15, 34)
    ..lineTo(22, 21)
    ..close();
  g.area(needle, .17);
  g.outline(needle);
  g.circle(24, 24, 2, secondary: true);
  g.line(24, 7, 24, 11, secondary: true);
  g.line(24, 37, 24, 41, secondary: true);
  g.line(7, 24, 11, 24, secondary: true);
  g.line(37, 24, 41, 24, secondary: true);
}
