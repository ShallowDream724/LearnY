import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/schedule/schedule_models.dart';

String scheduleFailureLabel(ScheduleFailure failure) => switch (failure) {
  ScheduleFailure.timeout => '课表连接超时，请重试',
  ScheduleFailure.sessionExpired => '网络学堂登录已失效，请重新登录',
  ScheduleFailure.storage => '课表缓存读取失败',
  ScheduleFailure.network => '课表连接失败，请重试',
  ScheduleFailure.registrarAuthorization => '暂时无法连接教务课表，请稍后重试',
  ScheduleFailure.campusAccess => '校园连接暂未恢复，请稍后重试',
  ScheduleFailure.identityVerification => '校园登录需要验证，请重新登录',
  ScheduleFailure.registrarUnavailable => '教务系统暂不可用，请稍后重试',
  ScheduleFailure.invalidCalendar => '教务暂未返回有效课表',
};

class ScheduleNotes extends StatelessWidget {
  const ScheduleNotes({
    super.key,
    required this.snapshot,
    required this.onOpenCourse,
  });
  final HomeScheduleSnapshot snapshot;
  final ValueChanged<String> onOpenCourse;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (snapshot.hasLegacyItems)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Text(
            '历史缓存 · 调课信息尚未核验',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: context.colors.tertiary,
            ),
          ),
        ),
      if (snapshot.hasEstimatedItems)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
          child: Text(
            snapshot.itemsByDateKey.values
                    .expand((items) => items)
                    .any((item) => item.source == ScheduleItemSource.registrar)
                ? '部分课程按排课推算 · 未含节假日调课'
                : '按排课推算 · 未含节假日调课',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: context.colors.tertiary,
            ),
          ),
        ),
      if (snapshot.unscheduledCourses.isNotEmpty)
        TextButton(
          child: Text('${snapshot.unscheduledCourses.length} 门课程时间待安排'),
          onPressed: () async {
            final courseId = await showDialog<String>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('待安排的课程'),
                content: SizedBox(
                  width: 440,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final course in snapshot.unscheduledCourses)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(course.courseName),
                            subtitle: Text(course.details.join('\n')),
                            trailing: const Icon(Icons.chevron_right, size: 18),
                            onTap: () =>
                                Navigator.pop(context, course.courseId),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('关闭'),
                  ),
                ],
              ),
            );
            if (courseId != null && context.mounted) onOpenCourse(courseId);
          },
        ),
    ],
  );
}

Future<bool> showScheduleItemDetails(
  BuildContext context,
  TodayScheduleItem item,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.courseName),
        content: Text(
          [
            item.timeLabel,
            if (item.periodLabel.isNotEmpty) item.periodLabel,
            item.location.isEmpty ? '地点待定' : item.location,
            if (item.endTimeInferred) '下课时间以课程实际安排为准',
          ].join('\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
          if (item.courseId?.isNotEmpty ?? false)
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('进入课程'),
            ),
        ],
      ),
    ) ??
    false;
