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
import 'package:learn_y/core/database/database.dart'
    show Semester, CourseDao, HomeworkDao;
import 'package:learn_y/core/router/router.dart';
import 'package:learn_y/features/home/home_screen.dart';

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
    Future<void> settleData() async {
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
      }
    }

    await settleData();
    final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LearnYApp)),
    );
    final courses = (await tester.runAsync(
      () => demo.database.getCoursesBySemester(demo.selectedSemesterId),
    ))!;
    final homeworks = (await tester.runAsync(
      () => demo.database.getHomeworksBySemester(demo.selectedSemesterId),
    ))!;
    final routes = {
      'home': Routes.home,
      'assignments': Routes.assignments,
      'courses': Routes.courses,
      'profile': Routes.profile,
      'unread_files': Routes.unreadFiles,
      'files': Routes.files,
      if (courses.isNotEmpty)
        'course_detail': Routes.courseDetail(courses.first.id),
      if (homeworks.isNotEmpty)
        'homework_detail': Routes.homeworkDetail(
          homeworkId: homeworks.first.id,
          courseId: homeworks.first.courseId,
          courseName: courses
              .where((course) => course.id == homeworks.first.courseId)
              .first
              .name,
        ),
    };
    for (final size in [
      const Size(1440, 900),
      const Size(390, 844),
      const Size(800, 1000),
    ]) {
      tester.view.physicalSize = size;
      for (final entry in routes.entries) {
        if (size.width == 800 && !['home', 'courses'].contains(entry.key)) {
          continue;
        }
        final mainRoute = [
          'home',
          'assignments',
          'courses',
          'profile',
        ].contains(entry.key);
        router.go(mainRoute ? entry.value : Routes.home);
        if (!mainRoute) router.push(entry.value);
        await settleData();
        await capture(tester, key, '${entry.key}_${size.width.toInt()}');
      }
      if (size.width != 800) {
        final pending = homeworks.firstWhere(
          (hw) => !hw.submitted && !hw.graded,
        );
        router.go(Routes.home);
        router.push(
          Routes.homeworkDetail(
            homeworkId: pending.id,
            courseId: pending.courseId,
            courseName: courses
                .firstWhere((c) => c.id == pending.courseId)
                .name,
          ),
        );
        await settleData();
        await tester.tap(find.text('提交作业'));
        await settleData();
        await capture(tester, key, 'submission_${size.width.toInt()}');
        await tester.tap(find.byTooltip('关闭'));
        await settleData();
      }
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final entry in {
      'home': Routes.home,
      'assignments': Routes.assignments,
    }.entries) {
      router.go(entry.value);
      await settleData();
      await capture(tester, key, '${entry.key}_390_large_text');
    }
    tester.platformDispatcher.clearTextScaleFactorTestValue();
    await tester.runAsync(
      () => container.read(themeModeProvider.notifier).setTheme('dark'),
    );
    router.go(Routes.home);
    await settleData();
    await capture(tester, key, 'home_390_dark');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

class _Connected extends StateNotifier<ConnectivityState>
    implements ConnectivityNotifier {
  _Connected() : super(const ConnectivityState(status: NetworkStatus.online));
}
