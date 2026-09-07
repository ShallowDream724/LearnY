import 'package:flutter/material.dart';

import '../../../core/design/app_theme_colors.dart';
import '../../../core/schedule/schedule_models.dart';

String scheduleFailureLabel(ScheduleFailure failure) => switch (failure) {
  ScheduleFailure.timeout => '课表连接超时，请重试',
  ScheduleFailure.sessionExpired => '网络学堂登录已失效，请重新登录',
  ScheduleFailure.storage => '课表缓存读取失败',
  ScheduleFailure.network => '课表连接失败，请重试',
  ScheduleFailure.registrarAuthorization => '教务授权未完成，请重试',
  ScheduleFailure.campusAccess => '课表需要校园网或 WebVPN 授权',
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (snapshot.hasLegacyItems)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            '历史课表缓存，调课信息尚未核验。',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: context.colors.tertiary,
            ),
          ),
        ),
      if (snapshot.hasEstimatedItems)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Text(
            snapshot.itemsByDateKey.values
                    .expand((items) => items)
                    .any((item) => item.source == ScheduleItemSource.registrar)
                ? '部分课程按排课推算，未包含节假日调课。'
                : '按课程排课推算，未包含节假日调课。',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: context.colors.tertiary,
            ),
          ),
        ),
      if (snapshot.unscheduledCourses.isNotEmpty)
        TextButton.icon(
          icon: const Icon(Icons.event_note_outlined, size: 16),
          label: Text('${snapshot.unscheduledCourses.length} 门课程有待安排的上课时间'),
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
