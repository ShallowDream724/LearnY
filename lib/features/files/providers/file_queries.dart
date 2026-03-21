import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database.dart' as db;
import '../../../core/files/cached_asset_repository.dart';
import '../../../core/files/file_bookmark_repository.dart';
import '../../../core/files/file_repository.dart';
import '../../../core/files/file_models.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/stream_combiner.dart';

final allFilesWithCourseProvider = StreamProvider<List<FileWithCourse>>((ref) {
  final semesterId = ref.watch(currentSemesterIdProvider);
  return ref.watch(fileRepositoryProvider).watchAllFilesWithCourse(semesterId);
});

enum FileFeedFilter { all, unread, favorite, downloaded }

enum FileFeedTimeGroup { today, thisWeek, earlier }

class FileFeedEntry {
  const FileFeedEntry({required this.item, required this.isFavorite});

  factory FileFeedEntry.fromCourseFile(
    FileWithCourse file, {
    required bool isFavorite,
  }) {
    return FileFeedEntry(
      item: FileDetailItem.fromCourseFile(
        file.file,
        courseName: file.courseName,
      ),
      isFavorite: isFavorite,
    );
  }

  factory FileFeedEntry.fromCachedAsset(
    CachedAssetListItem asset, {
    required bool isFavorite,
  }) {
    return FileFeedEntry(
      item: FileDetailItem.fromCachedAssetListItem(asset),
      isFavorite: isFavorite,
    );
  }

  final FileDetailItem item;
  final bool isFavorite;

  bool get isDownloaded => item.localDownloadState == 'downloaded';
  String get title => item.title;
  String get courseName => item.courseName;
  String get sortTime => item.uploadTime;
}

class FileFeedSection {
  const FileFeedSection({required this.group, required this.entries});

  final FileFeedTimeGroup group;
  final List<FileFeedEntry> entries;
}

class FileFeedPresentation {
  const FileFeedPresentation({
    required this.filteredEntries,
    required this.sections,
  });

  final List<FileFeedEntry> filteredEntries;
  final List<FileFeedSection> sections;
}

final allFileFeedEntriesProvider = StreamProvider<List<FileFeedEntry>>((ref) {
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) {
    return Stream.value(const <FileFeedEntry>[]);
  }

  final database = ref.watch(databaseProvider);
  final fileRepository = ref.watch(fileRepositoryProvider);
  final bookmarkRepository = ref.watch(fileBookmarkRepositoryProvider);
  final cachedAssetRepository = ref.watch(cachedAssetRepositoryProvider);
  final courseMapStream = database
      .watchCoursesBySemester(semesterId)
      .map((courses) => {for (final course in courses) course.id: course.name});

  return combineLatest2(
    bookmarkRepository.watchKeys(),
    combineLatest2(
      fileRepository.watchAllFilesWithCourse(semesterId),
      combineLatest2(
        courseMapStream,
        cachedAssetRepository.watchAllAssets(),
        _buildCachedAttachmentFeedEntries,
      ),
      (courseFiles, cachedAttachments) => (courseFiles, cachedAttachments),
    ),
    (favoriteKeys, data) {
      final (courseFiles, cachedAttachments) = data;
      final entries = [
        ...courseFiles.map(
          (file) => FileFeedEntry.fromCourseFile(
            file,
            isFavorite: favoriteKeys.contains(file.file.id),
          ),
        ),
        ...cachedAttachments.map(
          (entry) => FileFeedEntry(
            item: entry.item,
            isFavorite: favoriteKeys.contains(entry.item.cacheKey),
          ),
        ),
      ];
      entries.sort((a, b) => _compareSortTimeDesc(a.sortTime, b.sortTime));
      return entries;
    },
  );
});

final unreadFilesProvider = StreamProvider<List<db.CourseFile>>((ref) {
  final database = ref.watch(databaseProvider);
  return database.watchUnreadFiles();
});

final fileCourseNameMapProvider = StreamProvider<Map<String, String>>((ref) {
  final database = ref.watch(databaseProvider);
  final semesterId = ref.watch(currentSemesterIdProvider);
  if (semesterId == null) {
    return Stream.value(const <String, String>{});
  }

  return database
      .watchCoursesBySemester(semesterId)
      .map((courses) => {for (final course in courses) course.id: course.name});
});

final fileDetailProvider = StreamProvider.family<db.CourseFile?, String>((
  ref,
  fileId,
) {
  final database = ref.watch(databaseProvider);
  return database.watchFileById(fileId);
});

final fileDetailItemProvider =
    StreamProvider.family<FileDetailItem?, FileDetailRouteData>((
      ref,
      routeData,
    ) {
      if (!routeData.isCourseFile) {
        final cachedAssetRepository = ref.watch(cachedAssetRepositoryProvider);
        final attachment = routeData.attachment!;
        return cachedAssetRepository
            .watchAsset(attachment.cacheKeyForCourse(routeData.courseId))
            .map(
              (cachedAsset) => FileDetailItem.fromAttachment(
                attachment: attachment,
                courseId: routeData.courseId,
                courseName: routeData.courseName,
                cachedAsset: cachedAsset,
              ),
            );
      }

      final database = ref.watch(databaseProvider);
      return database.watchFileById(routeData.fileId!).map((file) {
        if (file == null) {
          return null;
        }
        return FileDetailItem.fromCourseFile(
          file,
          courseName: routeData.courseName,
        );
      });
    });

FileFeedPresentation buildFilesPresentation({
  required List<FileFeedEntry> entries,
  required FileFeedFilter filter,
  String searchQuery = '',
  DateTime? now,
}) {
  var filtered = entries;
  final normalizedQuery = searchQuery.trim().toLowerCase();
  if (normalizedQuery.isNotEmpty) {
    filtered = filtered
        .where(
          (entry) =>
              entry.title.toLowerCase().contains(normalizedQuery) ||
              entry.courseName.toLowerCase().contains(normalizedQuery),
        )
        .toList();
  }

  filtered = switch (filter) {
    FileFeedFilter.all => filtered,
    FileFeedFilter.unread =>
      filtered.where((entry) => entry.item.isNew).toList(),
    FileFeedFilter.favorite =>
      filtered.where((entry) => entry.isFavorite).toList(),
    FileFeedFilter.downloaded =>
      filtered.where((entry) => entry.isDownloaded).toList(),
  };
  filtered.sort((a, b) => _compareSortTimeDesc(a.sortTime, b.sortTime));

  final grouped = <FileFeedTimeGroup, List<FileFeedEntry>>{};
  for (final entry in filtered) {
    final group = _classifyByTime(entry.sortTime, now: now);
    grouped.putIfAbsent(group, () => []).add(entry);
  }

  final sections = FileFeedTimeGroup.values
      .where(grouped.containsKey)
      .map(
        (group) => FileFeedSection(
          group: group,
          entries: grouped[group]!
            ..sort((a, b) => _compareSortTimeDesc(a.sortTime, b.sortTime)),
        ),
      )
      .toList();

  return FileFeedPresentation(filteredEntries: filtered, sections: sections);
}

List<FileFeedEntry> _buildCachedAttachmentFeedEntries(
  Map<String, String> courseNames,
  List<db.CachedAsset> assets,
) {
  final entries = <FileFeedEntry>[];
  for (final asset in assets) {
    if (asset.sourceKind == 'courseFile') {
      continue;
    }

    final item = CachedAssetListItem.fromCachedAsset(
      asset,
      courseName: courseNames[asset.courseId] ?? '',
    );
    if (item.routeData?.attachment == null) {
      continue;
    }
    entries.add(FileFeedEntry.fromCachedAsset(item, isFavorite: false));
  }
  return entries;
}

FileFeedTimeGroup _classifyByTime(String rawTime, {DateTime? now}) {
  try {
    final dt = DateTime.parse(rawTime);
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final weekStart = today.subtract(Duration(days: clock.weekday - 1));

    if (dt.isAfter(today)) {
      return FileFeedTimeGroup.today;
    }
    if (dt.isAfter(weekStart)) {
      return FileFeedTimeGroup.thisWeek;
    }
  } catch (_) {}
  return FileFeedTimeGroup.earlier;
}

int _compareSortTimeDesc(String a, String b) {
  final aTime = DateTime.tryParse(a);
  final bTime = DateTime.tryParse(b);
  if (aTime == null && bTime == null) {
    return 0;
  }
  if (aTime == null) {
    return 1;
  }
  if (bTime == null) {
    return -1;
  }
  return bTime.compareTo(aTime);
}
