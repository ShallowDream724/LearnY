import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

/// Decode once through the HTML parser. Comments (including Word's conditional
/// markup) are not submission text, while encoded literal markup stays text.
String stripHtmlToPlainText(String html) {
  final fragment = html_parser.parseFragment(html);
  final buffer = StringBuffer();
  void write(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.text.replaceAll('\u00a0', ' '));
      return;
    }
    if (node is! dom.Element) return;
    final tag = node.localName;
    if (const {'script', 'style', 'img'}.contains(tag)) return;
    if (tag == 'br') {
      buffer.write('\n');
      return;
    }
    if (tag == 'li') buffer.write('• ');
    for (final child in node.nodes) {
      write(child);
    }
    if (const {'p', 'div', 'section', 'article', 'blockquote'}.contains(tag)) {
      buffer.write('\n\n');
    } else if (const {'li', 'ul', 'ol'}.contains(tag)) {
      buffer.write('\n');
    }
  }

  for (final node in fragment.nodes) {
    write(node);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
      .trim();
}
