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

  DateTime? _lastFullSync;
  DateTime? _lastHomeworkSync;
  DateTime? _lastFileSync;
  final _courseSyncTimes = <String, DateTime>{};

  SyncCooldownDecision? checkFullSync(DateTime now) {
    return _check(_lastFullSync, _globalCooldown, now);
  }

  SyncCooldownDecision? checkHomeworkSync(DateTime now) {
    return _check(_lastHomeworkSync, _homeworkCooldown, now);
  }

  SyncCooldownDecision? checkFileSync(DateTime now) {
    return _check(_lastFileSync, _fileCooldown, now);
  }

  SyncCooldownDecision? checkCourseSync(String courseId, DateTime now) {
    return _check(_courseSyncTimes[courseId], _courseCooldown, now);
  }

  void recordFullSync(Iterable<String> courseIds, DateTime timestamp) {
    _lastFullSync = timestamp;
    for (final courseId in courseIds) {
      _courseSyncTimes[courseId] = timestamp;
    }
  }

  void recordHomeworkSync(DateTime timestamp) {
    _lastHomeworkSync = timestamp;
  }

  void recordFileSync(DateTime timestamp) {
    _lastFileSync = timestamp;
  }

  void recordCourseSync(String courseId, DateTime timestamp) {
    _courseSyncTimes[courseId] = timestamp;
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
