import 'package:html/parser.dart' as html_parser;

final _entity = RegExp(r'&(?:[A-Za-z][A-Za-z0-9]+|#[0-9]+|#[xX][0-9a-fA-F]+);');

/// Decodes one layer of entities in a text field, preserving literal markup.
/// The HTML parser owns the HTML5 entity table and invalid code point handling.
String decodeHtmlEntities(String text) => text.replaceAllMapped(
  _entity,
  (match) =>
      html_parser.parseFragment(match[0]!).text!.replaceAll('\u00a0', ' '),
);
