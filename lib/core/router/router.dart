/// LearnY Router — GoRouter with ShellRoute for 4-tab navigation.
///
/// Detail pages (notification, homework) are full-screen routes that push
/// ABOVE the shell. This gives focused reading experience with proper back
/// navigation and no bottom nav distraction.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

export 'package:go_router/go_router.dart' show GoRouter;

import '../providers/providers.dart';

import '../../features/home/home_screen.dart';
import '../../features/assignments/assignments_screen.dart';
import '../../features/assignments/homework_detail_screen.dart';
import '../../features/courses/courses_screen.dart';
import '../../features/courses/course_detail_screen.dart';

import '../../features/files/file_detail_screen.dart';
import '../../features/files/file_manager_screen.dart';
import '../../features/files/unread_files_screen.dart';
import '../../features/notifications/notification_detail_screen.dart';
import '../../features/search/search_screen.dart';
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
  static const String search = '/search';

  // Detail routes (full screen, above shell)
  static String courseDetail(String courseId) => '/courses/$courseId';

  static const String _notificationDetailPath = '/notification-detail';
  static const String _homeworkDetailPath = '/homework-detail';
  static const String _fileDetailPath = '/file-detail';
  static const String _fileManagerPath = '/file-manager';

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

  static String fileDetail({
    required String fileId,
    required String courseId,
    required String courseName,
  }) =>
      '$_fileDetailPath?id=$fileId&courseId=$courseId&courseName=${Uri.encodeComponent(courseName)}';

  static const String fileManager = _fileManagerPath;
  static const String unreadFiles = '/unread-files';
}

/// Safely decode a URI component — falls back to raw value if decoding fails
/// (e.g. when courseName contains malformed percent encoding like a literal %).
String _safeDecode(String value) {
  try {
    return Uri.decodeComponent(value);
  } catch (_) {
    return value;
  }
}

/// Navigation key for the shell.
final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Build the app router.
///
/// Takes [ref] to reactively read auth state inside redirect.
/// The router is created ONCE and reacts to auth changes via redirect.
GoRouter buildRouter({required WidgetRef ref}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isOnLogin = state.matchedLocation == Routes.login;

      // Still loading auth state from DB — don't redirect yet.
      // initialLocation is home, so user sees home screen while loading.
      if (auth.status == AuthStatus.unknown) return null;

      if (!auth.isLoggedIn && !isOnLogin) return Routes.login;
      if (auth.isLoggedIn && isOnLogin) return Routes.home;
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
            courseName: _safeDecode(q['courseName'] ?? ''),
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
            courseName: _safeDecode(q['courseName'] ?? ''),
          );
        },
      ),

      GoRoute(
        path: Routes.search,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SearchScreen(),
      ),

      GoRoute(
        path: Routes._fileDetailPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return FileDetailScreen(
            fileId: q['id'] ?? '',
            courseId: q['courseId'] ?? '',
            courseName: _safeDecode(q['courseName'] ?? ''),
          );
        },
      ),

      GoRoute(
        path: Routes._fileManagerPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FileManagerScreen(),
      ),

      GoRoute(
        path: Routes.unreadFiles,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UnreadFilesScreen(),
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

