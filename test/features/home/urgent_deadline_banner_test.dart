import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/sync_models.dart';
import 'package:learn_y/features/home/widgets/urgent_deadline_banner.dart';

void main() {
  testWidgets('compact empty assignments retain validated reminder settings', (
    tester,
  ) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: UrgentDeadlineBanner(assignments: [], pendingAssignments: 0),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byType(UrgentDeadlineBanner)).height,
      lessThan(64),
    );
    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('请输入大于 0 的小时数'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '48');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(container.read(deadlineThresholdHoursProvider), 48);
    expect(
      await tester.runAsync(
        () => db.getState(AppStateKeys.deadlineThresholdHours),
      ),
      '48',
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'desktop right-click opens assignment actions without navigating',
    (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      var opens = 0;
      var menus = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            home: Scaffold(
              body: UrgentDeadlineBanner(
                assignments: const [
                  HomeworkSummary(
                    id: 'hw',
                    courseId: 'course',
                    courseName: '算法设计',
                    title: '第一章习题',
                    deadline: '4102416000000',
                    timeRemaining: Duration(hours: 20),
                    isOverdue: false,
                  ),
                ],
                pendingAssignments: 1,
                onTap: (_) => opens++,
                onLongPress: (_, _) async {
                  menus++;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.down(tester.getCenter(find.text('第一章习题')));
      await gesture.up();
      await gesture.removePointer();
      await tester.pumpAndSettle();
      expect(menus, 1);
      expect(opens, 0);
      await tester.tap(find.text('第一章习题'));
      expect(opens, 1);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
