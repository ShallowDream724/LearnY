import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learn_y/app/app.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/connectivity_provider.dart';
import 'package:learn_y/core/router/router.dart';
import 'package:learn_y/core/shell/app_bottom_navigation.dart';
import 'package:learn_y/demo/demo_environment.dart';
import 'package:learn_y/features/home/home_screen.dart';

void main() {
  testWidgets(
    'real shell preserves browsing and coordinates scroll, dock, keyboard and details',
    (tester) async {
      final demo = await tester.runAsync(() => DemoEnvironment.create());
      addTearDown(() => demo!.dispose());
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...demo!.overrides,
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
      final router = GoRouter.of(tester.element(find.byType(HomeScreen)));
      final dock = find.byType(AppBottomNavigation);
      final progress = tester.widget<AppBottomNavigation>(dock).progress;
      Finder destination(String name) =>
          find.descendant(of: dock, matching: find.byTooltip(name));
      final homeList = find.byKey(const PageStorageKey('home_scroll_view'));
      final homeController = tester
          .widget<CustomScrollView>(homeList)
          .controller!;
      await tester.drag(homeList, const Offset(0, -350));
      await settle();
      final savedOffset = homeController.offset;
      expect(savedOffset, greaterThan(0));
      expect(progress.value, 0);
      expect(dock, findsOneWidget);

      // Dock scrubbing previews selection without changing the page until release.
      final gesture = await tester.startGesture(
        tester.getCenter(destination('首页')),
      );
      await gesture.moveTo(tester.getCenter(destination('课程')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(router.routeInformationProvider.value.uri.path, Routes.home);
      await gesture.up();
      await settle();
      expect(router.routeInformationProvider.value.uri.path, Routes.courses);
      await tester.tap(destination('首页'));
      await settle();
      expect(homeController.offset, closeTo(savedOffset, .1));

      // A vertical move starting over the dock cannot accidentally select a tab,
      // even if the pointer returns inside its bounds before release.
      final start = tester.getCenter(destination('课程'));
      final vertical = await tester.startGesture(start);
      await vertical.moveBy(const Offset(0, -40));
      await vertical.moveTo(start);
      await vertical.up();
      await settle();
      expect(router.routeInformationProvider.value.uri.path, Routes.home);

      // Interrupt a partially dragged page by choosing the current destination.
      homeController.jumpTo(0);
      await settle();
      final page = await tester.startGesture(const Offset(345, 98), pointer: 4);
      await page.moveBy(const Offset(-30, 0));
      await tester.pump();
      await page.moveBy(const Offset(-100, 0));
      await tester.pump(const Duration(milliseconds: 30));
      expect(progress.value, greaterThan(0));
      expect(progress.value, lessThan(.5));
      await tester.tap(destination('首页'), pointer: 5);
      await page.cancel();
      await settle();
      expect(progress.value, 0);
      expect(router.routeInformationProvider.value.uri.path, Routes.home);

      await tester.drag(homeList, const Offset(0, -350));
      await settle();
      final beforeDetail = homeController.offset;
      final assignments = (await tester.runAsync(
        () => demo.database.getHomeworksBySemester(demo.selectedSemesterId),
      ))!;
      final homework = assignments.first;
      router.push(
        Routes.homeworkDetail(
          homeworkId: homework.id,
          courseId: homework.courseId,
          courseName: '课程',
        ),
      );
      await settle();
      expect(dock, findsNothing);
      router.pop();
      await settle();
      expect(homeController.offset, closeTo(beforeDetail, .1));

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await settle();
      expect(dock, findsNothing);
      tester.view.resetViewInsets();
      await settle();
      expect(dock, findsOneWidget);
      expect(progress.value, 0);
      expect(homeController.offset, closeTo(beforeDetail, .1));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}

class _Connected extends StateNotifier<ConnectivityState>
    implements ConnectivityNotifier {
  _Connected() : super(const ConnectivityState(status: NetworkStatus.online));
}
