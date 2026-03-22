/// Centralized keys for app-level persisted state.
abstract final class AppStateKeys {
  static const String username = 'username';
  static const String userDepartment = 'user_department';
  static const String currentSemesterId = 'current_semester_id';
  static const String themeMode = 'theme_mode';
  static const String deadlineThresholdHours = 'deadline_threshold_hours';
  static const String fileCacheLimitMb = 'file_cache_limit_mb';
  static const String autoReloginEnabled = 'auto_relogin_enabled';
  static const String recentSearches = 'recent_searches';
  static const String homeScheduleSnapshot = 'home_schedule_snapshot';
}
