import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../courses/course_catalog_repository.dart';
import 'api_client_provider.dart';
import 'app_providers.dart';

final courseCatalogRepositoryProvider = Provider<CourseCatalogRepository>((
  ref,
) {
  ref.watch(dataSessionEpochProvider);
  return CourseCatalogRepository(
    database: ref.watch(databaseProvider),
    apiClient: ref.watch(learningReadApiProvider),
  );
});
