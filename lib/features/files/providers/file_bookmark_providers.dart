import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/enums.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/files/cached_asset_repository.dart';
import '../../../core/files/file_bookmark_repository.dart';
import '../../../core/files/file_models.dart';
import '../../../core/files/file_repository.dart';
import '../../../core/providers/providers.dart';
import '../../../core/utils/stream_combiner.dart';

class FileFavoriteActions {
  const FileFavoriteActions(this._ref);

  final Ref _ref;

  Future<void> setFavorite({
    required FileDetailItem item,
    required bool isFavorite,
  }) async {
    final bookmarks = _ref.read(fileBookmarkRepositoryProvider);
    final fileRepository = _ref.read(fileRepositoryProvider);

    if (isFavorite) {
      await bookmarks.save(item.cacheKey, courseName: item.courseName);
    } else {
      await bookmarks.remove(item.cacheKey);
    }

    if (item.sourceKind == 'courseFile' && item.persistedFileId != null) {
      await fileRepository.setFavoriteState(
        item.persistedFileId!,
        isFavorite: isFavorite,
      );

      try {
        final api = _ref.read(apiClientProvider);
        if (isFavorite) {
          await api.addToFavorites(ContentType.file, item.persistedFileId!);
        } else {
          await api.removeFromFavorites(item.persistedFileId!);
        }
      } catch (error, stackTrace) {
        debugPrint(
          'Failed to sync file favorite for ${item.persistedFileId}: '
          '$error\n$stackTrace',
        );
      }
    }
  }
}

final fileFavoriteActionsProvider = Provider<FileFavoriteActions>((ref) {
  return FileFavoriteActions(ref);
});

final bookmarkedAssetKeysProvider = StreamProvider<Set<String>>((ref) {
  return ref.watch(fileBookmarkRepositoryProvider).watchKeys();
});

final bookmarkedFileCountProvider = StreamProvider<int>((ref) {
  return ref
      .watch(fileBookmarkRepositoryProvider)
      .watchAll()
      .map((bookmarks) => bookmarks.length);
});

final fileBookmarkStateProvider = StreamProvider.family<bool, String>((
  ref,
  assetKey,
) {
  return ref.watch(fileBookmarkRepositoryProvider).watchIsBookmarked(assetKey);
});

class FavoriteFileEntry {
  const FavoriteFileEntry({
    required this.assetKey,
    required this.item,
    required this.createdAt,
  });

  final String assetKey;
  final FileDetailItem item;
  final DateTime? createdAt;
}

class FavoriteFileCourseSection {
  const FavoriteFileCourseSection({
    required this.courseId,
    required this.courseName,
    required this.entries,
  });

  final String courseId;
  final String courseName;
  final List<FavoriteFileEntry> entries;
}

class FavoriteFilesPresentation {
  const FavoriteFilesPresentation({
    required this.filteredEntries,
    required this.sections,
  });

  final List<FavoriteFileEntry> filteredEntries;
  final List<FavoriteFileCourseSection> sections;
}

final favoriteFileEntriesProvider = StreamProvider<List<FavoriteFileEntry>>((
  ref,
) {
  final bookmarks = ref.watch(fileBookmarkRepositoryProvider);
  final cachedAssets = ref.watch(cachedAssetRepositoryProvider);
  final fileRepository = ref.watch(fileRepositoryProvider);

  return combineLatest3(
    bookmarks.watchAll(),
    cachedAssets.watchAllAssets(),
    fileRepository.watchAllFiles(),
    _buildFavoriteFileEntries,
  );
});

FavoriteFilesPresentation buildFavoriteFilesPresentation({
  required List<FavoriteFileEntry> entries,
  String searchQuery = '',
}) {
  final normalizedQuery = searchQuery.trim().toLowerCase();
  final filtered = normalizedQuery.isEmpty
      ? entries
      : entries
            .where(
              (entry) =>
                  entry.item.title.toLowerCase().contains(normalizedQuery) ||
                  entry.item.courseName.toLowerCase().contains(normalizedQuery),
            )
            .toList();

  final grouped = <String, List<FavoriteFileEntry>>{};
  for (final entry in filtered) {
    grouped.putIfAbsent(entry.item.courseId, () => []).add(entry);
  }

  final sections =
      grouped.entries.map((group) {
        final sectionEntries = group.value.toList()
          ..sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        return FavoriteFileCourseSection(
          courseId: group.key,
          courseName: sectionEntries.first.item.courseName,
          entries: sectionEntries,
        );
      }).toList()..sort((a, b) {
        final aTime =
            a.entries.first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b.entries.first.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

  return FavoriteFilesPresentation(
    filteredEntries: filtered,
    sections: sections,
  );
}

List<FavoriteFileEntry> _buildFavoriteFileEntries(
  List<db.FileBookmark> bookmarks,
  List<db.CachedAsset> assets,
  List<db.CourseFile> courseFiles,
) {
  final assetMap = {for (final asset in assets) asset.assetKey: asset};
  final courseFileMap = {for (final file in courseFiles) file.id: file};
  final entries = <FavoriteFileEntry>[];

  for (final bookmark in bookmarks) {
    final asset = assetMap[bookmark.assetKey];
    if (asset == null) {
      continue;
    }

    final routeData = FileDetailRouteData.tryParseJsonString(
      asset.routeDataJson,
    );
    final routeCourseName = routeData?.courseName ?? '';
    final courseName = routeCourseName.isNotEmpty
        ? routeCourseName
        : bookmark.courseName;

    FileDetailItem? item;
    final persistedFileId = asset.persistedFileId;
    if (persistedFileId != null && persistedFileId.isNotEmpty) {
      final file = courseFileMap[persistedFileId];
      if (file == null) {
        continue;
      }
      item = FileDetailItem.fromCourseFile(file, courseName: courseName);
    } else {
      final cachedItem = CachedAssetListItem.fromCachedAsset(
        asset,
        courseName: courseName,
      );
      if (cachedItem.routeData?.attachment == null) {
        continue;
      }
      item = FileDetailItem.fromCachedAssetListItem(cachedItem);
    }

    entries.add(
      FavoriteFileEntry(
        assetKey: bookmark.assetKey,
        item: item,
        createdAt: DateTime.tryParse(bookmark.createdAt),
      ),
    );
  }

  entries.sort((a, b) {
    final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
  return entries;
}
