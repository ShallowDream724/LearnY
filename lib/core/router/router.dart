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

import '../files/file_models.dart';
import '../providers/providers.dart';

import '../../features/home/home_screen.dart';
import '../../features/assignments/assignments_screen.dart';
import '../../features/assignments/homework_detail_screen.dart';
import '../../features/courses/courses_screen.dart';
import '../../features/courses/course_detail_screen.dart';
import '../../features/courses/course_search_screen.dart';

import '../../features/files/file_detail_screen.dart';
import '../../features/files/favorite_files_screen.dart';
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
  static String loginWithReturnTo(String? location) {
    if (location == null || location.isEmpty) return login;
    final encoded = Uri.encodeComponent(location);
    return '$login?from=$encoded';
  }

  static String courseDetail(String courseId) => '/courses/$courseId';

  static const String _notificationDetailPath = '/notification-detail';
  static const String _homeworkDetailPath = '/homework-detail';
  static const String _fileDetailPath = '/file-detail';
  static const String _fileManagerPath = '/file-manager';
  static const String _courseSearchPath = '/course-search';
  static const String _favoriteFilesPath = '/favorite-files';

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
    String? fileId,
    required String courseId,
    required String courseName,
    FileAttachment? attachment,
  }) {
    final routeData = attachment != null
        ? FileDetailRouteData.attachment(
            attachment: attachment,
            courseId: courseId,
            courseName: courseName,
          )
        : FileDetailRouteData.courseFile(
            fileId: fileId ?? '',
            courseId: courseId,
            courseName: courseName,
          );

    return fileDetailFromData(routeData);
  }

  static String fileDetailFromData(FileDetailRouteData routeData) {
    final query = Uri(queryParameters: routeData.toQueryParameters()).query;
    return '$_fileDetailPath?$query';
  }

  static const String fileManager = _fileManagerPath;
  static const String favoriteFiles = _favoriteFilesPath;
  static const String unreadFiles = '/unread-files';

  static String courseSearch({
    required String courseId,
    required String courseName,
  }) =>
      '$_courseSearchPath?courseId=$courseId&courseName=${Uri.encodeComponent(courseName)}';
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
final _homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'homeBranch');
final _assignmentsNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'assignmentsBranch',
);
final _coursesNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'coursesBranch',
);
final _profileNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'profileBranch',
);

/// Build the app router.
///
/// Takes [ref] to reactively read auth state inside redirect.
/// The router is created ONCE and reacts to auth changes via redirect.
GoRouter buildRouter({required WidgetRef ref}) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: ref.read(authRouterRefreshNotifierProvider),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isOnLogin = state.matchedLocation == Routes.login;
      final returnTo = state.uri.queryParameters['from'];

      // Still loading auth state from DB — don't redirect yet.
      // initialLocation is home, so user sees home screen while loading.
      if (auth.isRestoring) return null;

      if (auth.isSignedOut && !isOnLogin) {
        return Routes.login;
      }
      if (isOnLogin &&
          auth.canAccessCachedData &&
          !auth.requiresReauthentication) {
        if (returnTo != null &&
            returnTo.isNotEmpty &&
            returnTo != Routes.login) {
          return returnTo;
        }
        return Routes.home;
      }
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
          final q = state.uri.queryParameters.map(
            (key, value) => MapEntry(key, _safeDecode(value)),
          );
          final routeData = FileDetailRouteData.fromQueryParameters(q);
          return FileDetailScreen(routeData: routeData);
        },
      ),

      GoRoute(
        path: Routes._fileManagerPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FileManagerScreen(),
      ),

      GoRoute(
        path: Routes._favoriteFilesPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const FavoriteFilesScreen(),
      ),

      GoRoute(
        path: Routes.unreadFiles,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const UnreadFilesScreen(),
      ),

      GoRoute(
        path: Routes._courseSearchPath,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final q = state.uri.queryParameters;
          return CourseSearchScreen(
            courseId: q['courseId'] ?? '',
            courseName: _safeDecode(q['courseName'] ?? ''),
          );
        },
      ),

      // ── Main app shell with 4 tabs ──
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        navigatorContainerBuilder: buildAppShellBranchContainer,
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _assignmentsNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.assignments,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: AssignmentsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _coursesNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.courses,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: CoursesScreen()),
                routes: [
                  GoRoute(
                    path: ':courseId',
                    builder: (context, state) => CourseDetailScreen(
                      courseId: state.pathParameters['courseId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: Routes.profile,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
