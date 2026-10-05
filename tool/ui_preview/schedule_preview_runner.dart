import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learn_y/app/app.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/design/app_light_scene.dart';
import 'package:learn_y/core/design/app_font.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/connectivity_provider.dart';
import 'package:learn_y/demo/demo_environment.dart';
import 'package:learn_y/core/database/database.dart'
    show Semester, CourseDao, HomeworkDao, AppStateDao;
import 'package:learn_y/core/router/router.dart';
import 'package:learn_y/features/home/home_screen.dart';
import 'package:learn_y/features/home/widgets/pending_assignments.dart';
import 'package:learn_y/features/home/widgets/weekly_timetable.dart';
import 'package:learn_y/core/shell/app_bottom_navigation.dart';
import 'package:learn_y/features/assignments/assignment_submission_screen.dart';
import 'package:learn_y/features/assignments/widgets/homework_detail_sections.dart';
import 'package:learn_y/features/assignments/submission/homework_submission_models.dart';
import 'package:learn_y/features/assignments/submission/homework_submission_controller.dart';

import '../../test/support/schedule_fixture.dart';

// Explicit, account-free visual review. Not part of default test discovery.
void main() {
  if (Platform.environment['LEARNY_CAPTURE_UI'] != '1') return;
  final fontPath = Platform.environment['LEARNY_PREVIEW_FONT'];
  final captureRoutes = Platform.environment['LEARNY_PREVIEW_ROUTES']
      ?.split(',')
      .toSet();
  final captureRatio =
      double.tryParse(
        Platform.environment['LEARNY_PREVIEW_PIXEL_RATIO'] ?? '',
      ) ??
      1;

  late DemoEnvironment demo;
  setUpAll(() async {
    final bytes = fontPath == null
        ? (await rootBundle.load(AppFont.asset)).buffer.asUint8List()
        : await File(fontPath).readAsBytes();
    for (final name in [
      'Roboto',
      'Segoe UI',
      'Microsoft YaHei UI',
      'Microsoft YaHei',
      'Preview',
    ]) {
      await (FontLoader(
        name,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader(
      AppFont.family,
    )..addFont(rootBundle.load(AppFont.asset))).load();
    demo = await DemoEnvironment.create(now: scheduleToday);
    final wallpaper = Platform.environment['LEARNY_PREVIEW_WALLPAPER'];
    if (wallpaper != null) {
      await demo.database.setState(AppStateKeys.wallpaper, wallpaper);
      final intensity = Platform.environment['LEARNY_PREVIEW_INTENSITY'];
      if (intensity != null) {
        await demo.database.setState(
          AppStateKeys.wallpaperIntensity(wallpaper),
          intensity,
        );
      }
    }
  });
  tearDownAll(() => demo.dispose());

  Future<void> withShadows(Future<void> Function() render) async {
    final original = debugDisableShadows;
    final originalPlatform = debugDefaultTargetPlatformOverride;
    debugDefaultTargetPlatformOverride =
        switch (Platform.environment['LEARNY_PREVIEW_PLATFORM']) {
          'windows' => TargetPlatform.windows,
          'android' => TargetPlatform.android,
          _ => originalPlatform,
        };
    debugDisableShadows = false;
    try {
      await render();
    } finally {
      debugDisableShadows = original;
      debugDefaultTargetPlatformOverride = originalPlatform;
    }
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final rendered = await boundary.toImage(pixelRatio: captureRatio);
      final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/ui_preview/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
      rendered.dispose();
    });
  }

  Widget previewApp(GlobalKey key) => RepaintBoundary(
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
  );

  testWidgets(
    'review submission workflow proportions',
    (tester) => withShadows(() async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final key = GlobalKey();
      await tester.pumpWidget(previewApp(key));
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
        }
        expect(tester.takeException(), isNull);
      }

      await settle();
      final context = tester.element(find.byType(HomeScreen));
      final navigator = Navigator.of(context, rootNavigator: true);
      final container = ProviderScope.containerOf(context);
      final homeworks = (await tester.runAsync(
        () => demo.database.getHomeworksBySemester(demo.selectedSemesterId),
      ))!;
      final sample = homeworks.first.copyWith(
        title: 'Ch16',
        submitted: false,
        graded: false,
        deadline: DateTime.now()
            .add(const Duration(days: 7))
            .millisecondsSinceEpoch
            .toString(),
        description: const Value(''),
        submittedContent: const Value(
          '<!-- <div>school editor</div> --><p><br></p>',
        ),
        submittedAttachmentJson: const Value(null),
        attachmentJson: const Value(
          '{"id":"preview-brief","name":"Ch16.docx","size":11950,"downloadUrl":"https://example.invalid/brief"}',
        ),
      );
      for (final sampleCase in [
        ('sparse_desktop', const Size(1267, 684), 1.0, false),
        ('sparse_phone', const Size(390, 844), 1.0, false),
        ('dense_desktop', const Size(1267, 684), 1.0, true),
        ('large_text', const Size(950, 650), 1.5, true),
      ]) {
        tester.view.physicalSize = sampleCase.$2;
        tester.platformDispatcher.textScaleFactorTestValue = sampleCase.$3;
        final homework = sampleCase.$4
            ? sample.copyWith(
                description: Value(
                  List.filled(
                    14,
                    '<p>请阅读教材第十六章，逐题说明推导过程，并将最终结果整理为文档。引用资料时标注来源。</p>',
                  ).join(),
                ),
              )
            : sample;
        navigator.push(
          MaterialPageRoute<void>(
            builder: (_) => AssignmentSubmissionScreen(
              homework: homework,
              courseName: '生物化学(2)(英文)',
            ),
          ),
        );
        await settle();
        expect(find.text('-->'), findsNothing);
        await capture(tester, key, 'workflow/${sampleCase.$1}');
        if (sampleCase.$1 == 'sparse_phone') {
          await tester.enterText(find.byType(TextField), '已完成习题，详细推导见附件。');
          container
              .read(
                homeworkSubmissionControllerProvider(
                  HomeworkSubmissionSeed.fromHomework(homework),
                ).notifier,
              )
              .selectAttachment(
                const HomeworkSubmissionAttachment(
                  path: 'preview-only.docx',
                  name: 'Ch16-习题解答.docx',
                  sizeBytes: 26112,
                ),
              );
          tester.view.viewInsets = const FakeViewPadding(bottom: 280);
          await settle();
          await tester.ensureVisible(find.text('提交前请核对内容与附件'));
          await settle();
          await capture(tester, key, 'workflow/phone_keyboard_review');
          tester.view.resetViewInsets();
          await tester.tap(find.byTooltip('关闭'));
          await settle();
          expect(find.text('放弃本次修改？'), findsOneWidget);
          await tester.tap(find.text('继续编辑'));
          await settle();
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            '已完成习题，详细推导见附件。',
          );
          await tester.tap(find.byTooltip('关闭'));
          await settle();
          await tester.tap(find.text('放弃修改'));
        } else {
          await tester.tap(find.byTooltip('关闭'));
        }
        await settle();
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }),
  );

  testWidgets(
    'render phone timetable vertical scrolling',
    (tester) => withShadows(() async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light.copyWith(platform: TargetPlatform.android),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ScheduleFixture(
                    snapshotBuilder: (week) => scheduleFixtureSnapshot(week, [
                      6,
                      6,
                      6,
                      6,
                      6,
                      0,
                      0,
                    ], secondPeriodEnd: '12:15'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('查看整周课表'));
      await tester.pumpAndSettle();
      final table = find.byType(WeeklyTimetable);
      expect(find.text('午休'), findsOneWidget);
      final scrollable = find.descendant(
        of: table,
        matching: find.byType(Scrollable),
      );
      final position = tester.state<ScrollableState>(scrollable).position;
      final evening = find
          .descendant(
            of: table,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Tooltip &&
                  (widget.message?.contains('19:20-20:55') ?? false),
            ),
          )
          .first;
      expect(position.maxScrollExtent, greaterThan(0));
      expect(position.pixels, 0);
      expect(
        tester.getRect(evening).bottom,
        greaterThan(tester.getRect(scrollable).bottom),
      );
      final week = find.text('2026年 9/7 - 9/13');
      final headerPosition = tester.getTopLeft(week);
      await capture(tester, key, 'weekly_lunch/phone_morning');
      // Use a real vertical drag through the nested week pager, not jumpTo.
      await tester.drag(scrollable, const Offset(0, -550));
      await tester.pumpAndSettle();
      expect(position.pixels, closeTo(position.maxScrollExtent, .1));
      expect(
        tester.getRect(evening).bottom,
        lessThanOrEqualTo(tester.getRect(scrollable).bottom),
      );
      expect(tester.getTopLeft(week), headerPosition);
      await capture(tester, key, 'weekly_lunch/phone_evening');
      await tester.tap(evening);
      await tester.pumpAndSettle();
      expect(find.text('19:20-20:55\n六教 6A306'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }),
  );

  testWidgets(
    'render release 014 headers and extreme timetable',
    (tester) => withShadows(() async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      await tester.runAsync(
        () =>
            demo.database.setState(AppStateKeys.deadlineThresholdHours, '8000'),
      );
      for (final width in [360.0, 1280.0]) {
        tester.view.physicalSize = Size(width, 1080);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light.copyWith(
                platform: width < 600
                    ? TargetPlatform.android
                    : TargetPlatform.windows,
              ),
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        ScheduleFixture(
                          initialDate: DateTime(2025, 12, 12),
                          snapshotBuilder: extremeScheduleSnapshot,
                        ),
                        const SizedBox(height: 16),
                        ProviderScope(
                          overrides: [
                            databaseProvider.overrideWithValue(demo.database),
                          ],
                          child: const PendingAssignments(
                            assignments: [],
                            pendingAssignments: 0,
                          ),
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
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pumpAndSettle();
        await capture(tester, key, 'release014/headers_${width.toInt()}');
        await tester.tap(find.byTooltip('查看整周课表'));
        await tester.pumpAndSettle();
        await capture(tester, key, 'release014/extreme_week_${width.toInt()}');
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
    }),
  );

  testWidgets(
    'render floating navigation motion',
    (tester) => withShadows(() async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final key = GlobalKey();
      await tester.pumpWidget(previewApp(key));
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
        }
      }

      await settle();
      final context = tester.element(find.byType(HomeScreen));
      final router = GoRouter.of(context);
      final container = ProviderScope.containerOf(context);
      router.go(Routes.courses);
      await settle();
      await capture(tester, key, 'liquid_navigation/courses_light');
      final progress = tester
          .widget<AppBottomNavigation>(find.byType(AppBottomNavigation))
          .progress;
      var frame = 0;
      Future<void> captureMotion() => capture(
        tester,
        key,
        'liquid_navigation/frames/${(frame++).toString().padLeft(3, '0')}',
      );
      await captureMotion();
      final drag = await tester.startGesture(const Offset(330, 500));
      for (var i = 0; i < 7; i++) {
        await drag.moveBy(const Offset(-25, 0));
        await tester.pump(const Duration(milliseconds: 40));
        await captureMotion();
      }
      expect(progress.value, greaterThan(2.25));
      expect(progress.value, lessThan(3));
      for (var i = 0; i < 7; i++) {
        await drag.moveBy(const Offset(25, 0));
        await tester.pump(const Duration(milliseconds: 40));
        await captureMotion();
      }
      await drag.up();
      await tester.pumpAndSettle();
      expect(progress.value, closeTo(2, .01));
      await captureMotion();
      await tester.tap(find.byTooltip('首页'));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 35));
        await captureMotion();
      }
      expect(progress.value, 0);
      expect(tester.takeException(), isNull);
      await settle();
      await capture(tester, key, 'liquid_navigation/home_light');
      router.go(Routes.profile);
      await settle();
      await capture(tester, key, 'liquid_navigation/profile_light');
      router.go(Routes.courses);
      await settle();
      await tester.runAsync(
        () => container.read(themeModeProvider.notifier).setTheme('dark'),
      );
      await settle();
      await capture(tester, key, 'liquid_navigation/courses_dark');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }),
  );

  testWidgets(
    'render sparse dense and empty schedules with actual fonts',
    (tester) => withShadows(() async {
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
    }),
  );

  testWidgets(
    'render reading material while scrolling at phone pixel density',
    (tester) => withShadows(() async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(1170, 2532);
      final key = GlobalKey();
      await tester.pumpWidget(previewApp(key));
      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
        }
      }

      await settle();
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      for (final route in {
        'home': Routes.home,
        'profile': Routes.profile,
      }.entries) {
        router.go(route.value);
        await settle();
        final scroll = find.byType(CustomScrollView).hitTestable().first;
        final texture = StudyLightBackdrop.sceneOf(
          tester.element(scroll),
        )!.readingBlur;
        expect(texture, isNotNull);
        await capture(tester, key, 'reading_scroll/${route.key}/000');
        final gesture = await tester.startGesture(tester.getCenter(scroll));
        for (var frame = 1; frame <= 24; frame++) {
          await gesture.moveBy(const Offset(0, -20));
          await tester.pump(const Duration(milliseconds: 40));
          await capture(
            tester,
            key,
            'reading_scroll/${route.key}/${frame.toString().padLeft(3, '0')}',
          );
          expect(
            identical(
              StudyLightBackdrop.sceneOf(tester.element(scroll))!.readingBlur,
              texture,
            ),
            isTrue,
            reason:
                'Scrolling reuses the Gaussian texture rather than re-rendering it',
          );
        }
        await gesture.up();
        for (var frame = 25; frame <= 30; frame++) {
          await tester.pump(const Duration(milliseconds: 40));
          await capture(
            tester,
            key,
            'reading_scroll/${route.key}/${frame.toString().padLeft(3, '0')}',
          );
        }
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }),
  );

  testWidgets(
    'render the actual home and shell with isolated demo data',
    (tester) => withShadows(() async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await tester.pumpWidget(previewApp(key));
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
          if (captureRoutes != null && !captureRoutes.contains(entry.key)) {
            continue;
          }
          if (size.width == 800 &&
              !['home', 'courses', 'profile'].contains(entry.key)) {
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
          if (entry.key == 'homework_detail') {
            final texts = find.descendant(
              of: find.byType(HomeworkStatusHeader),
              matching: find.byType(Text),
            );
            expect(
              tester.getTopLeft(texts.first).dx,
              closeTo(tester.getTopLeft(texts.last).dx, .01),
              reason:
                  'Status tag ink and homework title share the reading edge',
            );
          }
          if (entry.key == 'profile' && size.width == 1440) {
            await tester.tap(find.byTooltip('选择外观'));
            await tester.pumpAndSettle();
            await capture(tester, key, 'profile_menu_1440');
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
            await tester.pumpAndSettle();
          }
          if (entry.key == 'courses') {
            await tester.tap(find.byTooltip('编辑课程'));
            await settleData();
            await capture(tester, key, 'course_editor_${size.width.toInt()}');
            if (size.width == 1440) {
              await tester.tap(find.byTooltip('编辑课程').first);
              await tester.pumpAndSettle();
              await capture(tester, key, 'course_menu_1440');
              await tester.sendKeyEvent(LogicalKeyboardKey.escape);
              await tester.pumpAndSettle();
            }
            await tester.tap(find.text('取消'));
            await settleData();
          }
        }
        if (size.width != 800 &&
            (captureRoutes == null || captureRoutes.contains('submission'))) {
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
        'courses': Routes.courses,
        'profile': Routes.profile,
      }.entries) {
        if (captureRoutes != null && !captureRoutes.contains(entry.key)) {
          continue;
        }
        router.go(entry.value);
        await settleData();
        await capture(tester, key, '${entry.key}_390_large_text');
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await tester.runAsync(
        () => container.read(themeModeProvider.notifier).setTheme('dark'),
      );
      for (final entry in {
        'home': Routes.home,
        'courses': Routes.courses,
        'assignments': Routes.assignments,
        'profile': Routes.profile,
      }.entries) {
        if (captureRoutes != null && !captureRoutes.contains(entry.key)) {
          continue;
        }
        router.go(entry.value);
        for (final size in [const Size(390, 844), const Size(1440, 900)]) {
          tester.view.physicalSize = size;
          await settleData();
          await capture(tester, key, '${entry.key}_${size.width.toInt()}_dark');
        }
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    }),
  );
}

class _Connected extends StateNotifier<ConnectivityState>
    implements ConnectivityNotifier {
  _Connected() : super(const ConnectivityState(status: NetworkStatus.online));
}
