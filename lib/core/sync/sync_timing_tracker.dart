class SyncCooldownDecision {
  const SyncCooldownDecision({
    required this.lastSynced,
    required this.cooldownSeconds,
  });

  final DateTime lastSynced;
  final int cooldownSeconds;
}

class SyncTimingTracker {
  static const _globalCooldown = Duration(seconds: 30);
  static const _homeworkCooldown = Duration(seconds: 10);
  static const _fileCooldown = Duration(seconds: 15);
  static const _courseCooldown = Duration(seconds: 5);

  final _fullSyncTimes = <String, DateTime>{};
  final _homeworkSyncTimes = <String, DateTime>{};
  final _fileSyncTimes = <String, DateTime>{};
  final _courseSyncTimes = <String, DateTime>{};

  SyncCooldownDecision? checkFullSync(DateTime now, {String scope = ''}) {
    return _check(_fullSyncTimes[scope], _globalCooldown, now);
  }

  SyncCooldownDecision? checkHomeworkSync(DateTime now, {String scope = ''}) {
    return _check(_homeworkSyncTimes[scope], _homeworkCooldown, now);
  }

  SyncCooldownDecision? checkFileSync(DateTime now, {String scope = ''}) {
    return _check(_fileSyncTimes[scope], _fileCooldown, now);
  }

  SyncCooldownDecision? checkCourseSync(
    String courseId,
    DateTime now, {
    String scope = '',
  }) {
    return _check(_courseSyncTimes['$scope::$courseId'], _courseCooldown, now);
  }

  void recordFullSync(
    Iterable<String> courseIds,
    DateTime timestamp, {
    String scope = '',
  }) {
    _fullSyncTimes[scope] = timestamp;
    _homeworkSyncTimes[scope] = timestamp;
    _fileSyncTimes[scope] = timestamp;
    for (final courseId in courseIds) {
      _courseSyncTimes['$scope::$courseId'] = timestamp;
    }
  }

  void recordHomeworkSync(DateTime timestamp, {String scope = ''}) {
    _homeworkSyncTimes[scope] = timestamp;
  }

  void recordFileSync(DateTime timestamp, {String scope = ''}) {
    _fileSyncTimes[scope] = timestamp;
  }

  void recordCourseSync(
    String courseId,
    DateTime timestamp, {
    String scope = '',
  }) {
    _courseSyncTimes['$scope::$courseId'] = timestamp;
  }

  SyncCooldownDecision? _check(
    DateTime? lastSynced,
    Duration cooldown,
    DateTime now,
  ) {
    if (lastSynced == null) return null;

    final elapsed = now.difference(lastSynced);
    if (elapsed >= cooldown) return null;

    return SyncCooldownDecision(
      lastSynced: lastSynced,
      cooldownSeconds: cooldown.inSeconds - elapsed.inSeconds,
    );
  }
}
