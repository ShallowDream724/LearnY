import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/features/profile/widgets/appearance_menu.dart';
import 'package:learn_y/features/profile/widgets/settings_rows.dart';

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    var appearance = 'light';
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, setState) => MaterialApp(
          theme: AppTheme.light.copyWith(platform: TargetPlatform.windows),
          darkTheme: AppTheme.dark.copyWith(platform: TargetPlatform.windows),
          themeMode: appearance == 'dark' ? ThemeMode.dark : ThemeMode.light,
          home: Scaffold(
            body: SettingsRow(
              icon: Icons.palette_outlined,
              title: '外观',
              trailing: AppearanceMenu(
                value: appearance,
                onChanged: (value) => setState(() => appearance = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> mouseClick(WidgetTester tester, Finder finder) async {
    final mouse = await tester.startGesture(
      tester.getCenter(finder),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
  }

  FocusNode opener(WidgetTester tester) => tester
      .widget<TextButton>(find.byKey(const ValueKey('appearance-menu-button')))
      .focusNode!;

  testWidgets('selecting dark with a mouse leaves no persistent opener focus', (
    tester,
  ) async {
    await openSettings(tester);
    await mouseClick(tester, find.byTooltip('选择外观'));
    await mouseClick(tester, find.text('深色'));
    expect(
      tester.widget<AppearanceMenu>(find.byType(AppearanceMenu)).value,
      'dark',
    );
    expect(opener(tester).hasFocus, isFalse);
    expect(
      Theme.of(tester.element(find.byType(AppearanceMenu))).brightness,
      Brightness.dark,
    );
  });

  testWidgets(
    'keyboard reopening after a pointer interaction preserves return focus',
    (tester) async {
      await openSettings(tester);
      await mouseClick(tester, find.byTooltip('选择外观'));
      await mouseClick(tester, find.text('深色'));
      opener(tester).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(MenuItemButton), findsNWidgets(3));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(opener(tester).hasFocus, isTrue);
    },
  );
}
