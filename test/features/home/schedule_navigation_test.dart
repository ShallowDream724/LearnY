import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/features/home/widgets/schedule_browser.dart';

final scheduleToday = DateTime(2026, 9, 7);

class ScheduleFixture extends StatefulWidget {
  const ScheduleFixture({
    super.key,
    this.counts = const [1, 1, 1, 1, 1, 0, 0],
    this.onOpen,
    this.onDate,
    this.failure,
    this.scale = 1,
  });
  final List<int> counts;
  final ValueChanged<String>? onOpen;
  final ValueChanged<DateTime>? onDate;
  final ScheduleFailure? failure;
  final double scale;
  @override
  State<ScheduleFixture> createState() => _ScheduleFixtureState();
}

class _ScheduleFixtureState extends State<ScheduleFixture> {
  DateTime selected = scheduleToday;
  @override
  Widget build(BuildContext context) {
    final days = buildHomeScheduleDays(
      scheduleWeekStart(selected),
      today: scheduleToday,
    );
    final snapshot = HomeScheduleSnapshot(
      days: days,
      itemsByDateKey: {
        for (final day in days)
          day.dateKey: [
            for (var i = 0; i < widget.counts[day.date.weekday - 1]; i++)
              TodayScheduleItem(
                courseId: '${day.date.weekday}-$i',
                courseName:
                    '${['计算机系统结构', '概率论与数理统计', '操作系统实验', '算法设计与分析', '线性代数', '体育专项', '课程研讨'][day.date.weekday - 1]} ${i + 1}',
                startTime: '${(8 + i * 2).toString().padLeft(2, '0')}:00',
                endTime: '${(9 + i * 2).toString().padLeft(2, '0')}:35',
                location: '第六教学楼 6A301',
              ),
          ],
      },
    );
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(widget.scale)),
      child: ScheduleBrowser(
        days: days,
        today: scheduleToday,
        selectedDate: selected,
        onDateSelected: (date) {
          setState(() => selected = date);
          widget.onDate?.call(date);
        },
        snapshot: snapshot,
        onOpenCourse: widget.onOpen ?? (_) {},
        onRetry: () {},
        failure: widget.failure,
      ),
    );
  }
}

Future<void> pumpScheduleFixture(
  WidgetTester tester, {
  double width = 1280,
  double scale = 1,
  List<int> counts = const [1, 1, 1, 1, 1, 0, 0],
  ValueChanged<String>? onOpen,
  ValueChanged<DateTime>? onDate,
  ScheduleFailure? failure,
}) async {
  await tester.pumpWidget(const SizedBox());
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        platform: width < 600 ? TargetPlatform.android : TargetPlatform.windows,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ScheduleFixture(
              counts: counts,
              onOpen: onOpen,
              onDate: onDate,
              failure: failure,
              scale: scale,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> clickScheduleMouse(WidgetTester tester, Finder finder) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: tester.getCenter(finder));
  await gesture.down(tester.getCenter(finder));
  await gesture.up();
  await gesture.removePointer();
  await tester.pumpAndSettle();
}

void main() {
  void resetView(WidgetTester tester) {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'sparse desktop week uses a short agenda with direct course access',
    (tester) async {
      resetView(tester);
      final opened = <String>[];
      await pumpScheduleFixture(
        tester,
        counts: const [1, 0, 1, 0, 0, 0, 0],
        onOpen: opened.add,
      );
      expect(find.text('周二 9/8'), findsNothing);
      expect(
        tester.getSize(find.byType(ScheduleBrowser)).height,
        lessThan(200),
      );
      await clickScheduleMouse(tester, find.text('操作系统实验 1'));
      expect(opened, ['3-0']);
    },
  );

  testWidgets(
    'desktop week overview opens courses and navigates beyond the original six days',
    (tester) async {
      resetView(tester);
      final opened = <String>[];
      final selected = <DateTime>[];
      await pumpScheduleFixture(
        tester,
        onOpen: opened.add,
        onDate: selected.add,
      );
      await clickScheduleMouse(tester, find.text('概率论与数理统计 1'));
      expect(opened, ['2-0']);
      await clickScheduleMouse(tester, find.byTooltip('下一周'));
      expect(selected.last, DateTime(2026, 9, 14));
      expect(find.text('9/14 - 9/20'), findsOneWidget);
      await clickScheduleMouse(tester, find.byTooltip('上一周'));
      expect(selected.last, scheduleToday);
      await clickScheduleMouse(tester, find.byTooltip('上一周'));
      expect(selected.last, DateTime(2026, 8, 31));
      await clickScheduleMouse(tester, find.byTooltip('回到今天'));
      expect(selected.last, scheduleToday);
    },
  );

  testWidgets('date picker jumps directly to an arbitrary day', (tester) async {
    resetView(tester);
    final selected = <DateTime>[];
    await pumpScheduleFixture(tester, onDate: selected.add);
    await tester.tap(find.text('9/7 - 9/13'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('21'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(selected.last, DateTime(2026, 9, 21));
  });

  testWidgets('keyboard and touch can cross week boundaries in the day view', (
    tester,
  ) async {
    resetView(tester);
    final selected = <DateTime>[];
    await pumpScheduleFixture(tester, width: 360, onDate: selected.add);
    await tester.fling(find.text('计算机系统结构 1'), const Offset(-200, 0), 600);
    await tester.pumpAndSettle();
    expect(find.text('概率论与数理统计 1'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(selected.last, DateTime(2026, 9, 13));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(selected.last, DateTime(2026, 9, 14));
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(selected.last, scheduleToday);
  });

  testWidgets('dense week stays compact and exposes all six courses in a day', (
    tester,
  ) async {
    resetView(tester);
    await pumpScheduleFixture(tester, counts: const [6, 1, 2, 0, 1, 0, 0]);
    expect(find.text('计算机系统结构 6'), findsNothing);
    expect(tester.getSize(find.byType(ScheduleBrowser)).height, lessThan(350));
    await clickScheduleMouse(tester, find.text('+3 节'));
    expect(find.text('计算机系统结构 6'), findsOneWidget);
    expect(tester.getSize(find.byType(ScheduleBrowser)).height, lessThan(350));
  });

  testWidgets('empty weekends are hidden but can be explicitly restored', (
    tester,
  ) async {
    resetView(tester);
    await pumpScheduleFixture(tester);
    expect(find.text('周六 9/12'), findsNothing);
    await clickScheduleMouse(tester, find.byTooltip('课表显示选项'));
    await tester.tap(find.byType(CheckedPopupMenuItem<bool>));
    await tester.pumpAndSettle();
    expect(find.text('周六 9/12'), findsOneWidget);
    await pumpScheduleFixture(tester, counts: const [1, 0, 0, 0, 0, 1, 0]);
    expect(find.text('周六 9/12'), findsOneWidget);
    expect(find.text('体育专项 1'), findsOneWidget);
  });

  testWidgets(
    'phone shows three classes first and expands the remaining day on demand',
    (tester) async {
      resetView(tester);
      await pumpScheduleFixture(
        tester,
        width: 360,
        counts: const [6, 0, 0, 0, 0, 0, 0],
      );
      expect(find.text('计算机系统结构 6'), findsNothing);
      await tester.tap(find.text('还有 3 节课'));
      await tester.pumpAndSettle();
      expect(find.text('计算机系统结构 6'), findsOneWidget);
      await tester.tap(find.text('周'));
      await tester.pumpAndSettle();
      expect(find.text('6 节'), findsOneWidget);
    },
  );

  testWidgets(
    'empty state uses little space and a settled failure never claims no classes',
    (tester) async {
      resetView(tester);
      await pumpScheduleFixture(tester, counts: const [0, 0, 0, 0, 0, 0, 0]);
      expect(find.text('本周没有课'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ScheduleBrowser)).height,
        lessThan(120),
      );
      await pumpScheduleFixture(
        tester,
        width: 360,
        counts: const [0, 0, 0, 0, 0, 0, 0],
        failure: ScheduleFailure.timeout,
      );
      expect(find.text('今天没有课'), findsNothing);
      expect(find.text('课表更新超时'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets('phone tablet and desktop layouts accommodate large text', (
    tester,
  ) async {
    resetView(tester);
    for (final width in [320.0, 600.0, 1440.0]) {
      for (final scale in [1.0, 2.0]) {
        await pumpScheduleFixture(
          tester,
          width: width,
          scale: scale,
          counts: const [6, 1, 0, 2, 1, 1, 0],
        );
        expect(tester.takeException(), isNull, reason: '$width / $scale');
        await tester.tap(find.text('周'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'week $width / $scale');
      }
    }
  });
}
