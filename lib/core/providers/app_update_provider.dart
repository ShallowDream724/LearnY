import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

const appRepositoryUrl = 'https://github.com/ShallowDream724/LearnY';
const _githubReleasesApi =
    'https://api.github.com/repos/ShallowDream724/LearnY/releases?per_page=5';
const _githubReleasesPage =
    'https://github.com/ShallowDream724/LearnY/releases';

enum AppUpdateAvailability { available, noRelease, unavailable }

class AppBuildInfo {
  const AppBuildInfo({
    required this.version,
    required this.buildNumber,
    required this.packageName,
  });

  final String version;
  final String buildNumber;
  final String packageName;

  String get shortLabel => 'v${_formatDisplayVersion(version)}';
  String get fullLabel =>
      buildNumber.isEmpty ? shortLabel : '$shortLabel ($buildNumber)';
}

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentBuild,
    required this.checkedAt,
    this.availability = AppUpdateAvailability.available,
    this.latestVersion,
    this.releaseUrl,
    this.releaseNotes,
    this.errorMessage,
  });

  final AppBuildInfo currentBuild;
  final DateTime checkedAt;
  final AppUpdateAvailability availability;
  final String? latestVersion;
  final String? releaseUrl;
  final String? releaseNotes;
  final String? errorMessage;

  bool get hasUpdate =>
      latestVersion != null &&
      _compareSemanticVersions(latestVersion!, currentBuild.version) > 0;

  bool get hasNoPublishedRelease =>
      availability == AppUpdateAvailability.noRelease;
  bool get isUnavailable => availability == AppUpdateAvailability.unavailable;

  String? get displayLatestVersion =>
      latestVersion == null ? null : _formatDisplayVersion(latestVersion!);

  String get statusLabel {
    if (hasUpdate && displayLatestVersion != null) {
      return '发现 $displayLatestVersion';
    }
    if (hasNoPublishedRelease) {
      return '暂无发布';
    }
    if (isUnavailable) {
      return 'GitHub 不可达';
    }
    return '当前 ${currentBuild.shortLabel}';
  }
}

final appBuildInfoProvider = FutureProvider<AppBuildInfo>((ref) async {
  final packageInfo = await PackageInfo.fromPlatform();
  return AppBuildInfo(
    version: packageInfo.version,
    buildNumber: packageInfo.buildNumber,
    packageName: packageInfo.packageName,
  );
});

final appUpdateInfoProvider = FutureProvider<AppUpdateInfo>((ref) async {
  final currentBuild = await ref.watch(appBuildInfoProvider.future);
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'LearnY',
      },
    ),
  );

  try {
    final response = await dio.get(_githubReleasesApi);
    final data = response.data;
    if (data is! List) {
      return AppUpdateInfo(
        currentBuild: currentBuild,
        checkedAt: DateTime.now(),
        availability: AppUpdateAvailability.unavailable,
        errorMessage: 'GitHub 响应异常',
      );
    }

    Map<String, dynamic>? release;
    for (final item in data) {
      if (item is! Map) {
        continue;
      }
      final normalized = item.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      if (normalized['draft'] == true) {
        continue;
      }
      release = normalized;
      break;
    }

    if (release == null) {
      return AppUpdateInfo(
        currentBuild: currentBuild,
        checkedAt: DateTime.now(),
        availability: AppUpdateAvailability.noRelease,
      );
    }

    final latestVersion = _normalizeReleaseVersion(
      release['tag_name']?.toString() ?? release['name']?.toString() ?? '',
    );
    final releaseNotes = release['body']?.toString().trim();

    return AppUpdateInfo(
      currentBuild: currentBuild,
      checkedAt: DateTime.now(),
      latestVersion: latestVersion.isEmpty ? null : latestVersion,
      releaseUrl: release['html_url']?.toString() ?? appRepositoryUrl,
      releaseNotes: releaseNotes == null || releaseNotes.isEmpty
          ? null
          : releaseNotes,
    );
  } catch (error, stackTrace) {
    debugPrint('Failed to check GitHub releases: $error\n$stackTrace');
    final fallbackInfo = await _tryResolveUpdateFromReleasesPage(
      dio,
      currentBuild,
    );
    if (fallbackInfo != null) {
      return fallbackInfo;
    }
    return AppUpdateInfo(
      currentBuild: currentBuild,
      checkedAt: DateTime.now(),
      availability: AppUpdateAvailability.unavailable,
      errorMessage: 'GitHub 不可达',
    );
  } finally {
    dio.close(force: true);
  }
});

Future<AppUpdateInfo?> _tryResolveUpdateFromReleasesPage(
  Dio dio,
  AppBuildInfo currentBuild,
) async {
  try {
    final response = await dio.get<String>(
      _githubReleasesPage,
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data ?? '';
    if (html.isEmpty) {
      return null;
    }

    if (html.contains('There aren’t any releases here') ||
        html.contains("There aren't any releases here")) {
      return AppUpdateInfo(
        currentBuild: currentBuild,
        checkedAt: DateTime.now(),
        availability: AppUpdateAvailability.noRelease,
      );
    }

    final tagMatch = RegExp(
      r'/ShallowDream724/LearnY/releases/tag/([^"?#]+)',
    ).firstMatch(html);
    if (tagMatch == null) {
      return AppUpdateInfo(
        currentBuild: currentBuild,
        checkedAt: DateTime.now(),
        availability: AppUpdateAvailability.noRelease,
      );
    }

    final rawTag = Uri.decodeComponent(tagMatch.group(1) ?? '');
    final latestVersion = _normalizeReleaseVersion(rawTag);
    return AppUpdateInfo(
      currentBuild: currentBuild,
      checkedAt: DateTime.now(),
      latestVersion: latestVersion.isEmpty ? null : latestVersion,
      releaseUrl: '$appRepositoryUrl/releases/tag/$rawTag',
    );
  } catch (error, stackTrace) {
    debugPrint(
      'Fallback GitHub release page check failed: $error\n$stackTrace',
    );
    return null;
  }
}

String _normalizeReleaseVersion(String raw) {
  var value = raw.trim();
  if (value.startsWith('v') || value.startsWith('V')) {
    value = value.substring(1);
  }
  return value;
}

String _formatDisplayVersion(String raw) {
  final normalized = _normalizeReleaseVersion(raw);
  return normalized
      .replaceFirst(RegExp(r'^(\d+\.\d+)\.0-'), r'$1-')
      .replaceAll('-beta', 'beta')
      .replaceAll('-alpha', 'alpha')
      .replaceAll('-rc', 'rc');
}

int _compareSemanticVersions(String left, String right) {
  final parsedLeft = _SemanticVersion.tryParse(left);
  final parsedRight = _SemanticVersion.tryParse(right);
  if (parsedLeft == null || parsedRight == null) {
    return left.compareTo(right);
  }
  return parsedLeft.compareTo(parsedRight);
}

class _SemanticVersion implements Comparable<_SemanticVersion> {
  const _SemanticVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.preRelease,
  });

  final int major;
  final int minor;
  final int patch;
  final List<String> preRelease;

  static _SemanticVersion? tryParse(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }

    final buildSplit = normalized.split('+');
    final preSplit = buildSplit.first.split('-');
    final core = preSplit.first.split('.');
    if (core.length < 3) {
      return null;
    }

    final major = int.tryParse(core[0]);
    final minor = int.tryParse(core[1]);
    final patch = int.tryParse(core[2]);
    if (major == null || minor == null || patch == null) {
      return null;
    }

    final preRelease = preSplit.length > 1
        ? preSplit.sublist(1).join('-').split('.')
        : const <String>[];

    return _SemanticVersion(
      major: major,
      minor: minor,
      patch: patch,
      preRelease: preRelease,
    );
  }

  @override
  int compareTo(_SemanticVersion other) {
    final majorDiff = major.compareTo(other.major);
    if (majorDiff != 0) return majorDiff;

    final minorDiff = minor.compareTo(other.minor);
    if (minorDiff != 0) return minorDiff;

    final patchDiff = patch.compareTo(other.patch);
    if (patchDiff != 0) return patchDiff;

    if (preRelease.isEmpty && other.preRelease.isEmpty) {
      return 0;
    }
    if (preRelease.isEmpty) {
      return 1;
    }
    if (other.preRelease.isEmpty) {
      return -1;
    }

    final maxLength = preRelease.length > other.preRelease.length
        ? preRelease.length
        : other.preRelease.length;
    for (var i = 0; i < maxLength; i++) {
      if (i >= preRelease.length) return -1;
      if (i >= other.preRelease.length) return 1;

      final left = preRelease[i];
      final right = other.preRelease[i];
      final leftInt = int.tryParse(left);
      final rightInt = int.tryParse(right);

      if (leftInt != null && rightInt != null) {
        final diff = leftInt.compareTo(rightInt);
        if (diff != 0) return diff;
        continue;
      }
      if (leftInt != null) return -1;
      if (rightInt != null) return 1;

      final diff = left.compareTo(right);
      if (diff != 0) return diff;
    }
    return 0;
  }
}
