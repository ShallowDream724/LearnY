import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_state_keys.dart';
import '../../../core/database/database.dart';
import '../../../core/providers/providers.dart';

class ProfileIdentity {
  const ProfileIdentity({required this.department});

  final String department;

  bool get hasDepartment => department.trim().isNotEmpty;
}

final profileIdentityProvider = FutureProvider<ProfileIdentity?>((ref) async {
  final authState = ref.watch(authProvider);
  if (!authState.hasPersistedIdentity) {
    return null;
  }

  final database = ref.watch(databaseProvider);
  final cachedDepartment =
      (await database.getState(AppStateKeys.userDepartment))?.trim() ?? '';

  if (!authState.isLoggedIn) {
    return cachedDepartment.isEmpty
        ? null
        : ProfileIdentity(department: cachedDepartment);
  }

  try {
    final userInfo = await ref.watch(apiClientProvider).getUserInfo();
    final department = userInfo.department.trim();
    final resolvedDepartment = department.isNotEmpty
        ? department
        : cachedDepartment;

    if (department.isNotEmpty && department != cachedDepartment) {
      await database.setState(AppStateKeys.userDepartment, department);
    }

    return resolvedDepartment.isEmpty
        ? null
        : ProfileIdentity(department: resolvedDepartment);
  } catch (error, stackTrace) {
    debugPrint('Failed to load profile identity: $error\n$stackTrace');
    return cachedDepartment.isEmpty
        ? null
        : ProfileIdentity(department: cachedDepartment);
  }
});
