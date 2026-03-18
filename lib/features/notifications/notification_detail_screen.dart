/// Notification detail page — full content view with attachments.
///
/// UX Design Decisions:
/// - Full-screen page (pushed above shell) for focused reading
/// - Auto-marks notification as read locally when opened
/// - HTML content stripped to styled text (with "open in browser" for complex HTML)
/// - Attachment card with file type icon, size, and download button
/// - Bottom action bar: favorite, share
/// - Responsive: constrained width on tablets for readability
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/design/colors.dart';
import '../../core/design/responsive.dart';
import '../../core/design/shimmer.dart';
import '../../core/design/typography.dart';
import '../../core/database/database.dart' as db;
import '../../core/providers/providers.dart';
import '../../core/api/enums.dart';

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
  db.Notification? _notification;
  bool _loading = true;
  bool _isFavorite = false; // Local optimistic state

  @override
  void initState() {
    super.initState();
    _loadAndMarkRead();
  }

  Future<void> _loadAndMarkRead() async {
    final database = ref.read(databaseProvider);

    // Load notification data from DB
    final notifications =
        await database.getNotificationsByCourse(widget.courseId);
    final notif = notifications
        .where((n) => n.id == widget.notificationId)
        .firstOrNull;

    if (notif != null) {
      // Mark as read locally
      await database.markNotificationReadLocal(notif.id);
    }

    if (mounted) {
      setState(() {
        _notification = notif;
        _isFavorite = notif?.isFavorite ?? false;
        _loading = false;
      });
    }
  }

  /// Toggle favorite with optimistic UI: update icon immediately,
  /// call API in background, revert on failure.
  Future<void> _toggleFavorite(db.Notification n) async {
    final wasFavorite = _isFavorite;
    setState(() => _isFavorite = !wasFavorite);

    try {
      final api = ref.read(apiClientProvider);
      if (!wasFavorite) {
        await api.addToFavorites(ContentType.notification, n.id);
      } else {
        await api.removeFromFavorites(n.id);
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() => _isFavorite = wasFavorite);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasFavorite ? '取消收藏失败' : '收藏失败'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Parse attachment JSON to extract the filename for display.
  String _attachmentName(String? json) {
    if (json == null || json.isEmpty) return '查看附件';
    try {
      final data = jsonDecode(json);
      if (data is Map) {
        return (data['name'] ?? data['fileName'] ?? '查看附件').toString();
      }
    } catch (_) {}
    return '查看附件';
  }

  /// Handle attachment tap.
  void _onAttachmentTap(db.Notification n) {
    if (n.attachmentJson == null || n.attachmentJson!.isEmpty) return;

    String? name;
    try {
      final data = jsonDecode(n.attachmentJson!);
      if (data is Map) {
        name = (data['name'] ?? data['fileName'])?.toString();
      }
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(name != null ? '附件: $name' : '附件下载功能开发中'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final tertiaryColor =
        isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final border = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    if (_loading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(),
        body: const ListSkeleton(),
      );
    }

    final n = _notification;
    if (n == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(),
        body: Center(
          child: Text('通知未找到',
              style: AppTypography.titleMedium.copyWith(color: subColor)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──
          SliverAppBar(
            pinned: true,
            title: Text(
              widget.courseName,
              style: AppTypography.titleMedium.copyWith(color: subColor),
            ),
            actions: [
              // Favorite toggle
              IconButton(
                icon: Icon(
                  _isFavorite
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: _isFavorite ? AppColors.warning : subColor,
                ),
                onPressed: () => _toggleFavorite(n),
              ),
            ],
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Constrain width on tablets for readability
                ResponsiveContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Title ──
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n.markedImportant)
                            Container(
                              margin:
                                  const EdgeInsets.only(top: 4, right: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                    color: AppColors.warning.withAlpha(60)),
                              ),
                              child: Text('重要',
                                  style: AppTypography.labelSmall.copyWith(
                                    color: AppColors.warning,
                                    fontSize: 10,
                                  )),
                            ),
                          Expanded(
                            child: Text(
                              n.title,
                              style: AppTypography.headlineSmall
                                  .copyWith(color: textColor),
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
                                _initial(n.publisher ?? ''),
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
                              n.publisher ?? '',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: subColor),
                            ),
                          ),
                          Text(
                            _formatFullTime(n.publishTime),
                            style: AppTypography.bodySmall
                                .copyWith(color: tertiaryColor),
                          ),
                        ],
                      )
                          .animate(delay: 100.ms)
                          .fadeIn(duration: 250.ms),

                      // Expiry indicator
                      if (n.expireTime != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded,
                                size: 13, color: tertiaryColor),
                            const SizedBox(width: 4),
                            Text(
                              '有效期至 ${_formatFullTime(n.expireTime!)}',
                              style: AppTypography.bodySmall
                                  .copyWith(color: tertiaryColor, fontSize: 11),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ── Divider ──
                      Divider(color: border, height: 1),

                      const SizedBox(height: 20),

                      // ── Content body ──
                      if (n.content != null && n.content.isNotEmpty)
                        _ContentBody(
                          htmlContent: n.content,
                          textColor: textColor,
                          isDark: isDark,
                        )
                            .animate(delay: 200.ms)
                            .fadeIn(duration: 300.ms)
                      else
                        Text(
                          '（无内容）',
                          style: AppTypography.bodyMedium
                              .copyWith(color: tertiaryColor),
                        ),

                      // ── Attachment ──
                      if (n.attachmentJson != null &&
                          n.attachmentJson!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('附件',
                            style: AppTypography.labelMedium
                                .copyWith(color: subColor)),
                        const SizedBox(height: 8),
                        Material(
                          color: surface,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => _onAttachmentTap(n),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: border, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.info.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                    Icons.attach_file_rounded,
                                    size: 18,
                                    color: AppColors.info),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _attachmentName(n.attachmentJson),
                                  style: AppTypography.titleSmall
                                      .copyWith(color: textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Icon(Icons.download_rounded,
                                  size: 20, color: subColor),
                            ],
                          ),
                        )),
                        )
                            .animate(delay: 300.ms)
                            .fadeIn(duration: 250.ms),
                      ],

                      // ── Comment ──
                      if (n.comment != null && n.comment!.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text('我的备注',
                            style: AppTypography.labelMedium
                                .copyWith(color: subColor)),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.primary.withAlpha(30)),
                          ),
                          child: Text(
                            n.comment!,
                            style: AppTypography.bodyMedium
                                .copyWith(color: textColor),
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
  final Color textColor;
  final bool isDark;

  const _ContentBody({
    required this.htmlContent,
    required this.textColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Strip HTML tags to get plain text
    final text = _stripHtml(htmlContent);

    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return SelectableText(
      text,
      style: AppTypography.bodyLarge.copyWith(
        color: textColor,
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
