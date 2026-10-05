import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/shell/app_bottom_navigation.dart';
import 'package:learn_y/core/shell/shell_navigation_progress.dart';

void main() {
  testWidgets(
    'dock previews a drag, commits once on release, and cancels without navigating',
    (tester) async {
      final progress = ShellNavigationProgress(0);
      addTearDown(progress.dispose);
      final selections = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              selectedIndex: 0,
              progress: progress,
              onTap: selections.add,
              destinations: const [
                ShellNavDestinationData(
                  icon: Icons.home,
                  selectedIcon: Icons.home,
                  label: '首页',
                ),
                ShellNavDestinationData(
                  icon: Icons.task,
                  selectedIcon: Icons.task,
                  label: '作业',
                ),
                ShellNavDestinationData(
                  icon: Icons.school,
                  selectedIcon: Icons.school,
                  label: '课程',
                ),
                ShellNavDestinationData(
                  icon: Icons.person,
                  selectedIcon: Icons.person,
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final home = tester.getCenter(find.byIcon(Icons.home).first);
      final courses = tester.getCenter(find.byIcon(Icons.school).first);
      final drag = await tester.startGesture(home);
      await tester.pump(const Duration(milliseconds: 100));
      await drag.moveTo(courses);
      await tester.pump(const Duration(milliseconds: 180));
      expect(selections, isEmpty);
      await drag.up();
      await tester.pumpAndSettle();
      expect(selections, [2]);
      selections.clear();
      final cancelled = await tester.startGesture(courses);
      await tester.pump(const Duration(milliseconds: 60));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(selections, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dock retains accessible controls during a reduced-motion drag', (
    tester,
  ) async {
    final progress = ShellNavigationProgress(0);
    addTearDown(progress.dispose);
    final semantics = tester.ensureSemantics();
    final selections = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            bottomNavigationBar: AppBottomNavigation(
              selectedIndex: 0,
              progress: progress,
              onTap: selections.add,
              destinations: const [
                ShellNavDestinationData(
                  icon: Icons.home,
                  selectedIcon: Icons.home,
                  label: '首页',
                ),
                ShellNavDestinationData(
                  icon: Icons.task,
                  selectedIcon: Icons.task,
                  label: '作业',
                ),
                ShellNavDestinationData(
                  icon: Icons.school,
                  selectedIcon: Icons.school,
                  label: '课程',
                ),
                ShellNavDestinationData(
                  icon: Icons.person,
                  selectedIcon: Icons.person,
                  label: '我的',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final home = find.bySemanticsLabel('首页');
    expect(home, findsOneWidget);
    expect(
      tester.getSemantics(home).flagsCollection.isSelected,
      Tristate.isTrue,
    );
    expect(tester.getSemantics(home).flagsCollection.isButton, isTrue);

    final first = await tester.startGesture(tester.getCenter(home), pointer: 1);
    final second = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('我的')),
      pointer: 2,
    );
    await second.up();
    await tester.pump();
    expect(selections, isEmpty);
    await first.cancel();
    await tester.pumpAndSettle();
    expect(selections, isEmpty);
    expect(
      tester.getSemantics(home).flagsCollection.isSelected,
      Tristate.isTrue,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(
      tester
          .widgetList<Container>(find.byType(Container))
          .where(
            (container) =>
                (container.decoration as BoxDecoration?)?.border != null,
          ),
      hasLength(1),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(selections, [1]);

    progress.select(3);
    progress.select(1);
    progress.follow(.5);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
