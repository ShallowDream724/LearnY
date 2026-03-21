/// Notification detail page — full content view with attachments.
///
/// UX Design Decisions:
/// - Full-screen page (pushed above shell) for focused reading
/// - Auto-marks notification as read locally when opened
/// - HTML content stripped to styled text (with "open in browser" for complex HTML)
/// - Attachment card with file type icon, size, and download button
/// - Bottom action bar: favorite, share
/// - Responsive: constrained width on tablets for readability
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_toast.dart';
import '../../core/design/app_theme_colors.dart';
import '../../core/design/colors.dart';
import '../../core/design/responsive.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/files/file_models.dart';
import '../../core/files/widgets/file_attachment_card.dart';
import '../../core/router/router.dart';
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
  bool? _favoriteOverride;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(notificationActionsProvider).markRead(widget.notificationId);
    });
  }

  /// Toggle favorite with optimistic UI: update icon immediately,
  /// call API in background, revert on failure.
  Future<void> _toggleFavorite(
    db.Notification notification,
    bool isFavorite,
  ) async {
    final nextValue = !isFavorite;
    setState(() => _favoriteOverride = nextValue);

    try {
      await ref
          .read(notificationActionsProvider)
          .setFavorite(notificationId: notification.id, isFavorite: nextValue);
    } catch (e) {
      if (mounted) {
        setState(() => _favoriteOverride = isFavorite);
        AppToast.showError(context, message: isFavorite ? '取消收藏失败' : '收藏失败');
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
              child: Center(
                child: Text(
                  '加载失败',
                  style: AppTypography.titleMedium.copyWith(color: c.subtitle),
                ),
              ),
            ),
          ],
        ),
        data: (notification) {
          if (notification == null) {
            return Center(
              child: Text(
                '通知未找到',
                style: AppTypography.titleMedium.copyWith(color: c.subtitle),
              ),
            );
          }

          final isFavorite = _favoriteOverride ?? notification.isFavorite;
          final attachmentEntry = FileAttachmentEntry.fromJson(
            label: '查看附件',
            rawJson: notification.attachmentJson,
            courseId: widget.courseId,
            courseName: widget.courseName,
          );

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
                      isFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isFavorite ? AppColors.warning : c.subtitle,
                    ),
                    onPressed: () => _toggleFavorite(notification, isFavorite),
                  ),
                ],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    ResponsiveContent(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (notification.markedImportant)
                                    Container(
                                      margin: const EdgeInsets.only(
                                        top: 4,
                                        right: 8,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withAlpha(20),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: AppColors.warning.withAlpha(
                                            60,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '重要',
                                        style: AppTypography.labelSmall
                                            .copyWith(
                                              color: AppColors.warning,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      notification.title,
                                      style: AppTypography.headlineSmall
                                          .copyWith(color: c.text),
                                    ),
                                  ),
                                ],
                              )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .slideY(begin: 0.05, end: 0),

                          const SizedBox(height: 12),

                          // ── Metadata bar ──
                          Row(
                            children: [
                              // Publisher avatar
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    _initial(notification.publisher),
                                    style: AppTypography.labelSmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  notification.publisher,
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: c.subtitle,
                                  ),
                                ),
                              ),
                              Text(
                                _formatFullTime(notification.publishTime),
                                style: AppTypography.bodySmall.copyWith(
                                  color: c.tertiary,
                                ),
                              ),
                            ],
                          ).animate(delay: 100.ms).fadeIn(duration: 250.ms),

                          // Expiry indicator
                          if (notification.expireTime != null) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.schedule_rounded,
                                  size: 13,
                                  color: c.tertiary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '有效期至 ${_formatFullTime(notification.expireTime!)}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: c.tertiary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 20),

                          // ── Divider ──
                          Divider(color: c.border, height: 1),

                          const SizedBox(height: 20),

                          // ── Content body ──
                          if (notification.content.isNotEmpty)
                            _ContentBody(
                              htmlContent: notification.content,
                            ).animate(delay: 200.ms).fadeIn(duration: 300.ms)
                          else
                            Text(
                              '（无内容）',
                              style: AppTypography.bodyMedium.copyWith(
                                color: c.tertiary,
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
                            ).animate(delay: 300.ms).fadeIn(duration: 250.ms),
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primary.withAlpha(30),
                                ),
                              ),
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

  String _initial(String name) {
    if (name.isEmpty) return '';
    final chars = name.runes.toList();
    if (chars.isNotEmpty && chars[0] > 127) {
      return String.fromCharCode(chars[0]);
    }
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
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

/// Renders notification HTML content as styled text.
///
/// Why not use flutter_html or webview?
/// - flutter_html adds a heavy dependency
/// - webview is overkill for simple announcement text
/// - Most notification content is simple HTML (<p>, <br>, <b>, <a>)
///
/// We strip HTML tags and render as clean text with proper spacing.
/// Complex HTML (tables, images) falls back to "open in browser".
class _ContentBody extends StatelessWidget {
  final String htmlContent;

  const _ContentBody({required this.htmlContent});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Strip HTML tags to get plain text
    final text = _stripHtml(htmlContent);

    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectableText(
      text,
      style: AppTypography.bodyLarge.copyWith(
        color: c.text,
        height: 1.8,
        letterSpacing: 0.1,
      ),
    );
  }

  /// Strips HTML tags and converts common HTML entities to readable text.
  /// Preserves paragraph breaks.
  String _stripHtml(String html) {
    // Replace block elements with newlines
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</p>'), '\n\n')
        .replaceAll(RegExp(r'</div>'), '\n')
        .replaceAll(RegExp(r'</li>'), '\n')
        .replaceAll(RegExp(r'</tr>'), '\n')
        .replaceAll(RegExp(r'<li[^>]*>'), '  \u2022 '); // bullet for list items

    // Strip remaining tags
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode HTML entities
    text = text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&mdash;', '\u2014')
        .replaceAll('&ndash;', '\u2013')
        .replaceAll('&hellip;', '\u2026');

    // Clean up excessive whitespace
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }
}
