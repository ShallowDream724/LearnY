import 'dart:async';
import 'dart:io';
import 'package:learn_y/core/database/database.dart'
    show CourseDao, AppStateDao;
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/features/courses/providers/course_workbench_models.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:learn_y/core/design/app_font.dart';
import 'package:learn_y/core/design/app_light_scene.dart';
import 'package:learn_y/core/design/wallpaper.dart';
import 'package:learn_y/core/providers/wallpaper_provider.dart';
import 'package:learn_y/core/database/app_state_keys.dart';
import 'package:learn_y/core/design/theme.dart';
import 'package:learn_y/core/design/typography.dart';
import 'package:learn_y/core/router/router.dart';
import 'package:learn_y/core/providers/connectivity_provider.dart';
import 'package:learn_y/core/shell/app_shell.dart';
import 'package:learn_y/demo/demo_environment.dart';
import 'package:learn_y/features/courses/courses_screen.dart';
import 'package:learn_y/features/profile/profile_screen.dart';
import 'package:learn_y/features/courses/providers/course_workbench_repository.dart';
import 'package:learn_y/core/design/course_icons/course_icon.dart';
import 'package:learn_y/core/design/course_icons/course_icon_catalog.dart';

typedef SampleCourse = ({String name, String teacher, int unread, int pending});
late List<ResolvedCourseCardModel> previewCards;
const samples = <SampleCourse>[
  (name: '工业系统概论', teacher: '汤彬', unread: 0, pending: 0),
  (name: '有限元分析基础', teacher: '危银涛', unread: 1, pending: 0),
  (name: '生物化学基础实验', teacher: '韩再铭', unread: 0, pending: 0),
  (name: '计算流体力学基础', teacher: '任玉新', unread: 2, pending: 0),
  (name: '工程项目管理(1)', teacher: '李小冬', unread: 1, pending: 0),
  (name: '计算机组成原理', teacher: '杨铮', unread: 2, pending: 3),
  (name: '分子生物学基础实验', teacher: '陈金春', unread: 0, pending: 0),
  (name: '医学细胞生物学实验', teacher: '潘登', unread: 2, pending: 0),
  (name: '法律与神话传说', teacher: '李平', unread: 0, pending: 0),
  (name: '三年级男生游泳提高班', teacher: '陈祚', unread: 0, pending: 0),
  (name: '西方音乐剧史', teacher: '罗薇', unread: 1, pending: 0),
  (name: '土力学', teacher: '王睿', unread: 0, pending: 0),
  (name: '分子生物学', teacher: '李春', unread: 0, pending: 0),
  (name: '临床早接触与医学人文（2）', teacher: '王炜', unread: 0, pending: 0),
];

void main() {
  const sceneStudy = bool.fromEnvironment('LEARNY_PREVIEW_SCENE_ONLY');
  testWidgets('render course surfaces, picker and complete icon collection', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2534, 1369);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final originalShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = originalShadows);
    await (FontLoader(
      AppFont.family,
    )..addFont(rootBundle.load(AppFont.asset))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    final demo = await tester.runAsync(
      () => DemoEnvironment.create(
        now: DateTime(2026, 9, 8),
        selectPreviousSemester: true,
      ),
    );
    final bases = (await tester.runAsync(
      () => demo!.database.getCoursesBySemester(demo.selectedSemesterId),
    ))!;
    const tones = [
      StudyTone.ink,
      StudyTone.slate,
      StudyTone.ochre,
      StudyTone.plum,
      StudyTone.ochre,
      StudyTone.rose,
      StudyTone.slate,
      StudyTone.jade,
      StudyTone.plum,
      StudyTone.rose,
      StudyTone.jade,
      StudyTone.ochre,
      StudyTone.rose,
      StudyTone.slate,
    ];
    const files = [7, 20, 70, 8, 18, 17, 30, 24, 1, 0, 13, 22, 16, 0];
    previewCards = List.generate(samples.length, (index) {
      var suffix = 0;
      var id = 'glass-$index-$suffix';
      while (StudyPalette.fallbackCourse(id) != tones[index]) {
        suffix++;
        id = 'glass-$index-$suffix';
      }
      final sample = samples[index];
      return ResolvedCourseCardModel(
        course: bases[index % bases.length].copyWith(
          id: id,
          name: sample.name,
          teacherName: sample.teacher,
        ),
        unreadNotifications: sample.unread,
        pendingHomeworks: sample.pending,
        totalFiles: files[index],
        defaultSortOrder: index,
      );
    });
    final router = GoRouter(
      initialLocation: Routes.courses,
      routes: [
        StatefulShellRoute(
          builder: (_, _, shell) => AppShell(navigationShell: shell),
          navigatorContainerBuilder: buildAppShellBranchContainer,
          branches: [
            for (final route in [
              Routes.home,
              Routes.assignments,
              Routes.courses,
              Routes.profile,
            ])
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: route,
                    builder: (_, _) => route == Routes.courses
                        ? const CoursesScreen()
                        : route == Routes.profile
                        ? const ProfileScreen()
                        : const SizedBox(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    final key = GlobalKey();
    Widget app(ThemeData theme) => RepaintBoundary(
      key: key,
      child: ProviderScope(
        overrides: [
          ...demo!.overrides,
          mobileWallpapersProvider.overrideWithValue(
            theme.platform == TargetPlatform.android ||
                theme.platform == TargetPlatform.iOS,
          ),
          resolvedCourseCardsProvider.overrideWithValue(
            AsyncData(previewCards),
          ),
          connectivityProvider.overrideWith((ref) => _Connected()),
        ],
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpWidget(
      app(AppTheme.light.copyWith(platform: TargetPlatform.windows)),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
    }
    expect(tester.takeException(), isNull);
    Future<void> settleStorage() async {
      // SQLite completes outside the widget test's fake clock. Pump its queued
      // callbacks before awaiting another write in runAsync.
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
    }

    Future<void> pumpAsyncWork(Future<void> Function() action) async {
      var done = false;
      Object? failure;
      StackTrace? failureStack;
      await tester.runAsync(() async {
        unawaited(
          action().then<void>(
            (_) {
              done = true;
            },
            onError: (Object error, StackTrace stack) {
              failure = error;
              failureStack = stack;
              done = true;
            },
          ),
        );
      });
      // Database invalidation and image decoding also schedule frame work.
      // Let real I/O and the widget test's clock both advance.
      for (var i = 0; i < 100 && !done; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
      expect(
        done,
        isTrue,
        reason: 'Async work should finish while frames advance',
      );
    }

    Future<void> capture(String name, double ratio) async {
      final sceneContext = find.byType(AppShell);
      if (sceneContext.evaluate().isNotEmpty) {
        final context = tester.element(sceneContext);
        final wallpaper = ProviderScope.containerOf(
          context,
        ).read(wallpaperProvider);
        await pumpAsyncWork(() async {
          await precacheImage(
            AssetImage(
              StudyLightBackdrop.assetFor(
                Theme.of(context).brightness,
                wallpaper: wallpaper,
                forMobile: ProviderScope.containerOf(
                  context,
                ).read(mobileWallpapersProvider),
              ),
            ),
            context,
          );
          await Future.wait([
            for (final widget in tester.widgetList<Image>(find.byType(Image)))
              precacheImage(widget.image, context),
          ]);
        });
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: ratio);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = sceneStudy
            ? 'build/ui_preview/light_scene'
            : 'build/ui_preview';
        final file = File('$directory/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
      });
    }

    await capture('courses_windows_final', 2);
    Future<void> selectPage(String label) => tester.tap(
      find.byType(NavigationBar).evaluate().isNotEmpty
          ? find.byTooltip(label)
          : find.text(label),
    );
    Future<void> openWallpaperPicker() async {
      await selectPage('我的');
      await settleStorage();
      await tester.ensureVisible(find.text('背景'));
      await tester.tap(find.text('背景'));
      await tester.pumpAndSettle();
    }

    Future<void> returnToCourses() async {
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      await selectPage('课程');
      await tester.pumpAndSettle();
    }

    if (sceneStudy) {
      await openWallpaperPicker();
      await capture('wallpaper_picker_windows', 2);
      await tester.tap(find.text('澄光'));
      await settleStorage();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      expect(container.read(wallpaperProvider), StudyWallpaper.prism);
      await pumpAsyncWork(() async {
        final preference = container.read(wallpaperProvider.notifier);
        await Future.wait([
          preference.select(StudyWallpaper.alpine),
          preference.select(StudyWallpaper.glow),
          preference.select(StudyWallpaper.dunes),
        ]);
        expect(await demo!.database.getState(AppStateKeys.wallpaper), 'dunes');
        final intensity = container.read(wallpaperIntensitiesProvider.notifier);
        intensity.preview(StudyWallpaper.dunes, 20);
        await intensity.save(StudyWallpaper.dunes);
        intensity.preview(StudyWallpaper.prism, 45);
        await intensity.save(StudyWallpaper.prism);
        expect(
          await demo.database.getState(
            AppStateKeys.wallpaperIntensity('dunes'),
          ),
          '20',
        );
        expect(
          await demo.database.getState(
            AppStateKeys.wallpaperIntensity('prism'),
          ),
          '45',
        );
      });
      await returnToCourses();
    }
    if (!sceneStudy) {
      await tester.tap(find.byTooltip('编辑课程'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('更换图标').first);
      await tester.pumpAndSettle();
      await capture('course_icon_picker_windows', 2);
      await tester.tap(find.byTooltip('关闭'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(
      app(AppTheme.dark.copyWith(platform: TargetPlatform.windows)),
    );
    await tester.pumpAndSettle();
    await capture('courses_windows_dark_final', 2);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1080, 2340);
    await tester.pumpWidget(
      app(AppTheme.light.copyWith(platform: TargetPlatform.android)),
    );
    await tester.pumpAndSettle();
    await capture('courses_android_final', 3);
    if (sceneStudy) {
      final container = ProviderScope.containerOf(
        tester.element(find.byType(AppShell)),
      );
      // A saved desktop-only choice migrates to the phone's own default.
      expect(container.read(wallpaperProvider), StudyWallpaper.prism);
      await openWallpaperPicker();
      await capture('wallpaper_picker_android', 3);
      expect(find.text('晴岚'), findsNothing);
      expect(find.text('微光'), findsNothing);
      for (final wallpaper in StudyWallpaper.mobileChoices) {
        await tester.tap(find.text(wallpaper.label));
        await settleStorage();
        expect(container.read(wallpaperProvider), wallpaper);
        await tester.runAsync(
          () => precacheImage(
            AssetImage(wallpaper.assetFor(Brightness.dark, forMobile: true)),
            tester.element(find.byType(AppShell)),
          ),
        );
      }
      final sliderRect = tester.getRect(find.byType(Slider));
      await tester.tapAt(
        Offset(sliderRect.left + sliderRect.width * .68, sliderRect.center.dy),
      );
      await tester.pumpAndSettle();
      final coveIntensity = container.read(wallpaperIntensityProvider);
      expect(coveIntensity, greaterThan(50));
      await tester.tap(find.text('暖丘'));
      await tester.pumpAndSettle();
      expect(container.read(wallpaperIntensityProvider), 30);
      await tester.tap(find.text('碧潭'));
      await tester.pumpAndSettle();
      expect(container.read(wallpaperIntensityProvider), coveIntensity);
      await settleStorage();
      await pumpAsyncWork(() async {
        expect(await demo!.database.getState(AppStateKeys.wallpaper), 'cove');
        expect(
          await demo.database.getState(AppStateKeys.wallpaperIntensity('cove')),
          '$coveIntensity',
        );
      });
      await returnToCourses();
      await capture('courses_android_cove', 3);
      await tester.pumpWidget(
        app(AppTheme.dark.copyWith(platform: TargetPlatform.android)),
      );
      await tester.pumpAndSettle();
      await capture('courses_android_dark', 3);
      await tester.pumpWidget(
        app(AppTheme.light.copyWith(platform: TargetPlatform.android)),
      );
      await tester.pumpAndSettle();
    }
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    await capture('courses_android_scrolled', 3);
    if (sceneStudy) {
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await pumpAsyncWork(demo!.dispose);
      debugDisableShadows = originalShadows;
      return;
    }
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, 1500),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('编辑课程'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('更换图标').first);
    await tester.pumpAndSettle();
    await capture('course_icon_picker_android', 3);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    tester.view.devicePixelRatio = 2;
    tester.view.physicalSize = const Size(2400, 2400);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          home: Scaffold(
            backgroundColor: const Color(0xFFFAFBFD),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text('课程图标', style: AppTypography.headlineMedium),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 10,
                            mainAxisExtent: 110,
                          ),
                      itemCount: courseIconOptions.length,
                      itemBuilder: (context, index) {
                        final option = courseIconOptions[index];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CourseIcon(
                              option: option,
                              size: 48,
                              color: StudyPalette.of(
                                context,
                                StudyTone.values[index % 6],
                              ).accent,
                            ),
                            const SizedBox(height: 7),
                            Text(option.label, style: AppTypography.bodySmall),
                            Text(
                              option.key,
                              style: AppTypography.bodySmall.copyWith(
                                fontSize: 8,
                                color: const Color(0xFF8891A2),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await capture('course_icons_100', 2);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    await pumpAsyncWork(demo!.dispose);
    debugDisableShadows = originalShadows;
  });
}

class _Connected extends StateNotifier<ConnectivityState>
    implements ConnectivityNotifier {
  _Connected() : super(const ConnectivityState(status: NetworkStatus.online));
}
