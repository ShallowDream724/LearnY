import 'dart:async';

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
            onSwipe: () async {
              reads++;
            },
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
    expect(find.byType(IconButton), findsOneWidget);
    expect(find.byType(Dismissible), findsNothing);
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
            onSwipe: () async {
              reads++;
            },
            child: const SizedBox(
              height: 60,
              width: double.infinity,
              child: Text('Document'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    await tester.drag(find.byType(SwipeToRead), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(reads, 1);
  });

  testWidgets('mobile read items do not turn unread from a swipe', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android),
        home: Scaffold(
          body: SwipeToRead(
            isRead: true,
            onSwipe: () async {
              calls++;
            },
            child: const SizedBox(
              height: 60,
              width: double.infinity,
              child: Text('Read document'),
            ),
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    await tester.drag(find.text('Read document'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    expect(calls, 0);
  });

  testWidgets(
    'a pending read cannot repeat and failure keeps the item usable',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: Scaffold(
            body: SwipeToRead(
              onSwipe: () {
                calls++;
                return calls == 1 ? pending.future : Future.value();
              },
              child: const Text('Document'),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('标为已读'));
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      expect(calls, 1);
      pending.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      expect(find.text('Document'), findsOneWidget);
      expect(find.text('已读状态未能更新'), findsOneWidget);
      await tester.tap(find.byTooltip('标为已读'));
      expect(calls, 2);
    },
  );
}
