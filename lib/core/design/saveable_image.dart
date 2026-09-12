import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import 'app_toast.dart';

/// Shared touch action for inline images, full-screen images and attachments.
class SaveableImage extends StatefulWidget {
  const SaveableImage({super.key, required this.onSave, required this.child});

  final Future<void> Function() onSave;
  final Widget child;

  @override
  State<SaveableImage> createState() => _SaveableImageState();
}

class _SaveableImageState extends State<SaveableImage> {
  bool _showingActions = false;
  bool _saving = false;

  Future<void> _showActions() async {
    if (_showingActions || _saving) return;
    _showingActions = true;
    final save = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SafeArea(
        top: false,
        child: ListTile(
          leading: const Icon(Icons.save_alt_rounded),
          title: const Text('保存到相册'),
          onTap: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    _showingActions = false;
    if (save != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.onSave();
      if (mounted) AppToast.showSuccess(context, message: '已保存到相册');
    } catch (error) {
      final message = switch (error) {
        GalException(type: GalExceptionType.accessDenied) =>
          '未获得保存权限，请在系统设置中允许后重试',
        GalException(type: GalExceptionType.notEnoughSpace) => '手机存储空间不足',
        GalException(type: GalExceptionType.notSupportedFormat) ||
        FormatException() => '相册暂不支持这种图片格式',
        _ => '图片保存失败，请重试',
      };
      if (mounted) AppToast.showError(context, message: message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (!mobile) return widget.child;
    return Semantics(
      onLongPress: _showActions,
      hint: '长按保存到相册',
      child: GestureDetector(
        onLongPress: _showActions,
        child: Stack(
          alignment: Alignment.center,
          children: [
            widget.child,
            if (_saving)
              const IgnorePointer(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
