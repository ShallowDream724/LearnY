import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_theme_colors.dart';
import 'colors.dart';
import 'typography.dart';

enum HomeworkReminderMenuAction { markNoSubmissionNeeded, restoreReminder }

const double _kHomeworkMenuMaxWidth = 272;
const double _kHomeworkMenuBaseHeight = 160;
const double _kHomeworkMenuMargin = 12;
const double _kHomeworkMenuGap = 10;

Future<HomeworkReminderMenuAction?> showHomeworkReminderMenu(
  BuildContext context, {
  required String title,
  required String courseName,
  required bool isNoSubmissionNeeded,
  Offset? anchor,
}) async {
  HapticFeedback.mediumImpact();

  return showGeneralDialog<HomeworkReminderMenuAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭作业菜单',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, _) {
      return _HomeworkReminderMenuOverlay(
        title: title,
        courseName: courseName,
        isNoSubmissionNeeded: isNoSubmissionNeeded,
        anchor: anchor,
      );
    },
    transitionBuilder: (context, animation, _, child) {
      final opacity = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(opacity: opacity, child: child);
    },
  );
}

class _HomeworkReminderMenuOverlay extends StatelessWidget {
  const _HomeworkReminderMenuOverlay({
    required this.title,
    required this.courseName,
    required this.isNoSubmissionNeeded,
    required this.anchor,
  });

  final String title;
  final String courseName;
  final bool isNoSubmissionNeeded;
  final Offset? anchor;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final resolvedAnchor =
        anchor ?? Offset(media.size.width / 2, media.size.height / 2);
    final estimatedHeight = _estimateMenuHeight(media.textScaler);
    final menuRect = _resolveMenuRect(
      size: media.size,
      padding: media.padding,
      anchor: resolvedAnchor,
      estimatedHeight: estimatedHeight,
    );
    final isDark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).maybePop(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(isDark ? 28 : 16),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: menuRect.left,
            top: menuRect.top,
            width: menuRect.width,
            child: _HomeworkReminderMenuCard(
              title: title,
              courseName: courseName,
              isNoSubmissionNeeded: isNoSubmissionNeeded,
              minHeight: estimatedHeight,
            ),
          ),
        ],
      ),
    );
  }

  Rect _resolveMenuRect({
    required Size size,
    required EdgeInsets padding,
    required Offset anchor,
    required double estimatedHeight,
  }) {
    final width = (size.width - (_kHomeworkMenuMargin * 2))
        .clamp(220.0, _kHomeworkMenuMaxWidth)
        .toDouble();
    final minLeft = _kHomeworkMenuMargin;
    final maxLeft = size.width - width - _kHomeworkMenuMargin;
    final left = (anchor.dx - (width / 2)).clamp(minLeft, maxLeft).toDouble();

    final minTop = padding.top + _kHomeworkMenuMargin;
    final maxTop =
        size.height - padding.bottom - estimatedHeight - _kHomeworkMenuMargin;
    final prefersBelow = anchor.dy < (size.height * 0.56);

    double top = prefersBelow
        ? anchor.dy + _kHomeworkMenuGap
        : anchor.dy - estimatedHeight - _kHomeworkMenuGap;

    if (top < minTop) {
      top = anchor.dy + _kHomeworkMenuGap;
    }
    if (top > maxTop) {
      top = anchor.dy - estimatedHeight - _kHomeworkMenuGap;
    }

    return Rect.fromLTWH(
      left,
      top.clamp(minTop, maxTop).toDouble(),
      width,
      estimatedHeight,
    );
  }

  double _estimateMenuHeight(TextScaler textScaler) {
    final scale = (textScaler.scale(14) / 14).clamp(1.0, 1.35);
    return (_kHomeworkMenuBaseHeight + ((scale - 1) * 24))
        .clamp(_kHomeworkMenuBaseHeight, 172)
        .toDouble();
  }
}

class _HomeworkReminderMenuCard extends StatelessWidget {
  const _HomeworkReminderMenuCard({
    required this.title,
    required this.courseName,
    required this.isNoSubmissionNeeded,
    required this.minHeight,
  });

  final String title;
  final String courseName;
  final bool isNoSubmissionNeeded;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = context.isDark;
    final action = isNoSubmissionNeeded
        ? HomeworkReminderMenuAction.restoreReminder
        : HomeworkReminderMenuAction.markNoSubmissionNeeded;
    final actionLabel = isNoSubmissionNeeded ? '恢复提醒' : '标记为无需提交';
    final actionHint = isNoSubmissionNeeded
        ? '重新显示在首页与作业提醒中'
        : '仅隐藏本地提醒，不影响网络学堂';
    final actionIcon = isNoSubmissionNeeded
        ? Icons.notifications_active_rounded
        : Icons.remove_circle_outline_rounded;
    final actionColor = isNoSubmissionNeeded
        ? AppColors.primary
        : const Color(0xFF8E8E93);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.94, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          alignment: Alignment.topCenter,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 18),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xE827272A)
                    : const Color(0xEAF6F6FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withAlpha(18)
                      : Colors.white.withAlpha(168),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(isDark ? 34 : 16),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 11),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleLarge.copyWith(
                            color: c.text,
                            height: 1.28,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          courseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySmall.copyWith(
                            color: c.tertiary,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 0.5, color: c.border.withAlpha(150)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.of(context).pop(action),
                        child: Ink(
                          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withAlpha(8)
                                : Colors.white.withAlpha(126),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withAlpha(12)
                                  : Colors.white.withAlpha(180),
                              width: 0.6,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: actionColor.withAlpha(
                                    isDark ? 42 : 20,
                                  ),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  actionIcon,
                                  size: 18,
                                  color: actionColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      actionLabel,
                                      style: AppTypography.titleMedium.copyWith(
                                        color: c.text,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      actionHint,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: c.tertiary,
                                        fontSize: 11.5,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                                color: c.tertiary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
