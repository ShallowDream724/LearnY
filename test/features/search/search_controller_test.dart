import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/providers/providers.dart';
import 'package:learn_y/core/database/database.dart';
import 'package:learn_y/features/search/providers/search_controller.dart';
import 'package:learn_y/features/search/providers/search_engine.dart';
import 'package:learn_y/features/search/providers/search_models.dart';
import 'package:learn_y/features/search/providers/search_repository.dart';

void main() {
  test('clearing the query invalidates a pending search', () async {
    final fixture = SearchFixture();
    addTearDown(fixture.dispose);
    final pending = fixture.controller.searchImmediately('course');
    fixture.controller.onQueryChanged('');
    fixture.repository.oldCorpus.complete([document('old')]);
    await pending;
    final state = fixture.container.read(searchControllerProvider);
    expect(state.query, isEmpty);
    expect(state.results, isEmpty);
    expect(state.isSearching, isFalse);
  });

  test(
    'semester change reruns the query and rejects the older corpus',
    () async {
      final fixture = SearchFixture();
      addTearDown(fixture.dispose);
      final pending = fixture.controller.searchImmediately('course');
      fixture.container.read(currentSemesterIdProvider.notifier).state = 'new';
      await Future<void>.delayed(Duration.zero);
      fixture.repository.oldCorpus.complete([document('old')]);
      await pending;
      final state = fixture.container.read(searchControllerProvider);
      expect(state.results.single.id, 'new');
      expect(state.isSearching, isFalse);
    },
  );

  test(
    'a new query immediately invalidates results still loading during debounce',
    () async {
      final fixture = SearchFixture();
      addTearDown(fixture.dispose);
      final pending = fixture.controller.searchImmediately('course');
      fixture.controller.onQueryChanged('unmatched');
      fixture.repository.oldCorpus.complete([document('old')]);
      await pending;
      expect(
        fixture.container.read(searchControllerProvider).query,
        'unmatched',
      );
      expect(fixture.container.read(searchControllerProvider).results, isEmpty);
    },
  );

  test('disposing a pending search does not update a dead notifier', () async {
    final fixture = SearchFixture();
    final pending = fixture.controller.searchImmediately('course');
    fixture.container.dispose();
    fixture.repository.oldCorpus.complete([document('old')]);
    await pending;
    await fixture.db.close();
  });
}

class SearchFixture {
  SearchFixture() {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        initialCurrentSemesterIdProvider.overrideWithValue('old'),
        initialAuthUsernameProvider.overrideWithValue('test'),
        didBootstrapAppSessionProvider.overrideWithValue(true),
        searchRepositoryProvider.overrideWith(
          (ref) => repository = DelayedRepository(ref),
        ),
      ],
    );
    container.listen(searchControllerProvider, (_, _) {});
  }
  final db = AppDatabase(NativeDatabase.memory());
  late final ProviderContainer container;
  late DelayedRepository repository;
  SearchController get controller =>
      container.read(searchControllerProvider.notifier);
  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }
}

class DelayedRepository extends SearchRepository {
  DelayedRepository(super.ref);
  final oldCorpus = Completer<List<SearchDocument>>();
  @override
  Future<List<SearchDocument>> loadCorpus({required String semesterId}) =>
      semesterId == 'old' ? oldCorpus.future : Future.value([document('new')]);
  @override
  Future<List<String>> loadRecentSearches() async => [];
  @override
  Future<List<String>> addRecentSearch(String query) async => [query];
}

SearchDocument document(String id) => SearchDocument(
  result: SearchResult(
    key: id,
    kind: SearchResultKind.course,
    navigationType: SearchNavigationType.courseDetail,
    id: id,
    courseId: id,
    courseName: 'course',
    title: 'course',
    subtitle: '',
    section: buildExactSectionMeta(SearchResultKind.course),
  ),
  fields: const [SearchField('course', weight: 4, isPrimary: true)],
);
