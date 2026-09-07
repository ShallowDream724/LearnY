import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/schedule/schedule_models.dart';
import 'package:learn_y/core/schedule/schedule_projection.dart';
import 'package:learn_y/features/home/widgets/home_schedule_section.dart';

void main() {
  final days = buildHomeScheduleDays(DateTime(2026, 9, 7));
  final snapshot = HomeScheduleSnapshot(
    days: days,
    itemsByDateKey: {
      for (var i = 0; i < days.length; i++)
        days[i].dateKey: [
          TodayScheduleItem(
            courseId: 'course-$i',
            courseName: 'Course $i',
            startTime: '08:00',
            endTime: '09:35',
            location: 'Room 101',
          ),
        ],
    },
  );

  Future<void> pumpBrowser(
    WidgetTester tester, {
    double width = 1000,
    double scale = 1,
    TargetPlatform platform = TargetPlatform.windows,
    ValueChanged<String>? open,
    HomeScheduleSnapshot? data,
    ScheduleFailure? failure,
    bool refreshing = false,
  }) async {
    await tester.pumpWidget(const SizedBox());
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: platform),
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 900),
              textScaler: TextScaler.linear(scale),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ScheduleBrowser(
                  days: days,
                  snapshot: data ?? snapshot,
                  onOpenCourse: open ?? (_) {},
                  onRetry: () {},
                  failure: failure,
                  isRefreshing: refreshing,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> clickMouse(WidgetTester tester, Finder finder) async {
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: tester.getCenter(finder));
    await gesture.down(tester.getCenter(finder));
    await gesture.up();
    await gesture.removePointer();
    await tester.pumpAndSettle();
  }

  testWidgets(
    'mouse can select dates, use arrows, and open the selected course',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final opened = <String>[];
      await pumpBrowser(tester, open: opened.add);
      await clickMouse(tester, find.text('明天'));
      expect(find.text('Course 1').hitTestable(), findsOneWidget);
      await clickMouse(tester, find.byTooltip('后一天'));
      expect(find.text('Course 2').hitTestable(), findsOneWidget);
      await clickMouse(tester, find.text('Course 2'));
      expect(opened, ['course-2']);
      await clickMouse(tester, find.byTooltip('前一天'));
      expect(find.text('Course 1').hitTestable(), findsOneWidget);
    },
  );

  testWidgets(
    'focused date navigation supports arrows, Home and End without wrapping',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpBrowser(tester);
      await clickMouse(tester, find.text('明天'));
      await tester.sendKeyEvent(LogicalKeyboardKey.end);
      await tester.pumpAndSettle();
      expect(find.text('Course 5').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('Course 5').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pumpAndSettle();
      expect(find.text('Course 0').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('phone touch swipe and visible date tabs stay synchronized', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpBrowser(tester, width: 360, platform: TargetPlatform.android);
    await tester.drag(find.byType(TabBarView), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('Course 1').hitTestable(), findsOneWidget);
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(find.text('Course 0').hitTestable(), findsOneWidget);
  });

  testWidgets(
    'date navigation and long course names fit responsive widths and text scaling',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final longData = HomeScheduleSnapshot(
        days: days,
        itemsByDateKey: {
          days.first.dateKey: const [
            TodayScheduleItem(
              courseName: '计算机系统结构与高性能并行程序设计课程实验',
              startTime: '13:30',
              endTime: '15:05',
              location: '第六教学楼长名称实验教室 6A301',
            ),
          ],
        },
      );
      for (final width in [320.0, 600.0, 1440.0]) {
        for (final scale in [1.0, 2.0]) {
          await pumpBrowser(tester, width: width, scale: scale, data: longData);
          expect(tester.takeException(), isNull, reason: '$width / $scale');
          await clickMouse(tester, find.byTooltip('后一天'));
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'failed empty schedule is not presented as a day without classes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await pumpBrowser(
        tester,
        data: emptyScheduleSnapshot(days),
        failure: ScheduleFailure.timeout,
      );
      expect(find.text('今天没有课'), findsNothing);
      expect(find.text('课表更新超时，请重试'), findsOneWidget);
    },
  );
}
