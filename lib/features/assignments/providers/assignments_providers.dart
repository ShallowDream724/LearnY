import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/deadline_time.dart';

enum HomeworkFilter { all, pending, submitted, graded }

enum AssignmentTimelineGroup { thisWeek, nextWeek, later, done }

const assignmentTimelineOrder = <AssignmentTimelineGroup>[
  AssignmentTimelineGroup.thisWeek,
  AssignmentTimelineGroup.nextWeek,
  AssignmentTimelineGroup.later,
  AssignmentTimelineGroup.done,
];

class AssignmentStats {
  const AssignmentStats({
    required this.pending,
    required this.submitted,
    required this.graded,
    required this.overdue,
  });

  final int pending;
  final int submitted;
  final int graded;
  final int overdue;
}

class AssignmentTimelineSection {
  const AssignmentTimelineSection({
    required this.group,
    required this.homeworks,
  });

  final AssignmentTimelineGroup group;
  final List<Homework> homeworks;
}

class AssignmentsPresentation {
  const AssignmentsPresentation({
    required this.stats,
    required this.filteredHomeworks,
    required this.sections,
  });

  final AssignmentStats stats;
  final List<Homework> filteredHomeworks;
  final List<AssignmentTimelineSection> sections;

  bool get isEmpty => filteredHomeworks.isEmpty;
}

final homeworkFilterProvider = StateProvider<HomeworkFilter>(
  (ref) => HomeworkFilter.all,
);

final assignmentHomeworksProvider = StreamProvider<List<Homework>>((ref) {
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) {
    return Stream.value(const <Homework>[]);
  }

  return database.watchHomeworksBySemester(semesterId);
});

final assignmentCourseNameMapProvider = StreamProvider<Map<String, String>>((
  ref,
) {
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) {
    return Stream.value(const <String, String>{});
  }

  return database
      .watchCoursesBySemester(semesterId)
      .map((courses) => {for (final course in courses) course.id: course.name});
});

final homeworkDetailProvider = StreamProvider.family<Homework?, String>((
  ref,
  homeworkId,
) {
  final db = ref.watch(databaseProvider);
  return db.watchHomeworkById(homeworkId);
});

AssignmentsPresentation buildAssignmentsPresentation({
  required List<Homework> homeworks,
  required HomeworkFilter filter,
  DateTime? now,
}) {
  final resolvedNow = now ?? nowInShanghai();
  final filteredHomeworks = homeworks
      .where((homework) => _matchesFilter(homework, filter))
      .toList();
  final groupedHomeworks = <AssignmentTimelineGroup, List<Homework>>{};

  for (final homework in filteredHomeworks) {
    final group = _classifyHomework(homework, resolvedNow);
    (groupedHomeworks[group] ??= []).add(homework);
  }

  final sections = assignmentTimelineOrder
      .where(groupedHomeworks.containsKey)
      .map((group) {
        final groupHomeworks = groupedHomeworks[group]!
          ..sort(_compareDeadlines);
        return AssignmentTimelineSection(
          group: group,
          homeworks: groupHomeworks,
        );
      })
      .toList();

  return AssignmentsPresentation(
    stats: _computeAssignmentStats(homeworks, resolvedNow),
    filteredHomeworks: filteredHomeworks,
    sections: sections,
  );
}

AssignmentStats _computeAssignmentStats(
  List<Homework> homeworks,
  DateTime now,
) {
  var pending = 0;
  var submitted = 0;
  var graded = 0;
  var overdue = 0;

  for (final homework in homeworks) {
    if (homework.graded) {
      graded++;
      continue;
    }
    if (homework.submitted) {
      submitted++;
      continue;
    }

    pending++;
    final deadlineMs = int.tryParse(homework.deadline);
    if (deadlineMs != null &&
        (tryParseEpochMillisToLocal(homework.deadline)?.isBefore(now) ??
            false)) {
      overdue++;
    }
  }

  return AssignmentStats(
    pending: pending,
    submitted: submitted,
    graded: graded,
    overdue: overdue,
  );
}

bool _matchesFilter(Homework homework, HomeworkFilter filter) {
  return switch (filter) {
    HomeworkFilter.pending => !homework.submitted && !homework.graded,
    HomeworkFilter.submitted => homework.submitted && !homework.graded,
    HomeworkFilter.graded => homework.graded,
    HomeworkFilter.all => true,
  };
}

AssignmentTimelineGroup _classifyHomework(Homework homework, DateTime now) {
  if (homework.submitted || homework.graded) {
    return AssignmentTimelineGroup.done;
  }

  final deadlineMs = int.tryParse(homework.deadline);
  if (deadlineMs == null) {
    return AssignmentTimelineGroup.later;
  }

  final deadline = tryParseEpochMillisToLocal(homework.deadline);
  if (deadline == null) {
    return AssignmentTimelineGroup.later;
  }
  final remaining = deadline.difference(now);
  if (remaining.isNegative) {
    return AssignmentTimelineGroup.thisWeek;
  }

  final nowMonday = _mondayOfWeek(now);
  final deadlineMonday = _mondayOfWeek(deadline);
  if (nowMonday == deadlineMonday) {
    return AssignmentTimelineGroup.thisWeek;
  }

  final nextMonday = nowMonday.add(const Duration(days: 7));
  final mondayAfterNext = nextMonday.add(const Duration(days: 7));
  if (!deadlineMonday.isBefore(nextMonday) &&
      deadlineMonday.isBefore(mondayAfterNext)) {
    return AssignmentTimelineGroup.nextWeek;
  }

  return AssignmentTimelineGroup.later;
}

DateTime _mondayOfWeek(DateTime value) {
  final dateOnly = DateTime(value.year, value.month, value.day);
  return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
}

int _compareDeadlines(Homework left, Homework right) {
  final leftMs = int.tryParse(left.deadline) ?? 0;
  final rightMs = int.tryParse(right.deadline) ?? 0;
  return leftMs.compareTo(rightMs);
}
