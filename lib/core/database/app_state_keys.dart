/// Centralized keys for app-level persisted state.
abstract final class AppStateKeys {
  static const String username = 'username';
  static const String learningDataOwner = 'learning_data_owner';
  static const String userDepartment = 'user_department';
  static const String currentSemesterId = 'current_semester_id';
  static const String serverCurrentSemesterId = 'server_current_semester_id';
  static const String themeMode = 'theme_mode';
  static const String wallpaper = 'wallpaper';
  static const String customWallpaper = 'custom_wallpaper';
  static String wallpaperIntensity(String id) => 'wallpaper_intensity::$id';
  static const String deadlineThresholdHours = 'deadline_threshold_hours';
  static const String fileCacheLimitMb = 'file_cache_limit_mb';
  static const String autoReloginEnabled = 'auto_relogin_enabled';
  static const String autoReloginStatus = 'auto_relogin_status';
  static const String identityAccountHint = 'identity_account_hint';
  static const String guideState = 'guide_state';
  static const String recentSearches = 'recent_searches';
  static const String homeScheduleSnapshot = 'home_schedule_snapshot';
  static const String homeScheduleSemesterCachePrefix =
      'home_schedule_semester_cache';
  static const String homeScheduleRemoteRefreshState =
      'home_schedule_remote_refresh_state';
  static const String homeworkNoSubmissionNeededPrefix =
      'homework_no_submission_needed';

  static String homeScheduleSemesterCache(String semesterId) =>
      '$homeScheduleSemesterCachePrefix::$semesterId';

  static const scheduleWeekPrefix = 'schedule_week';
  static const courseCatalogPrefix = 'course_catalog';
  static String courseCatalogUpdatedAt(String semesterId) =>
      '$courseCatalogPrefix::$semesterId::updated_at';
  static String courseCatalogWithdrawn(String semesterId) =>
      '$courseCatalogPrefix::$semesterId::withdrawn';
  static String scheduleWeekSnapshot(String semesterId, String firstDay) =>
      '$scheduleWeekPrefix::$semesterId::$firstDay::snapshot';
  static String scheduleWeekRefresh(String semesterId, String firstDay) =>
      '$scheduleWeekPrefix::$semesterId::$firstDay::refresh';
}
