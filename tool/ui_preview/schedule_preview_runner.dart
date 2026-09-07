import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learn_y/app/app.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/connectivity_provider.dart';
import 'package:learn_y/demo/demo_environment.dart';

import '../../test/features/home/schedule_navigation_test.dart'
    show ScheduleFixture, scheduleToday;

// Explicit, account-free visual review. Not part of default test discovery.
void main() {
  if (Platform.environment['LEARNY_CAPTURE_UI'] != '1') return;
  final fontPath = Platform.environment['LEARNY_PREVIEW_FONT'];
  if (fontPath == null) {
    throw StateError('Set LEARNY_PREVIEW_FONT to a local CJK font file.');
  }

  late DemoEnvironment demo;
  setUpAll(() async {
    final bytes = await File(fontPath).readAsBytes();
    for (final name in ['Roboto', 'Segoe UI', 'Preview']) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    demo = await DemoEnvironment.create(now: scheduleToday);
  });
  tearDownAll(() => demo.dispose());

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: 1);
      final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/ui_preview/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  testWidgets('render sparse dense and empty schedules with actual fonts', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final width in [360.0, 600.0, 1280.0]) {
      tester.view.physicalSize = Size(width, 720);
      for (final sample in {
        'dense': [6, 2, 4, 1, 3, 0, 0],
        'sparse': [1, 0, 1, 0, 0, 0, 0],
        'empty': [0, 0, 0, 0, 0, 0, 0],
      }.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light.copyWith(
                textTheme: AppTheme.light.textTheme.apply(
                  fontFamily: 'Preview',
                ),
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: ScheduleFixture(counts: sample.value),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'schedule_${width.toInt()}_${sample.key}');
      }
    }
  });

  testWidgets('render the actual home and shell with isolated demo data', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: ProviderScope(
          overrides: [
            ...demo.overrides,
            connectivityProvider.overrideWith((ref) => _Connected()),
            minuteTickProvider.overrideWith(
              (ref) => Stream.value(scheduleToday),
            ),
            appSessionCoordinatorProvider.overrideWith(
              (ref) => AppSessionCoordinator(
                RiverpodAppSessionCoordinatorDelegate(ref),
                scheduleTask: (_, _) async {},
              ),
            ),
          ],
          child: const LearnYApp(),
        ),
      ),
    );
    for (final size in [const Size(1440, 900), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
      }
      await capture(tester, key, 'home_${size.width.toInt()}');
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

class _Connected extends StateNotifier<ConnectivityState>
    implements ConnectivityNotifier {
  _Connected() : super(const ConnectivityState(status: NetworkStatus.online));
}
