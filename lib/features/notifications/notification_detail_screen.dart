// Notification detail page — full content view with attachments.
//
// UX Design Decisions:
// - Full-screen page (pushed above shell) for focused reading
// - Auto-marks notification as read locally when opened
// - HTML content rendered natively, including authenticated inline images
// - Attachment card with file type icon, size, and download button
// - Top action: mark unread / read
// - Responsive: constrained width on tablets for readability
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_materials.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/app_surfaces.dart';
import '../../core/design/colors.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/files/file_models.dart';
import '../../core/files/widgets/file_attachment_card.dart';
import '../../core/html/authenticated_html_content.dart';
import '../../core/router/router.dart';
import '../../core/utils/notification_read_state.dart';
import 'providers/notification_actions.dart';
import 'providers/notification_providers.dart';

class NotificationDetailScreen extends ConsumerStatefulWidget {
  final String notificationId;
  final String courseId;
  final String courseName;

  const NotificationDetailScreen({
    super.key,
    required this.notificationId,
    required this.courseId,
    required this.courseName,
  });

  @override
  ConsumerState<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState
    extends ConsumerState<NotificationDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        await ref
            .read(notificationActionsProvider)
            .markRead(widget.notificationId);
      } catch (_) {
        if (mounted) AppToast.showError(context, message: '通知已打开，标记已读失败');
      }
    });
  }

  Future<void> _toggleReadState(db.Notification notification) async {
    final nextReadState = !notification.isEffectivelyRead;

    try {
      await ref
          .read(notificationActionsProvider)
          .setReadState(notificationId: notification.id, isRead: nextReadState);
      if (!mounted) {
        return;
      }
      AppToast.showSuccess(context, message: nextReadState ? '已标为已读' : '已标为未读');
    } catch (_) {
      if (mounted) {
        AppToast.showError(
          context,
          message: nextReadState ? '标记已读失败' : '标记未读失败',
        );
      }
    }
  }

  void _openAttachment(FileAttachmentEntry entry) {
    final routeData = entry.routeData;
    if (routeData == null) {
      AppToast.showWarning(context, message: '附件信息不可用');
      return;
    }

    context.push(Routes.fileDetailFromData(routeData));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final notificationAsync = ref.watch(
      notificationDetailProvider(widget.notificationId),
    );

    return Scaffold(
      backgroundColor: c.bg,
      body: notificationAsync.when(
        loading: () => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                widget.courseName,
                style: AppTypography.titleMedium.copyWith(color: c.subtitle),
              ),
            ),
            const SliverFillRemaining(child: ListSkeleton()),
          ],
        ),
        error: (error, _) => CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                widget.courseName,
                style: AppTypography.titleMedium.copyWith(color: c.subtitle),
              ),
            ),
            SliverFillRemaining(
              child: AppEmptyState(
                icon: Icons.error_outline_rounded,
                title: '通知加载失败',
                action: FilledButton.tonalIcon(
                  onPressed: () => ref.invalidate(
                    notificationDetailProvider(widget.notificationId),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('重试'),
                ),
              ),
            ),
          ],
        ),
        data: (notification) {
          if (notification == null) {
            return CustomScrollView(
              slivers: [
                SliverAppBar(pinned: true, title: Text(widget.courseName)),
                const SliverFillRemaining(
                  child: AppEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: '通知未找到',
                  ),
                ),
              ],
            );
          }

          final isRead = notification.isEffectivelyRead;
          final attachmentEntry = FileAttachmentEntry.fromJson(
            label: '查看附件',
            rawJson: notification.attachmentJson,
            courseId: widget.courseId,
            courseName: widget.courseName,
            fallbackKind: FileAttachmentKind.notification,
          );
          final hasContent = hasVisibleHtmlContent(notification.content);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                title: Text(
                  widget.courseName,
                  style: AppTypography.titleMedium.copyWith(color: c.subtitle),
                ),
                actions: [
                  IconButton(
                    icon: Icon(
                      isRead
                          ? Icons.mark_email_unread_rounded
                          : Icons.mark_email_read_outlined,
                      color: isRead ? c.infoAccent : c.subtitle,
                    ),
                    tooltip: isRead ? '标为未读' : '标为已读',
                    onPressed: () => _toggleReadState(notification),
                  ),
                ],
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  pageGutter(context, maxWidth: 800),
                  16,
                  pageGutter(context, maxWidth: 800),
                  40,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ReadingWidth(
                      maxWidth: 800,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(
                            builder: (context, constraints) => StudySurface(
                              tone: StudyPalette.course(
                                context,
                                widget.courseId,
                              ),
                              radius: 22,
                              padding: EdgeInsets.all(
                                constraints.maxWidth >= 600 ? 36 : 22,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (notification.markedImportant) ...[
                                    Text(
                                      '重要通知',
                                      style: AppTypography.labelMedium.copyWith(
                                        color: AppColors.warning,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  Text(
                                    notification.title,
                                    style: AppTypography.headlineMedium
                                        .copyWith(color: c.text, height: 1.5),
                                  ),
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 18,
                                    runSpacing: 6,
                                    children: [
                                      if (notification.publisher
                                          .trim()
                                          .isNotEmpty)
                                        Text(
                                          notification.publisher,
                                          style: AppTypography.bodyMedium
                                              .copyWith(color: c.subtitle),
                                        ),
                                      Text(
                                        _formatFullTime(
                                          notification.publishTime,
                                        ),
                                        style: AppTypography.bodyMedium
                                            .copyWith(color: c.subtitle),
                                      ),
                                    ],
                                  ),
                                  if (notification.expireTime != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '有效期至 ${_formatFullTime(notification.expireTime!)}',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: c.tertiary,
                                      ),
                                    ),
                                  ],
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 26,
                                    ),
                                    child: Divider(
                                      color: c.border,
                                      height: 1,
                                      thickness: .7,
                                    ),
                                  ),
                                  if (hasContent)
                                    _ContentBody(
                                      htmlContent: notification.content,
                                    )
                                  else
                                    Text(
                                      '暂无正文',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: c.tertiary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // ── Attachment ──
                          if (notification.attachmentJson != null &&
                              notification.attachmentJson!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              '附件',
                              style: AppTypography.labelMedium.copyWith(
                                color: c.subtitle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            FileAttachmentCard(
                              entry: attachmentEntry,
                              showSize: false,
                              onTap: () => _openAttachment(attachmentEntry),
                            ),
                          ],

                          // ── Comment ──
                          if (notification.comment != null &&
                              notification.comment!.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              '我的备注',
                              style: AppTypography.labelMedium.copyWith(
                                color: c.subtitle,
                              ),
                            ),
                            const SizedBox(height: 8),
                            StudySurface(
                              tone: StudyTone.ochre,
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                notification.comment!,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: c.text,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatFullTime(String time) {
    final ms = int.tryParse(time);
    if (ms == null) return time;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}/${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────
//  HTML Content Renderer
// ─────────────────────────────────────────────

/// Renders notification HTML content with authenticated inline image support.
class _ContentBody extends StatelessWidget {
  final String htmlContent;

  const _ContentBody({required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AuthenticatedHtmlContent(
      html: htmlContent,
      textStyle: AppTypography.bodyLarge.copyWith(color: c.text, height: 1.8),
    );
  }
}
