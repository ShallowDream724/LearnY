import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/files/file_asset_actions.dart';
import '../../../core/files/file_models.dart';
import '../../../core/design/app_toast.dart';
import '../../../core/design/read_action_feedback.dart';
import '../providers/file_bookmark_providers.dart';

enum FileActionMenuAction { share, openExternal, toggleFavorite, toggleRead }

Future<void> showFileActionMenu(
  BuildContext context, {
  required FileDetailItem item,
  required bool isFavorite,
  required bool isDownloading,
  Offset? anchor,
}) async {
  final overlay =
      Overlay.of(context, rootOverlay: true).context.findRenderObject()!
          as RenderBox;
  final position = anchor == null
      ? overlay.size.center(Offset.zero)
      : overlay.globalToLocal(anchor);
  final feedback = AppToast.capture(context);
  final readFeedback = ReadActionFeedback.of(context);
  final theme = Theme.of(context);
  final container = ProviderScope.containerOf(context, listen: false);
  final assetActions = container.read(fileAssetActionsProvider);
  final favoriteActions = container.read(fileFavoriteActionsProvider);

  final action = await showMenu<FileActionMenuAction>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 1, 1),
      Offset.zero & overlay.size,
    ),
    constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
    items: [
      PopupMenuItem<FileActionMenuAction>(
        enabled: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              if (item.courseName.isNotEmpty)
                Text(
                  item.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
      const PopupMenuDivider(),
      _menuItem(
        action: FileActionMenuAction.share,
        icon: Icons.ios_share_rounded,
        label: isDownloading ? '下载完成后可分享' : '分享',
        enabled: !isDownloading,
      ),
      _menuItem(
        action: FileActionMenuAction.openExternal,
        icon: Icons.open_in_new_rounded,
        label: isDownloading ? '下载完成后可打开' : '外部打开',
        enabled: !isDownloading,
      ),
      const PopupMenuDivider(),
      _menuItem(
        action: FileActionMenuAction.toggleFavorite,
        icon: isFavorite
            ? Icons.bookmark_remove_rounded
            : Icons.bookmark_add_outlined,
        label: isFavorite ? '取消收藏' : '收藏',
      ),
      if (item.supportsReadState && item.persistedFileId != null)
        _menuItem(
          action: FileActionMenuAction.toggleRead,
          icon: item.isNew
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread_outlined,
          label: item.isNew ? '标为已读' : '标为未读',
        ),
    ],
  );
  if (action == null || !context.mounted) return;

  try {
    switch (action) {
      case FileActionMenuAction.share:
        await assetActions.share(item);
        break;
      case FileActionMenuAction.openExternal:
        final opened = await assetActions.ensureAvailableAndOpen(item);
        if (!opened) {
          feedback.show(message: '无法打开文件', tone: AppToastTone.error);
        }
        break;
      case FileActionMenuAction.toggleFavorite:
        await favoriteActions.setFavorite(item: item, isFavorite: !isFavorite);
        feedback.show(
          message: isFavorite ? '已取消收藏' : '已加入收藏',
          tone: AppToastTone.success,
        );
        break;
      case FileActionMenuAction.toggleRead:
        await assetActions.setReadState(item, isRead: item.isNew);
        if (readFeedback != null) {
          readFeedback.record(
            id: 'file-${item.persistedFileId}',
            wasRead: !item.isNew,
            undo: () => assetActions.setReadState(item, isRead: !item.isNew),
          );
        } else {
          feedback.show(
            message: item.isNew ? '已标为已读' : '已标为未读',
            tone: AppToastTone.success,
          );
        }
        break;
    }
  } on FileAssetActionException catch (error) {
    feedback.show(message: error.message, tone: AppToastTone.error);
  } catch (_) {
    final message = switch (action) {
      FileActionMenuAction.share => '分享失败',
      FileActionMenuAction.openExternal => '无法打开文件',
      FileActionMenuAction.toggleFavorite => '收藏状态更新失败',
      FileActionMenuAction.toggleRead => '文件已读状态更新失败',
    };
    feedback.show(message: message, tone: AppToastTone.error);
  }
}

PopupMenuItem<FileActionMenuAction> _menuItem({
  required FileActionMenuAction action,
  required IconData icon,
  required String label,
  bool enabled = true,
}) {
  return PopupMenuItem<FileActionMenuAction>(
    value: action,
    enabled: enabled,
    child: Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    ),
  );
}
