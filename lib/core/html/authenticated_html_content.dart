import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../api/urls.dart' as urls;
import '../api/utils.dart';
import '../auth/session_recovery_coordinator.dart';
import '../design/app_theme_colors.dart';
import '../design/colors.dart';
import '../design/typography.dart';
import '../providers/api_client_provider.dart';

class AuthenticatedHtmlContent extends StatelessWidget {
  const AuthenticatedHtmlContent({
    super.key,
    required this.html,
    this.baseUri,
    this.textStyle,
    this.emptyPlaceholder,
    this.blockSpacing = 12,
  });

  final String html;
  final Uri? baseUri;
  final TextStyle? textStyle;
  final Widget? emptyPlaceholder;
  final double blockSpacing;

  @override
  Widget build(BuildContext context) {
    final fragment = html_parser.parseFragment(html);
    final blocks = _buildBlockWidgets(
      context,
      fragment.nodes,
      baseUri ?? Uri.parse('${urls.learnPrefix}/'),
      textStyle ??
          AppTypography.bodyMedium.copyWith(
            color: context.colors.text,
            height: 1.7,
          ),
      blockSpacing,
    );

    if (blocks.isEmpty) {
      return emptyPlaceholder ?? const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks,
    );
  }
}

bool hasVisibleHtmlContent(String? html, {RegExp? placeholderOnly}) {
  if (html == null || html.trim().isEmpty) {
    return false;
  }
  final fragment = html_parser.parseFragment(html);
  if (fragment.querySelector('img') != null) {
    return true;
  }
  final text = stripHtmlToPlainText(html);
  if (text.isEmpty) {
    return false;
  }
  if (placeholderOnly != null && placeholderOnly.hasMatch(text)) {
    return false;
  }
  return true;
}

String stripHtmlToPlainText(String html) {
  final fragment = html_parser.parseFragment(html);
  final buffer = StringBuffer();

  void writeNode(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(decodeHTML(node.text).replaceAll('\u00A0', ' '));
      return;
    }
    if (node is! dom.Element) {
      return;
    }

    final tag = (node.localName ?? '').toLowerCase();
    switch (tag) {
      case 'br':
        buffer.write('\n');
        return;
      case 'p':
      case 'div':
      case 'section':
      case 'article':
      case 'blockquote':
        for (final child in node.nodes) {
          writeNode(child);
        }
        buffer.write('\n\n');
        return;
      case 'ul':
      case 'ol':
        for (final child in node.children.where((e) => e.localName == 'li')) {
          writeNode(child);
        }
        buffer.write('\n');
        return;
      case 'li':
        buffer.write('• ');
        for (final child in node.nodes) {
          writeNode(child);
        }
        buffer.write('\n');
        return;
      case 'img':
        return;
      default:
        for (final child in node.nodes) {
          writeNode(child);
        }
    }
  }

  for (final node in fragment.nodes) {
    writeNode(node);
  }

  var text = buffer.toString();
  text = text.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
  return text.trim();
}

List<Widget> _buildBlockWidgets(
  BuildContext context,
  List<dom.Node> nodes,
  Uri baseUri,
  TextStyle baseStyle,
  double spacing,
) {
  final widgets = <Widget>[];
  final inlineNodes = <dom.Node>[];

  void flushInline() {
    if (inlineNodes.isEmpty) {
      return;
    }
    final spans = _buildInlineSpans(context, inlineNodes, baseUri, baseStyle);
    inlineNodes.clear();
    if (!_hasVisibleSpanContent(spans)) {
      return;
    }
    widgets.add(
      SelectableText.rich(TextSpan(style: baseStyle, children: spans)),
    );
  }

  void addWithSpacing(List<Widget> children) {
    for (final child in children) {
      if (widgets.isNotEmpty) {
        widgets.add(SizedBox(height: spacing));
      }
      widgets.add(child);
    }
  }

  for (final node in nodes) {
    if (node is dom.Text) {
      inlineNodes.add(node);
      continue;
    }
    if (node is! dom.Element) {
      continue;
    }

    final tag = (node.localName ?? '').toLowerCase();
    switch (tag) {
      case 'img':
        flushInline();
        addWithSpacing([
          _AuthenticatedHtmlImage(
            uri: _resolveHtmlUri(node.attributes['src'], baseUri),
            alt: node.attributes['alt'],
          ),
        ]);
        break;
      case 'p':
      case 'div':
      case 'section':
      case 'article':
      case 'blockquote':
        flushInline();
        addWithSpacing(
          _buildBlockWidgets(
            context,
            node.nodes,
            baseUri,
            _styleForBlock(tag, baseStyle, context),
            spacing,
          ),
        );
        break;
      case 'ul':
      case 'ol':
        flushInline();
        addWithSpacing([
          _HtmlListBlock(
            items: node.children.where((e) => e.localName == 'li').toList(),
            ordered: tag == 'ol',
            baseUri: baseUri,
            textStyle: baseStyle,
          ),
        ]);
        break;
      case 'table':
        flushInline();
        final text = stripHtmlToPlainText(node.outerHtml);
        if (text.isNotEmpty) {
          addWithSpacing([SelectableText(text, style: baseStyle)]);
        }
        break;
      case 'br':
        inlineNodes.add(node);
        break;
      default:
        inlineNodes.add(node);
    }
  }

  flushInline();
  return widgets;
}

TextStyle _styleForBlock(
  String tag,
  TextStyle baseStyle,
  BuildContext context,
) {
  return switch (tag) {
    'blockquote' => baseStyle.copyWith(
      color: context.colors.subtitle,
      fontStyle: FontStyle.italic,
    ),
    _ => baseStyle,
  };
}

List<InlineSpan> _buildInlineSpans(
  BuildContext context,
  List<dom.Node> nodes,
  Uri baseUri,
  TextStyle currentStyle,
) {
  final spans = <InlineSpan>[];

  for (final node in nodes) {
    if (node is dom.Text) {
      final text = _normalizeInlineText(node.text);
      if (text.isNotEmpty) {
        spans.add(TextSpan(text: text, style: currentStyle));
      }
      continue;
    }
    if (node is! dom.Element) {
      continue;
    }

    final tag = (node.localName ?? '').toLowerCase();
    switch (tag) {
      case 'br':
        spans.add(const TextSpan(text: '\n'));
        break;
      case 'strong':
      case 'b':
        spans.addAll(
          _buildInlineSpans(
            context,
            node.nodes,
            baseUri,
            currentStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
        break;
      case 'em':
      case 'i':
        spans.addAll(
          _buildInlineSpans(
            context,
            node.nodes,
            baseUri,
            currentStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
        break;
      case 'u':
        spans.addAll(
          _buildInlineSpans(
            context,
            node.nodes,
            baseUri,
            currentStyle.copyWith(decoration: TextDecoration.underline),
          ),
        );
        break;
      case 'a':
        spans.addAll(
          _buildInlineSpans(
            context,
            node.nodes,
            baseUri,
            currentStyle.copyWith(
              color: AppColors.primary,
              decoration: TextDecoration.underline,
            ),
          ),
        );
        break;
      case 'img':
        break;
      default:
        spans.addAll(
          _buildInlineSpans(context, node.nodes, baseUri, currentStyle),
        );
    }
  }

  return spans;
}

bool _hasVisibleSpanContent(List<InlineSpan> spans) {
  final buffer = StringBuffer();

  void collect(InlineSpan span) {
    if (span is TextSpan) {
      buffer.write(span.text ?? '');
      final children = span.children;
      if (children != null) {
        for (final child in children) {
          collect(child);
        }
      }
    }
  }

  for (final span in spans) {
    collect(span);
  }
  return buffer.toString().trim().isNotEmpty;
}

String _normalizeInlineText(String input) {
  return decodeHTML(
    input,
  ).replaceAll('\u00A0', ' ').replaceAll(RegExp(r'[ \t\r\n]+'), ' ');
}

Uri? _resolveHtmlUri(String? raw, Uri baseUri) {
  if (raw == null || raw.trim().isEmpty) {
    return null;
  }
  return baseUri.resolve(raw.trim());
}

class _HtmlListBlock extends StatelessWidget {
  const _HtmlListBlock({
    required this.items,
    required this.ordered,
    required this.baseUri,
    required this.textStyle,
  });

  final List<dom.Element> items;
  final bool ordered;
  final Uri baseUri;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  ordered ? '${i + 1}.' : '•',
                  style: textStyle.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AuthenticatedHtmlContent(
                  html: items[i].innerHtml,
                  baseUri: baseUri,
                  textStyle: textStyle,
                  blockSpacing: 8,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AuthenticatedHtmlImage extends ConsumerStatefulWidget {
  const _AuthenticatedHtmlImage({required this.uri, this.alt});

  final Uri? uri;
  final String? alt;

  @override
  ConsumerState<_AuthenticatedHtmlImage> createState() =>
      _AuthenticatedHtmlImageState();
}

class _AuthenticatedHtmlImageState
    extends ConsumerState<_AuthenticatedHtmlImage> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Uint8List?> _load() async {
    final uri = widget.uri;
    if (uri == null) {
      return null;
    }

    if (uri.scheme == 'data') {
      return _decodeDataUri(uri);
    }

    final api = ref.read(apiClientProvider);
    final preparedUri = _appendCsrfIfNeeded(uri, api.getCSRFToken());

    Future<Response<List<int>>> request() {
      return api.dio.getUri<List<int>>(
        preparedUri,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
    }

    var response = await request();
    if (_looksLikeTimedOutHtml(response)) {
      final recovered = await ref
          .read(sessionRecoveryCoordinatorProvider)
          .recoverSession(apiClient: api);
      if (recovered.recovered) {
        response = await request();
      }
    }

    final bytes = response.data;
    if (response.statusCode != 200 || bytes == null || bytes.isEmpty) {
      throw StateError('image_fetch_failed');
    }
    return Uint8List.fromList(bytes);
  }

  Uint8List? _decodeDataUri(Uri uri) {
    final raw = uri.toString();
    final comma = raw.indexOf(',');
    if (comma == -1) {
      return null;
    }
    final metadata = raw.substring(0, comma);
    final payload = raw.substring(comma + 1);
    if (metadata.endsWith(';base64')) {
      return Uint8List.fromList(base64Decode(payload));
    }
    return Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
  }

  bool _looksLikeTimedOutHtml(Response<List<int>> response) {
    final contentType =
        response.headers.value(Headers.contentTypeHeader)?.toLowerCase() ?? '';
    if (!contentType.contains('text/html')) {
      return false;
    }
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      return false;
    }
    final preview = utf8.decode(bytes, allowMalformed: true);
    return _isIdentityLoginUri(response.realUri) ||
        _looksLikeIdentityLoginPage(preview);
  }

  Uri _appendCsrfIfNeeded(Uri uri, String csrfToken) {
    if (csrfToken.isEmpty) {
      return uri;
    }
    if (!uri.host.endsWith('tsinghua.edu.cn')) {
      return uri;
    }
    if (uri.queryParameters.containsKey('_csrf')) {
      return uri;
    }
    return Uri.parse(urls.addCSRFTokenToUrl(uri.toString(), csrfToken));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return FutureBuilder<Uint8List?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.border, width: 0.5),
            ),
            child: Row(
              children: [
                Icon(Icons.broken_image_outlined, size: 18, color: c.tertiary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.alt?.trim().isNotEmpty == true
                        ? '图片加载失败：${widget.alt!.trim()}'
                        : '图片加载失败',
                    style: AppTypography.bodySmall.copyWith(color: c.tertiary),
                  ),
                ),
              ],
            ),
          );
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final image = ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.memory(
                bytes,
                width: constraints.maxWidth,
                fit: BoxFit.fitWidth,
                gaplessPlayback: true,
              ),
            );

            return GestureDetector(
              onTap: () => _showFullscreenImage(context, bytes),
              child: image,
            );
          },
        );
      },
    );
  }

  void _showFullscreenImage(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(220),
      builder: (context) {
        return Dialog.fullscreen(
          backgroundColor: Colors.transparent,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.paddingOf(context).top + 12,
                right: 12,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

bool _isIdentityLoginUri(Uri? uri) {
  if (uri == null) {
    return false;
  }

  final identityHost = Uri.parse(urls.idPrefix).host;
  if (uri.host == identityHost) {
    return true;
  }

  final normalized = uri.toString();
  return normalized.contains('login_timeout') ||
      normalized.contains('/do/off/ui/auth/login/');
}

bool _looksLikeIdentityLoginPage(String pageSource) {
  if (pageSource.isEmpty) {
    return false;
  }

  final normalized = pageSource.toLowerCase();
  return normalized.contains('id="theform"') ||
      normalized.contains("id='theform'") ||
      normalized.contains('id="sm2publickey"') ||
      normalized.contains("id='sm2publickey'") ||
      normalized.contains('name="i_user"') ||
      normalized.contains("name='i_user'") ||
      normalized.contains('name="i_pass"') ||
      normalized.contains("name='i_pass'") ||
      normalized.contains('统一身份认证');
}
