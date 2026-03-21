import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import 'search_models.dart';
import 'search_repository.dart';

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._ref, this._repository) : super(const SearchState()) {
    _loadRecentSearches();
  }

  final Ref _ref;
  final SearchRepository _repository;

  Timer? _debounce;
  int _searchGeneration = 0;

  Future<void> _loadRecentSearches() async {
    try {
      final recentSearches = await _repository.loadRecentSearches();
      state = state.copyWith(recentSearches: recentSearches);
    } catch (error, stackTrace) {
      debugPrint('Failed to load recent searches: $error\n$stackTrace');
    }
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
    _debounce = Timer(const Duration(milliseconds: 300), () {
      unawaited(_performSearch(query));
    });
  }

  Future<void> searchImmediately(String rawQuery) async {
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
    await _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    final generation = ++_searchGeneration;
    final semesterId = _ref.read(currentSemesterIdProvider);
    if (semesterId == null) {
      if (generation != _searchGeneration) {
        return;
      }
      state = state.copyWith(
        results: const <SearchResult>[],
        isSearching: false,
        hasSearched: true,
      );
      return;
    }

    try {
      final results = await _repository.search(
        semesterId: semesterId,
        query: query,
      );
      if (generation != _searchGeneration) {
        return;
      }

      state = state.copyWith(
        query: query,
        results: results,
        isSearching: false,
        hasSearched: true,
      );
      unawaited(_persistRecentSearch(query, generation));
    } catch (error, stackTrace) {
      debugPrint('Search failed for "$query": $error\n$stackTrace');
      if (generation != _searchGeneration) {
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

  Future<void> _persistRecentSearch(String query, int generation) async {
    try {
      final recentSearches = await _repository.addRecentSearch(query);
      if (generation != _searchGeneration) {
        return;
      }
      state = state.copyWith(recentSearches: recentSearches);
    } catch (error, stackTrace) {
      debugPrint(
        'Failed to persist recent search "$query": $error\n$stackTrace',
      );
    }
  }

  Future<void> clearRecentSearches() async {
    await _repository.clearRecentSearches();
    state = state.copyWith(recentSearches: const <String>[]);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>((ref) {
      return SearchController(ref, ref.watch(searchRepositoryProvider));
    });
