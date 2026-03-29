import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/files/file_models.dart';

enum SearchResultKind {
  course,
  notification,
  homework,
  courseFile,
  notificationAttachment,
  homeworkAttachment,
  homeworkSubmittedAttachment,
  homeworkGradeAttachment,
  homeworkAnswerAttachment,
}

enum SearchNavigationType {
  courseDetail,
  notificationDetail,
  homeworkDetail,
  fileDetail,
}

enum SearchSectionKind { keyword, related }

class SearchSectionMeta {
  const SearchSectionMeta({
    required this.id,
    required this.title,
    required this.resultKind,
    required this.kind,
    required this.order,
  });

  final String id;
  final String title;
  final SearchResultKind resultKind;
  final SearchSectionKind kind;
  final int order;

  IconData get icon => searchResultKindPresentation(resultKind).$2;
  Color get accentColor => searchResultKindPresentation(resultKind).$3;
}

class SearchResult {
  const SearchResult({
    required this.key,
    required this.kind,
    required this.navigationType,
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.subtitle,
    required this.section,
    this.fileRouteData,
    this.isFavorite = false,
    this.isDownloaded = false,
  });

  final String key;
  final SearchResultKind kind;
  final SearchNavigationType navigationType;
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String subtitle;
  final SearchSectionMeta section;
  final FileDetailRouteData? fileRouteData;
  final bool isFavorite;
  final bool isDownloaded;

  IconData get icon => searchResultKindPresentation(kind).$2;
  Color get accentColor => searchResultKindPresentation(kind).$3;

  SearchResult copyWith({
    SearchSectionMeta? section,
    bool? isFavorite,
    bool? isDownloaded,
  }) {
    return SearchResult(
      key: key,
      kind: kind,
      navigationType: navigationType,
      id: id,
      courseId: courseId,
      courseName: courseName,
      title: title,
      subtitle: subtitle,
      section: section ?? this.section,
      fileRouteData: fileRouteData,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const <SearchResult>[],
    this.recentSearches = const <String>[],
    this.isSearching = false,
    this.hasSearched = false,
  });

  final String query;
  final List<SearchResult> results;
  final List<String> recentSearches;
  final bool isSearching;
  final bool hasSearched;

  SearchState copyWith({
    String? query,
    List<SearchResult>? results,
    List<String>? recentSearches,
    bool? isSearching,
    bool? hasSearched,
  }) {
    return SearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      recentSearches: recentSearches ?? this.recentSearches,
      isSearching: isSearching ?? this.isSearching,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class SearchResultGroup {
  const SearchResultGroup({required this.section, required this.results});

  final SearchSectionMeta section;
  final List<SearchResult> results;
}

class SearchResultGroupSplit {
  const SearchResultGroupSplit({
    required this.keywordGroups,
    required this.relatedGroups,
  });

  final List<SearchResultGroup> keywordGroups;
  final List<SearchResultGroup> relatedGroups;

  bool get hasRelatedGroups => relatedGroups.isNotEmpty;
}

List<SearchResultGroup> groupSearchResults(List<SearchResult> results) {
  final grouped = <String, SearchResultGroup>{};
  for (final result in results) {
    final existing = grouped[result.section.id];
    if (existing == null) {
      grouped[result.section.id] = SearchResultGroup(
        section: result.section,
        results: [result],
      );
      continue;
    }
    existing.results.add(result);
  }
  final groups = grouped.values.toList(growable: false);
  groups.sort(
    (left, right) => left.section.order.compareTo(right.section.order),
  );
  return groups;
}

SearchResultGroupSplit splitSearchResultGroups(List<SearchResultGroup> groups) {
  final keywordGroups = <SearchResultGroup>[];
  final relatedGroups = <SearchResultGroup>[];

  for (final group in groups) {
    switch (group.section.kind) {
      case SearchSectionKind.keyword:
        keywordGroups.add(group);
        break;
      case SearchSectionKind.related:
        relatedGroups.add(group);
        break;
    }
  }

  return SearchResultGroupSplit(
    keywordGroups: keywordGroups,
    relatedGroups: relatedGroups,
  );
}

SearchSectionMeta buildExactSectionMeta(SearchResultKind kind) {
  final label = searchResultKindPresentation(kind).$1;
  return SearchSectionMeta(
    id: 'exact:${kind.name}',
    title: label,
    resultKind: kind,
    kind: SearchSectionKind.keyword,
    order: searchResultKindBaseOrder(kind),
  );
}

SearchSectionMeta buildRelatedSectionMeta({
  required String idSuffix,
  required String title,
  required SearchResultKind kind,
  required int order,
}) {
  return SearchSectionMeta(
    id: 'related:$idSuffix',
    title: title,
    resultKind: kind,
    kind: SearchSectionKind.related,
    order: 1000 + order,
  );
}

int searchResultKindBaseOrder(SearchResultKind kind) {
  return switch (kind) {
    SearchResultKind.course => 0,
    SearchResultKind.notification => 10,
    SearchResultKind.homework => 20,
    SearchResultKind.courseFile => 30,
    SearchResultKind.notificationAttachment => 40,
    SearchResultKind.homeworkAttachment => 50,
    SearchResultKind.homeworkSubmittedAttachment => 60,
    SearchResultKind.homeworkGradeAttachment => 70,
    SearchResultKind.homeworkAnswerAttachment => 80,
  };
}

(String, IconData, Color) searchResultKindPresentation(SearchResultKind kind) {
  return switch (kind) {
    SearchResultKind.course => ('课程', Icons.school_rounded, AppColors.primary),
    SearchResultKind.notification => (
      '通知',
      Icons.notifications_rounded,
      AppColors.info,
    ),
    SearchResultKind.homework => (
      '作业',
      Icons.assignment_rounded,
      AppColors.warning,
    ),
    SearchResultKind.courseFile => (
      '文件',
      Icons.insert_drive_file_rounded,
      const Color(0xFF8B5CF6),
    ),
    SearchResultKind.notificationAttachment => (
      '通知附件',
      Icons.attach_file_rounded,
      AppColors.info,
    ),
    SearchResultKind.homeworkAttachment => (
      '作业附件',
      Icons.attach_file_rounded,
      AppColors.warning,
    ),
    SearchResultKind.homeworkSubmittedAttachment => (
      '提交附件',
      Icons.upload_file_rounded,
      AppColors.success,
    ),
    SearchResultKind.homeworkGradeAttachment => (
      '教师反馈附件',
      Icons.rate_review_rounded,
      AppColors.info,
    ),
    SearchResultKind.homeworkAnswerAttachment => (
      '参考答案附件',
      Icons.auto_stories_rounded,
      const Color(0xFF8B5CF6),
    ),
  };
}
