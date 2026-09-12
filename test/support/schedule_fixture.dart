import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/core/semester/semester_repository.dart';
import 'package:learn_y/core/database/database.dart' show Semester;
import 'package:learn_y/features/home/providers/home_schedule_provider.dart';
import 'package:learn_y/features/home/widgets/schedule_browser.dart';
import 'package:learn_y/features/home/widgets/schedule_dialog.dart';

final scheduleToday = DateTime(2026, 9, 7);
const scheduleCourses = [
  '计算机系统结构',
  '概率论与数理统计',
  '操作系统实验',
  '算法设计与分析',
  '线性代数',
  '大学物理',
  '课程研讨',
];
const scheduleStarts = [
  '08:00',
  '09:50',
  '13:30',
  '15:20',
  '17:05',
  '19:20',
  '21:00',
];
const scheduleEnds = [
  '09:35',
  '11:25',
  '15:05',
  '16:55',
  '18:40',
  '20:55',
  '21:45',
];

HomeScheduleSnapshot scheduleFixtureSnapshot(
  DateTime week,
  List<int> counts, {
  bool estimated = false,
}) {
  final days = buildHomeScheduleDays(week, today: scheduleToday);
  return HomeScheduleSnapshot(
    days: days,
    hasRoutineData: estimated,
    unscheduledCourses: estimated
        ? const [
            UnscheduledCourse(
              courseId: 'lab',
              courseName: '基础物理实验',
              details: ['第1-16周星期 第0节，各实验单元实验室'],
            ),
          ]
        : const [],
    itemsByDateKey: {
      for (final day in days)
        day.dateKey: [
          for (var i = 0; i < counts[day.date.weekday - 1]; i++)
            TodayScheduleItem(
              courseId: '${day.date.weekday}-$i',
              courseName:
                  scheduleCourses[(i + day.date.weekday - 1) %
                      scheduleCourses.length],
              startTime: scheduleStarts[i % scheduleStarts.length],
              endTime: estimated && day.date.weekday == 2 && i == 1
                  ? '12:15'
                  : scheduleEnds[i % scheduleEnds.length],
              location: '六教 6A${301 + i}',
              source: estimated && !(day.date.weekday == 2 && i == 1)
                  ? ScheduleItemSource.routine
                  : ScheduleItemSource.registrar,
              endTimeInferred: estimated && !(day.date.weekday == 2 && i == 1),
            ),
        ],
    },
  );
}

class ScheduleFixture extends StatefulWidget {
  const ScheduleFixture({
    super.key,
    this.counts = const [1, 1, 1, 1, 1, 0, 0],
    this.onOpen,
    this.onDate,
    this.failure,
    this.scale = 1,
    this.estimated = false,
    this.semesters = const [],
  });
  final List<int> counts;
  final ValueChanged<String>? onOpen;
  final ValueChanged<DateTime>? onDate;
  final ScheduleFailure? failure;
  final double scale;
  final bool estimated;
  final List<Semester> semesters;
  @override
  State<ScheduleFixture> createState() => _ScheduleFixtureState();
}

class _ScheduleFixtureState extends State<ScheduleFixture> {
  DateTime selected = scheduleToday;
  @override
  Widget build(BuildContext context) {
    final snapshot = scheduleFixtureSnapshot(
      scheduleWeekStart(selected),
      widget.counts,
      estimated: widget.estimated,
    );
    return ProviderScope(
      overrides: [
        semesterCatalogProvider.overrideWith(
          (ref) => Stream.value(widget.semesters),
        ),
        homeScheduleTodayProvider.overrideWithValue(scheduleToday),
        scheduleWeekProvider.overrideWith(
          (ref, week) => Stream.value(
            ScheduleState(
              snapshot: scheduleFixtureSnapshot(
                week,
                widget.counts,
                estimated: widget.estimated,
              ),
              hasCalendarData: true,
              failure: widget.failure,
            ),
          ),
        ),
      ],
      child: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(widget.scale)),
        child: Builder(
          builder: (context) => ScheduleBrowser(
            days: snapshot.days,
            today: scheduleToday,
            selectedDate: selected,
            onDateSelected: (date) {
              setState(() => selected = date);
              widget.onDate?.call(date);
            },
            snapshot: snapshot,
            onOpenCourse: widget.onOpen ?? (_) {},
            failure: widget.failure,
            onOpenWeek: () => showScheduleDialog(
              context,
              initialDate: selected,
              onOpenCourse: widget.onOpen ?? (_) {},
            ),
          ),
        ),
      ),
    );
  }
}
