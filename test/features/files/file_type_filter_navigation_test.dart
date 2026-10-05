import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/features/files/widgets/file_type_filter_button.dart';

void main() {
  testWidgets(
    'system back immediately closes the menu and preserves its page',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
          home: const Scaffold(body: Text('首页')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('未读文件')),
            body: FileTypeFilterButton(
              currentFilter: null,
              typeCounts: const {'pdf': 2, 'docx': 1},
              onChanged: (value) => selected = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pump();
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      await tester.binding.handlePopRoute();
      await tester
          .pump(); // No page reverse-transition wait to remove the overlay.
      expect(find.byType(MenuItemButton), findsNothing);
      expect(find.text('未读文件'), findsOneWidget);
      expect(selected, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('首页'), findsOneWidget);
    },
  );

  testWidgets('selection and Escape share the same menu close lifecycle', (
    tester,
  ) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: FileTypeFilterButton(
            currentFilter: null,
            typeCounts: const {'pdf': 2},
            onChanged: (value) => selected = value,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.tap(find.text('PDF (2)'));
    await tester.pump();
    expect(selected, 'pdf');
    expect(find.byType(MenuItemButton), findsNothing);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(MenuItemButton), findsNothing);
    expect(selected, 'pdf');
  });
}
