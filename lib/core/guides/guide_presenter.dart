import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'guide_registry.dart';
import 'guide_state_store.dart';

class GuidePresenter {
  const GuidePresenter(this._store);

  final GuideStateStore _store;

  Future<bool> shouldShow(GuideDefinition guide) {
    return _store.shouldShow(guide);
  }

  Future<void> markPresented(GuideDefinition guide) {
    return _store.markPresented(guide);
  }

  Future<void> dismiss(GuideDefinition guide) {
    return _store.dismiss(guide);
  }
}

final guidePresenterProvider = Provider<GuidePresenter>((ref) {
  return GuidePresenter(ref.watch(guideStateStoreProvider));
});

final guideVisibilityProvider = FutureProvider.family<bool, String>((
  ref,
  guideId,
) async {
  final guide = GuideRegistry.byId(guideId);
  return ref.watch(guidePresenterProvider).shouldShow(guide);
});
