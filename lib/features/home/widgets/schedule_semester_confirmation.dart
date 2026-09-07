import 'package:flutter/material.dart';

import '../../../core/semester/semester_models.dart';

Future<bool> confirmScheduleSemesterChange(
  BuildContext context, {
  required String semesterId,
  required bool home,
  int? direction,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(home ? '切换首页学期？' : '切换课表学期？'),
        content: Text(
          [
            if (direction != null)
              home
                  ? (direction > 0 ? '已到本学期最后一天。' : '已到本学期第一天。')
                  : (direction > 0 ? '已到本学期最后一周。' : '已到本学期第一周。'),
            '${semesterLabel(semesterId)}${home ? '，课程、作业等内容将一同切换。' : '，仅切换课表的浏览学期。'}',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('留在当前学期'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('切换学期'),
          ),
        ],
      ),
    ) ??
    false;
