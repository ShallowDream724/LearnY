import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/features/home/widgets/schedule_browser.dart';
import 'package:learn_y/features/home/widgets/schedule_dialog.dart';
import 'package:learn_y/features/home/widgets/weekly_timetable.dart';

import '../../support/schedule_fixture.dart';

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
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
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
    'home remains daily on phone and desktop and opens a course directly',
    (tester) async {
      resetView(tester);
      for (final width in [360.0, 1280.0]) {
        final opened = <String>[];
        await pumpScheduleFixture(
          tester,
          width: width,
          counts: const [6, 6, 6, 6, 6, 0, 0],
          onOpen: opened.add,
        );
        expect(find.byType(WeeklyTimetable), findsNothing);
        expect(find.text('大学物理'), findsOneWidget);
        expect(
          tester.getSize(find.byType(ScheduleBrowser)).height,
          lessThan(tester.view.physicalSize.height * .45),
          reason: 'A full day leaves most of the viewport for coursework.',
        );
        await clickScheduleMouse(tester, find.text('计算机系统结构'));
        expect(opened, ['1-0']);
      }
    },
  );

  testWidgets(
    'daily touch paging and mouse buttons cross the Sunday boundary',
    (tester) async {
      resetView(tester);
      final dates = <DateTime>[];
      await pumpScheduleFixture(tester, width: 360, onDate: dates.add);
      for (var i = 0; i < 6; i++) {
        await clickScheduleMouse(tester, find.byTooltip('后一天'));
      }
      expect(dates.last, DateTime(2026, 9, 13));
      await tester.fling(find.byType(PageView), const Offset(-240, 0), 900);
      await tester.pumpAndSettle();
      expect(dates.last, DateTime(2026, 9, 14));
      await tester.tap(find.byTooltip('回到今天'));
      await tester.pumpAndSettle();
      expect(dates.last, scheduleToday);
    },
  );

  testWidgets(
    'weekly overlay swipes independently and dismisses with backdrop or Escape',
    (tester) async {
      resetView(tester);
      final dates = <DateTime>[];
      await pumpScheduleFixture(tester, width: 390, onDate: dates.add);
      await tester.tap(find.byTooltip('查看整周课表'));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleDialog), findsOneWidget);
      await tester.fling(
        find.descendant(
          of: find.byType(ScheduleDialog),
          matching: find.byType(PageView),
        ),
        const Offset(-280, 0),
        900,
      );
      await tester.pumpAndSettle();
      expect(find.text('2026年 9/14 - 9/20'), findsOneWidget);
      expect(dates, isEmpty);
      await tester.tapAt(const Offset(2, 450));
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleDialog), findsNothing);
      await tester.tap(find.byTooltip('查看整周课表'));
      await tester.pumpAndSettle();
      expect(find.text('2026年 9/7 - 9/13'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(ScheduleDialog), findsNothing);
    },
  );

  testWidgets(
    'full week retains 35 classes and reveals complete course details',
    (tester) async {
      resetView(tester);
      final opened = <String>[];
      await pumpScheduleFixture(
        tester,
        counts: const [7, 7, 7, 7, 7, 0, 0],
        onOpen: opened.add,
      );
      await tester.tap(find.byTooltip('查看整周课表'));
      await tester.pumpAndSettle();
      final table = find.byType(WeeklyTimetable);
      final events = find.descendant(of: table, matching: find.byType(Tooltip));
      expect(events, findsNWidgets(35));
      expect(find.text('周六'), findsNothing);
      await clickScheduleMouse(tester, events.first);
      expect(find.text('08:00-09:35\n六教 6A301'), findsOneWidget);
      await tester.tap(find.text('进入课程'));
      await tester.pumpAndSettle();
      expect(opened, ['1-0']);
      expect(find.byType(ScheduleDialog), findsNothing);
    },
  );

  testWidgets(
    'weekends with classes remain visible and empty weekends can be restored',
    (tester) async {
      resetView(tester);
      await pumpScheduleFixture(tester, counts: const [1, 0, 0, 0, 0, 1, 0]);
      await tester.tap(find.byTooltip('查看整周课表'));
      await tester.pumpAndSettle();
      expect(find.text('周六'), findsOneWidget);
      expect(find.text('周日'), findsNothing);
      await tester.tap(find.byTooltip('课表显示选项'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckedPopupMenuItem<String>));
      await tester.pumpAndSettle();
      expect(find.text('周日'), findsOneWidget);
    },
  );

  testWidgets(
    'date picker and keyboard move weeks and today restores the current week',
    (tester) async {
      resetView(tester);
      await pumpScheduleFixture(tester);
      await tester.tap(find.byTooltip('查看整周课表'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('2026年 9/14 - 9/20'), findsOneWidget);
      await tester.tap(find.text('2026年 9/14 - 9/20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('21'));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('2026年 9/21 - 9/27'), findsOneWidget);
      await tester.tap(find.byTooltip('回到今天'));
      await tester.pumpAndSettle();
      expect(find.text('2026年 9/7 - 9/13'), findsOneWidget);
    },
  );

  testWidgets('settled errors never claim no classes or keep spinning', (
    tester,
  ) async {
    resetView(tester);
    await pumpScheduleFixture(
      tester,
      width: 360,
      counts: const [0, 0, 0, 0, 0, 0, 0],
      failure: ScheduleFailure.campusAccess,
    );
    expect(find.text('今天没有课'), findsNothing);
    expect(find.text('校园连接暂未恢复，请稍后重试'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.byTooltip('查看整周课表'));
    await tester.pumpAndSettle();
    expect(find.text('本周没有课'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'dense weekly layouts fit phone tablet and desktop with large text',
    (tester) async {
      resetView(tester);
      for (final width in [320.0, 600.0, 1440.0]) {
        for (final scale in [1.0, 2.0]) {
          await pumpScheduleFixture(
            tester,
            width: width,
            scale: scale,
            counts: const [6, 6, 6, 6, 6, 1, 1],
          );
          expect(
            tester.takeException(),
            isNull,
            reason: 'daily $width / $scale',
          );
          await tester.tap(find.byTooltip('查看整周课表'));
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'week $width / $scale',
          );
        }
      }
    },
  );
}
