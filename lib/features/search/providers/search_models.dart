import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';

enum SearchCategory { course, notification, homework, file }

class SearchResult {
  const SearchResult({
    required this.category,
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isFavorite = false,
  });

  final SearchCategory category;
  final String id;
  final String courseId;
  final String courseName;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isFavorite;
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

const searchCategoryOrder = <SearchCategory>[
  SearchCategory.course,
  SearchCategory.notification,
  SearchCategory.homework,
  SearchCategory.file,
];

(String, IconData, Color) searchCategoryPresentation(SearchCategory category) {
  return switch (category) {
    SearchCategory.course => ('课程', Icons.school_rounded, AppColors.primary),
    SearchCategory.notification => (
      '通知',
      Icons.notifications_rounded,
      AppColors.info,
    ),
    SearchCategory.homework => (
      '作业',
      Icons.assignment_rounded,
      AppColors.warning,
    ),
    SearchCategory.file => (
      '文件',
      Icons.insert_drive_file_rounded,
      const Color(0xFF8B5CF6),
    ),
  };
}
