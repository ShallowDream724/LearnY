/// LearnY Router — GoRouter with ShellRoute for 4-tab navigation.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/assignments/assignments_screen.dart';
import '../../features/courses/courses_screen.dart';
import '../../features/courses/course_detail_screen.dart';
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

  // Detail routes
  static String courseDetail(String courseId) => '/courses/$courseId';
  static const String assignmentDetail = '/assignments/:assignmentId';
  static const String notificationDetail = '/notifications/:notificationId';
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
      // Login (full screen, outside shell)
      GoRoute(
        path: Routes.login,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),

      // Main app shell with 4 tabs
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
              // Course detail — nested under /courses/:courseId
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
