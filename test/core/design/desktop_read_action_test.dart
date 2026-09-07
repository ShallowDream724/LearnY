import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/swipe_to_read.dart';

void main() {
  testWidgets('desktop read action and content click are independent', (
    tester,
  ) async {
    var reads = 0;
    var opens = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: Scaffold(
          body: SwipeToRead(
            onSwipe: () => reads++,
            child: TextButton(
              onPressed: () => opens++,
              child: const Text('Document'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Document'));
    expect(opens, 1);
    expect(reads, 0);
    await tester.tap(find.byTooltip('标为已读'));
    expect(reads, 1);
    expect(opens, 1);
  });

  testWidgets('Android retains swipe-to-read behavior', (tester) async {
    var reads = 0;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SwipeToRead(
            onSwipe: () => reads++,
            child: const SizedBox(
              height: 60,
              width: double.infinity,
              child: Text('Document'),
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('标为已读'), findsOneWidget);
    await tester.drag(find.byType(SwipeToRead), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(reads, 1);
  });
}
