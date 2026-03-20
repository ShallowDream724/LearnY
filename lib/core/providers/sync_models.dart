/// Sync & home data model classes.
///
/// Lightweight summary types used by providers and UI.
/// Separated from provider logic for clean imports.
library;

// ---------------------------------------------------------------------------
// Sync state
// ---------------------------------------------------------------------------

enum SyncStatus { idle, syncing, success, error, sessionExpired, cooldown }

class SyncState {
  final SyncStatus status;
  final String? errorMessage;
  final DateTime? lastSynced;

  /// Per-course warnings (partial failures that didn't block overall sync).
  final List<String> syncWarnings;

  /// Number of items updated in the last sync.
  final int updatedCount;

  /// Seconds remaining before next sync allowed (only for cooldown status).
  final int cooldownSeconds;

  const SyncState({
    this.status = SyncStatus.idle,
    this.errorMessage,
    this.lastSynced,
    this.syncWarnings = const [],
    this.updatedCount = 0,
    this.cooldownSeconds = 0,
  });
}

// ---------------------------------------------------------------------------
// Home data — aggregated from multiple sources
// ---------------------------------------------------------------------------

class HomeData {
  final List<HomeworkSummary> urgentAssignments;
  final List<NotificationSummary> unreadNotifications;
  final List<FileSummary> newFiles;
  final List<GradeSummary> recentGrades;
  final int totalCourses;
  final int pendingAssignments;
  final int unreadCount;
  final int totalUnreadFiles;

  const HomeData({
    this.urgentAssignments = const [],
    this.unreadNotifications = const [],
    this.newFiles = const [],
    this.recentGrades = const [],
    this.totalCourses = 0,
    this.pendingAssignments = 0,
    this.unreadCount = 0,
    this.totalUnreadFiles = 0,
  });
}

/// Lightweight homework summary for home screen cards.
class HomeworkSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String deadline;
  final Duration timeRemaining;
  final bool isOverdue;

  const HomeworkSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.deadline,
    required this.timeRemaining,
    required this.isOverdue,
  });
}

/// Lightweight notification summary.
class NotificationSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String publisher;
  final String publishTime;
  final bool markedImportant;

  const NotificationSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.publisher,
    required this.publishTime,
    required this.markedImportant,
  });
}

/// Lightweight file summary.
class FileSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String size;
  final String fileType;
  final String uploadTime;

  const FileSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.size,
    required this.fileType,
    required this.uploadTime,
  });
}

/// Lightweight grade summary.
class GradeSummary {
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final double? grade;
  final String? gradeLevel;
  final String? gradeContent;

  const GradeSummary({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    this.grade,
    this.gradeLevel,
    this.gradeContent,
  });
}
