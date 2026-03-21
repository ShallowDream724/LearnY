import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/colors.dart';
import '../file_asset_runtime.dart';
import '../../services/file_download_service.dart';
import '../cached_asset_repository.dart';

class AssetStatusIcon extends ConsumerWidget {
  const AssetStatusIcon({
    super.key,
    required this.assetKey,
    required this.idleColor,
  });

  final String assetKey;
  final Color idleColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadStates = ref.watch(fileDownloadProvider);
    final cachedAsset = ref.watch(cachedAssetProvider(assetKey)).valueOrNull;
    final runtime = ref
        .read(fileAssetRuntimeResolverProvider)
        .resolveAttachment(
          assetKey: assetKey,
          cachedAsset: cachedAsset,
          trackedStates: downloadStates,
        );

    if (runtime.isDownloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: runtime.progress,
          color: AppColors.info,
        ),
      );
    }

    if (runtime.isDownloaded) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: AppColors.info.withAlpha(18),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 15, color: AppColors.info),
      );
    }

    if (runtime.hasFailure) {
      return const Icon(
        Icons.refresh_rounded,
        size: 20,
        color: AppColors.warning,
      );
    }

    return Icon(Icons.download_rounded, size: 20, color: idleColor);
  }
}
