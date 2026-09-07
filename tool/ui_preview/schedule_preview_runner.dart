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
import 'package:learn_y/core/database/database.dart' show Semester;

import '../../test/support/schedule_fixture.dart';

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
        'dense30': [6, 6, 6, 6, 6, 0, 0],
        'dense35': [7, 7, 7, 7, 7, 0, 0],
        'weekends': [6, 6, 6, 6, 6, 1, 1],
        'sparse': [1, 0, 1, 0, 0, 0, 0],
        'empty': [0, 0, 0, 0, 0, 0, 0],
        'estimated': [2, 2, 1, 0, 0, 0, 0],
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
                    child: ScheduleFixture(
                      counts: sample.value,
                      estimated: sample.key == 'estimated',
                      semesters: const [
                        Semester(
                          id: '2025-2026-3',
                          startDate: '2026-06-29',
                          endDate: '2026-09-13',
                          startYear: 2025,
                          endYear: 2026,
                          type: 'summer',
                        ),
                        Semester(
                          id: '2026-2027-1',
                          startDate: '2026-09-14',
                          endDate: '2027-01-17',
                          startYear: 2026,
                          endYear: 2027,
                          type: 'fall',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'schedule_${width.toInt()}_${sample.key}');
        await tester.tap(find.byTooltip('查看整周课表'));
        await tester.pumpAndSettle();
        await capture(tester, key, 'week_${width.toInt()}_${sample.key}');
        if (sample.key == 'estimated') {
          await tester.tap(find.byTooltip('下一周'));
          await tester.pumpAndSettle();
          await capture(tester, key, 'boundary_${width.toInt()}');
        }
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
