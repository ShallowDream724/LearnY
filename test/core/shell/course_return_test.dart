import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/app/app.dart';
import 'package:learn_y/core/database/database.dart' as db;
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/providers/connectivity_provider.dart';
import 'package:learn_y/core/router/router.dart';
import 'package:learn_y/core/shell/app_bottom_navigation.dart';
import 'package:learn_y/demo/demo_environment.dart';
import 'package:learn_y/features/courses/course_detail_screen.dart';
import 'package:learn_y/features/assignments/homework_detail_screen.dart';
import 'package:learn_y/features/assignments/widgets/assignment_list_item.dart';
import 'package:learn_y/core/design/app_materials.dart';
import 'package:learn_y/features/files/file_detail_screen.dart';
import 'package:learn_y/features/files/widgets/file_card.dart';
import 'package:learn_y/features/notifications/notification_detail_screen.dart';
import 'package:learn_y/features/home/home_screen.dart';

void main() {
  for (final target in [
    (
      tab: 0,
      label: '通知',
      list: 'notifications',
      prefix: '通知 ',
      detail: NotificationDetailScreen,
    ),
    (
      tab: 1,
      label: '文件',
      list: 'files',
      prefix: '资料 ',
      detail: FileDetailScreen,
    ),
    (
      tab: 2,
      label: '作业',
      list: 'homeworks',
      prefix: '作业 ',
      detail: HomeworkDetailScreen,
    ),
  ]) {
    testWidgets(
      'predictive back restores course ${target.list} and clears the dock',
      (tester) async {
        final demo = (await tester.runAsync(() => DemoEnvironment.create()))!;
        addTearDown(demo.dispose);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.reset);
        final course = (await tester.runAsync(
          () => demo.database.getCoursesBySemester(demo.selectedSemesterId),
        ))!.first;
        await tester.runAsync(() async {
          final file = (await demo.database.getFilesByCourse(course.id)).first;
          final notification = (await demo.database.getNotificationsByCourse(
            course.id,
          )).first;
          final homework = (await demo.database.getHomeworksByCourse(
            course.id,
          )).first;
          for (var i = 0; i < 20; i++) {
            await demo.database.upsertFile(
              file
                  .copyWith(id: '${file.id}-$i', title: '资料 $i.txt')
                  .toCompanion(false),
            );
            await demo.database.upsertNotification(
              notification
                  .copyWith(id: '${notification.id}-$i', title: '通知 $i')
                  .toCompanion(false),
            );
            await demo.database.upsertHomework(
              homework
                  .copyWith(
                    id: '${homework.id}-$i',
                    title: '作业 $i',
                    attachmentJson: Value(
                      jsonEncode({
                        'id': file.fileId,
                        'name': '作业附件.txt',
                        'downloadUrl': file.downloadUrl,
                        'size': '1 KB',
                      }),
                    ),
                  )
                  .toCompanion(false),
            );
          }
        });
        await tester.pumpWidget(
          ProviderScope(
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
        router.go(Routes.courseDetail(course.id));
        await settle();
        final courseState = tester.state(find.byType(CourseDetailScreen));
        await tester.tap(find.widgetWithText(Tab, target.label));
        await settle();
        final fileList = find.byKey(
          PageStorageKey('course-${target.list}-${course.id}'),
        );
        await tester.drag(fileList, const Offset(0, -450));
        await settle();
        final scrollable = find
            .descendant(of: fileList, matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        final savedOffset = position.pixels;
        expect(savedOffset, greaterThan(0));
        final visibleFile = find
            .textContaining(target.prefix)
            .hitTestable()
            .first;
        await tester.tap(visibleFile);
        await settle();
        expect(find.byType(target.detail), findsOneWidget);
        expect(find.byType(AppBottomNavigation), findsNothing);
        await _backGesture(tester, cancel: true);
        await settle();
        expect(find.byType(target.detail), findsOneWidget);
        if (target.tab == 2) {
          final homeworkRoute = router.routeInformationProvider.value.uri;
          await tester.ensureVisible(find.text('作业附件.txt'));
          await tester.tap(find.text('作业附件.txt'));
          await settle();
          expect(find.byType(FileDetailScreen), findsOneWidget);
          await _backGesture(tester);
          await settle();
          expect(find.byType(HomeworkDetailScreen), findsOneWidget);
          expect(router.routeInformationProvider.value.uri, homeworkRoute);
        }
        await _backGesture(tester);
        await settle();
        expect(
          router.routeInformationProvider.value.uri.path,
          Routes.courseDetail(course.id),
        );
        expect(
          tester.state(find.byType(CourseDetailScreen)),
          same(courseState),
        );
        expect(
          tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
          target.tab,
        );
        expect(
          tester.state<ScrollableState>(scrollable).position.pixels,
          closeTo(savedOffset, .1),
        );

        // A retained course in another branch must not handle a root back gesture.
        if (target.tab == 1) {
          final dock = find.byType(AppBottomNavigation);
          await tester.tap(
            find.descendant(of: dock, matching: find.byTooltip('首页')),
          );
          await settle();
          router.push(
            Routes.notificationDetail(
              notificationId: '${course.id}-notice',
              courseId: course.id,
              courseName: course.name,
            ),
          );
          await settle();
          await _backGesture(tester);
          await settle();
          expect(router.routeInformationProvider.value.uri.path, Routes.home);
          await tester.tap(
            find.descendant(of: dock, matching: find.byTooltip('课程')),
          );
          await settle();
          expect(
            tester.state(find.byType(CourseDetailScreen)),
            same(courseState),
          );
          expect(
            tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
            1,
          );
        }

        final currentPosition = tester
            .state<ScrollableState>(scrollable)
            .position;
        currentPosition.jumpTo(currentPosition.maxScrollExtent);
        await settle();
        final lastLabel = find.textContaining(target.prefix).last;
        final lastCard = switch (target.tab) {
          0 =>
            find
                .ancestor(of: lastLabel, matching: find.byType(StudySurface))
                .first,
          1 => find.byType(FileCard).last,
          _ => find.byType(AssignmentListItem).last,
        };
        expect(
          tester.getBottomLeft(lastCard).dy,
          lessThan(tester.getTopLeft(find.byType(AppBottomNavigation)).dy),
          reason: 'The complete last row must scroll above the floating dock.',
        );
        // Once it is visible again, the course itself can return normally.
        await _backGesture(tester);
        await settle();
        expect(router.routeInformationProvider.value.uri.path, Routes.courses);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }
}

Future<void> _backGesture(WidgetTester tester, {bool cancel = false}) async {
  for (final call in [
    const MethodCall('startBackGesture', {
      'touchOffset': [5.0, 300.0],
      'progress': 0.0,
      'swipeEdge': 0,
    }),
    const MethodCall('updateBackGestureProgress', {
      'touchOffset': [120.0, 300.0],
      'progress': 0.4,
      'swipeEdge': 0,
    }),
    MethodCall(cancel ? 'cancelBackGesture' : 'commitBackGesture'),
  ]) {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/backgesture',
      const StandardMethodCodec().encodeMethodCall(call),
      (_) {},
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
}

class _Connected extends StateNotifier<ConnectivityState>
    implements ConnectivityNotifier {
  _Connected() : super(const ConnectivityState(status: NetworkStatus.online));
}
