/// LearnY Router — GoRouter with ShellRoute for 4-tab navigation.
///
/// Detail pages (notification, homework) are full-screen routes that push
/// ABOVE the shell. This gives focused reading experience with proper back
/// navigation and no bottom nav distraction.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/assignments/assignments_screen.dart';
import '../../features/assignments/homework_detail_screen.dart';
import '../../features/courses/courses_screen.dart';
import '../../features/courses/course_detail_screen.dart';
import '../../features/notifications/notification_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/auth/login_screen.dart';
import '../shell/app_shell.dart';

/// Route paths.
abstract final class Routes {
  static const String login = '/login';
  static const String home = '/';
  static const String assignments = '/assignments';
  static const String courses = '/courses';
  static const String profile = '/profile';

  // Detail routes (full screen, above shell)
  static String courseDetail(String courseId) => '/courses/$courseId';

  // These use query params for extra data since GoRouter extras are not
  // preserved during deep linking. The courseId + courseName travel via query.
  static const String _notificationDetailPath = '/notification-detail';
  static const String _homeworkDetailPath = '/homework-detail';

  static String notificationDetail({
    required String notificationId,
    required String courseId,
    required String courseName,
  }) =>
      '$_notificationDetailPath?id=$notificationId&courseId=$courseId&courseName=${Uri.encodeComponent(courseName)}';

  static String homeworkDetail({
    required String homeworkId,
    required String courseId,
    required String courseName,
  }) =>
      '$_homeworkDetailPath?id=$homeworkId&courseId=$courseId&courseName=${Uri.encodeComponent(courseName)}';
}

/// Navigation key for the shell.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Build the app router.
///
/// Pass [isLoggedIn] to control auth redirect.
GoRouter buildRouter({required bool isLoggedIn}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    redirect: (context, state) {
      final isOnLogin = state.matchedLocation == Routes.login;
      if (!isLoggedIn && !isOnLogin) return Routes.login;
      if (isLoggedIn && isOnLogin) return Routes.home;
      return null;
    },
    routes: [
      // ── Full-screen routes (above shell) ──

      GoRoute(
        path: Routes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),

      GoRoute(
        path: Routes._notificationDetailPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return NotificationDetailScreen(
            notificationId: q['id'] ?? '',
            courseId: q['courseId'] ?? '',
            courseName: Uri.decodeComponent(q['courseName'] ?? ''),
          );
        },
      ),

      GoRoute(
        path: Routes._homeworkDetailPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return HomeworkDetailScreen(
            homeworkId: q['id'] ?? '',
            courseId: q['courseId'] ?? '',
            courseName: Uri.decodeComponent(q['courseName'] ?? ''),
          );
        },
      ),

      // ── Main app shell with 4 tabs ──

      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: Routes.home,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: Routes.assignments,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AssignmentsScreen(),
            ),
          ),
          GoRoute(
            path: Routes.courses,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CoursesScreen(),
            ),
            routes: [
              GoRoute(
                path: ':courseId',
                builder: (context, state) => CourseDetailScreen(
                  courseId: state.pathParameters['courseId']!,
                ),
              ),
            ],
          ),
          GoRoute(
            path: Routes.profile,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
    ],
  );
}

