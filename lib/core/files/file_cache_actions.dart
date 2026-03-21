import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/preferences_providers.dart';
import '../services/file_cache_service.dart';

class FileCacheActions {
  const FileCacheActions(this._ref);

  final Ref _ref;

  Future<FileCacheSnapshot> loadSnapshot({bool applyPolicy = true}) {
    return _ref
        .read(fileCacheServiceProvider)
        .loadSnapshot(applyPolicy: applyPolicy);
  }

  Future<FileCacheSnapshot> updateLimit(int? limitMb) async {
    await _ref.read(fileCacheLimitMbProvider.notifier).setLimitMb(limitMb);
    return loadSnapshot(applyPolicy: true);
  }

  Future<void> clearAll() {
    return _ref.read(fileCacheServiceProvider).clearAllCache();
  }

  Future<void> clearAsset(String assetKey) {
    return _ref.read(fileCacheServiceProvider).clearFile(assetKey);
  }
}

final fileCacheActionsProvider = Provider<FileCacheActions>((ref) {
  return FileCacheActions(ref);
});
