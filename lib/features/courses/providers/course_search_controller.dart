import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../search/providers/search_engine.dart';
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
    : super(const CourseSearchState()) {
    unawaited(_warmUpDocuments());
  }

  final CourseSearchArgs _args;
  final CourseSearchRepository _repository;

  Timer? _debounce;
  int _generation = 0;
  Future<List<SearchDocument>>? _documentsFuture;

  Future<void> _warmUpDocuments() async {
    try {
      await _ensureDocuments();
    } catch (_) {
      // Warm-up failures should not block opening the search screen.
    }
  }

  Future<List<SearchDocument>> _ensureDocuments() {
    final cached = _documentsFuture;
    if (cached != null) {
      return cached;
    }

    final future = _repository.loadCorpus(
      courseId: _args.courseId,
      courseName: _args.courseName,
    );
    _documentsFuture = future;
    return future;
  }

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
    try {
      final documents = await _ensureDocuments();
      final results = _repository.searchDocuments(
        documents: documents,
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
    } catch (_) {
      _documentsFuture = null;
      if (generation != _generation) {
        return;
      }
      state = state.copyWith(
        query: query,
        results: const <SearchResult>[],
        isSearching: false,
        hasSearched: true,
      );
    }
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
