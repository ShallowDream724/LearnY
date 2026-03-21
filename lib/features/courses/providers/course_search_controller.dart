import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../search/providers/search_models.dart';
import 'course_search_repository.dart';

class CourseSearchState {
  const CourseSearchState({
    this.query = '',
    this.results = const <SearchResult>[],
    this.isSearching = false,
    this.hasSearched = false,
  });

  final String query;
  final List<SearchResult> results;
  final bool isSearching;
  final bool hasSearched;

  CourseSearchState copyWith({
    String? query,
    List<SearchResult>? results,
    bool? isSearching,
    bool? hasSearched,
  }) {
    return CourseSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      isSearching: isSearching ?? this.isSearching,
      hasSearched: hasSearched ?? this.hasSearched,
    );
  }
}

class CourseSearchArgs {
  const CourseSearchArgs({required this.courseId, required this.courseName});

  final String courseId;
  final String courseName;
}

class CourseSearchController extends StateNotifier<CourseSearchState> {
  CourseSearchController(this._args, this._repository)
    : super(const CourseSearchState());

  final CourseSearchArgs _args;
  final CourseSearchRepository _repository;

  Timer? _debounce;
  int _generation = 0;

  void onQueryChanged(String rawQuery) {
    final query = rawQuery.trim();
    _debounce?.cancel();

    if (query.isEmpty) {
      state = state.copyWith(
        query: '',
        results: const <SearchResult>[],
        isSearching: false,
        hasSearched: false,
      );
      return;
    }

    state = state.copyWith(query: query, isSearching: true);
    _debounce = Timer(const Duration(milliseconds: 250), () {
      unawaited(_performSearch(query));
    });
  }

  Future<void> _performSearch(String query) async {
    final generation = ++_generation;
    final results = await _repository.search(
      courseId: _args.courseId,
      courseName: _args.courseName,
      query: query,
    );
    if (generation != _generation) {
      return;
    }
    state = state.copyWith(
      query: query,
      results: results,
      isSearching: false,
      hasSearched: true,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final courseSearchControllerProvider = StateNotifierProvider.autoDispose
    .family<CourseSearchController, CourseSearchState, CourseSearchArgs>((
      ref,
      args,
    ) {
      return CourseSearchController(
        args,
        ref.watch(courseSearchRepositoryProvider),
      );
    });
