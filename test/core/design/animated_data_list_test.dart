import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/design/animated_data_list.dart';

typedef _Item = ({int id, String label});

void main() {
  testWidgets('rapid removals and undo retain exits until the empty state', (
    tester,
  ) async {
    final items = ValueNotifier<List<_Item>>([
      (id: 1, label: 'One'),
      (id: 2, label: 'Two'),
      (id: 3, label: 'Three'),
    ]);
    addTearDown(items.dispose);
    final swipeResult = Completer<bool>();
    var taps = 0;
    await tester.pumpWidget(
      _host(
        items,
        row: (item) => Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => swipeResult.future,
          child: GestureDetector(
            onTap: () => taps++,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(height: 64, child: Text(item.label)),
            ),
          ),
        ),
      ),
    );
    final initialState = tester.state(find.byKey(const ValueKey(1)));
    final initialThirdTop = tester.getTopLeft(find.text('Three')).dy;
    await tester.drag(find.text('One'), const Offset(-500, 0));
    await tester.pump(const Duration(milliseconds: 200));

    items.value = [items.value[1], items.value[2]];
    await tester.pump();
    expect(tester.state(find.byKey(const ValueKey(1))), same(initialState));
    final outgoing = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byKey(const ValueKey(1)),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(outgoing.ignoring, isTrue);
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.getTopLeft(find.text('Three')).dy, lessThan(initialThirdTop));
    expect(tester.getTopLeft(find.text('Three')).dy, greaterThan(80));

    items.value = [items.value[1]];
    await tester.pump();
    items.value = [
      (id: 1, label: 'One restored'),
      (id: 3, label: 'Three updated'),
    ];
    await tester.pump();
    expect(find.text('One'), findsOneWidget);
    expect(find.text('One restored'), findsOneWidget);
    expect(find.text('Three updated'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsNothing);

    final thirdState = tester.state(find.byKey(const ValueKey(3)));
    items.value = [items.value.first];
    await tester.pump();
    items.value = [(id: 4, label: 'Four'), ...items.value];
    await tester.pump();
    expect(tester.state(find.byKey(const ValueKey(3))), same(thirdState));

    items.value = [];
    await tester.pump();
    expect(find.text('Empty'), findsNothing);
    await tester.pump(const Duration(milliseconds: 110));
    expect(find.text('Empty'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('Empty'), findsOneWidget);
    expect(taps, 0);
    swipeResult.complete(false);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('first data, content updates, reorder and reduced motion agree', (
    tester,
  ) async {
    final items = ValueNotifier<List<_Item>>([]);
    addTearDown(items.dispose);
    await tester.pumpWidget(_host(items));
    items.value = [
      (id: 1, label: 'One'),
      (id: 2, label: 'Two'),
      (id: 3, label: 'Three'),
    ];
    await tester.pump();
    expect(tester.getTopLeft(find.text('Three')).dy, 160);
    items.value = [
      (id: 3, label: 'Three updated'),
      (id: 1, label: 'One updated'),
      (id: 4, label: 'Four'),
    ];
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    items.value = [
      (id: 4, label: 'Four updated'),
      (id: 3, label: 'Three newest'),
    ];
    await tester.pumpAndSettle();
    expect(find.text('One'), findsNothing);
    expect(find.text('Two'), findsNothing);
    expect(find.text('Three updated'), findsNothing);
    expect(tester.getTopLeft(find.text('Four updated')).dy, 0);
    expect(tester.getTopLeft(find.text('Three newest')).dy, 80);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_host(items, disableAnimations: true));
    items.value = [];
    await tester.pump();
    await tester.pump();
    expect(find.text('Empty'), findsOneWidget);
    expect(find.text('Four updated'), findsNothing);
    expect(find.text('Three newest'), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

Widget _host(
  ValueNotifier<List<_Item>> items, {
  Widget Function(_Item)? row,
  bool disableAnimations = false,
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 600,
          child: ValueListenableBuilder<List<_Item>>(
            valueListenable: items,
            builder: (context, value, _) => AnimatedDataList<_Item>(
              items: value,
              itemId: (item) => item.id,
              shrinkWrap: true,
              itemBuilder: (context, item) =>
                  row?.call(item) ??
                  SizedBox(height: 80, child: Text(item.label)),
              emptyBuilder: (_) => const Text('Empty'),
            ),
          ),
        ),
      ),
    ),
  ),
);
