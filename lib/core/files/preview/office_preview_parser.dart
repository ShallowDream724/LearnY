import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../file_preview_registry.dart';
import 'file_preview_models.dart';

class OfficePreviewParser {
  const OfficePreviewParser();

  Future<HtmlPreparedFilePreview> parseDocx({
    required FilePreviewDescriptor descriptor,
    required String localPath,
  }) async {
    final archive = await _decodeArchive(localPath);
    final xmlString = _readUtf8File(archive, 'word/document.xml');
    if (xmlString == null || xmlString.isEmpty) {
      throw const FormatException('DOCX 文档内容缺失');
    }

    final document = XmlDocument.parse(xmlString);
    final body = _firstDescendant(document.rootElement, 'body');
    if (body == null) {
      throw const FormatException('DOCX 文档结构无效');
    }

    final buffer = StringBuffer();
    for (final child in body.childElements) {
      switch (child.name.local) {
        case 'p':
          final html = _renderDocxParagraph(child);
          if (html.isNotEmpty) {
            buffer.writeln(html);
          }
          break;
        case 'tbl':
          final html = _renderDocxTable(child);
          if (html.isNotEmpty) {
            buffer.writeln(html);
          }
          break;
      }
    }

    final htmlBody = buffer.toString().trim();
    if (htmlBody.isEmpty) {
      throw const FormatException('DOCX 文档没有可显示内容');
    }

    return HtmlPreparedFilePreview(
      descriptor: descriptor,
      kind: HtmlPreparedFilePreviewKind.document,
      htmlBody: htmlBody,
    );
  }

  Future<HtmlPreparedFilePreview> parseXlsx({
    required FilePreviewDescriptor descriptor,
    required String localPath,
  }) async {
    final archive = await _decodeArchive(localPath);
    final workbookXml = _readUtf8File(archive, 'xl/workbook.xml');
    if (workbookXml == null || workbookXml.isEmpty) {
      throw const FormatException('XLSX 工作簿内容缺失');
    }

    final workbook = XmlDocument.parse(workbookXml);
    final workbookRels = _readRelationships(
      archive,
      relsPath: 'xl/_rels/workbook.xml.rels',
      baseDir: 'xl',
    );
    final sharedStrings = _readSharedStrings(archive);
    final sheets = _descendantsNamed(workbook.rootElement, 'sheet').toList();
    if (sheets.isEmpty) {
      throw const FormatException('XLSX 工作簿中没有工作表');
    }

    const maxRows = 200;
    const maxColumns = 30;
    final sections = <String>[];
    var wasTruncated = false;

    for (var sheetIndex = 0; sheetIndex < sheets.length; sheetIndex += 1) {
      final sheet = sheets[sheetIndex];
      final relId = _attributeValue(sheet, 'id');
      final name = _attributeValue(sheet, 'name') ?? 'Sheet ${sheetIndex + 1}';
      final sheetPath = relId != null
          ? workbookRels[relId]
          : 'xl/worksheets/sheet${sheetIndex + 1}.xml';
      if (sheetPath == null) {
        continue;
      }

      final sheetXml = _readUtf8File(archive, sheetPath);
      if (sheetXml == null || sheetXml.isEmpty) {
        continue;
      }

      final sheetDocument = XmlDocument.parse(sheetXml);
      final rows = <int, Map<int, String>>{};
      var maxColumnIndex = -1;
      var rowCount = 0;

      for (final row in _descendantsNamed(sheetDocument.rootElement, 'row')) {
        rowCount += 1;
        if (rowCount > maxRows) {
          wasTruncated = true;
          break;
        }

        final rowIndex =
            int.tryParse(_attributeValue(row, 'r') ?? '') ?? rowCount;
        final cellMap = <int, String>{};

        for (final cell in row.childElements.where(
          (c) => c.name.local == 'c',
        )) {
          final ref = _attributeValue(cell, 'r') ?? '';
          final columnIndex = ref.isEmpty
              ? cellMap.length
              : _columnIndexFromCellReference(ref);
          if (columnIndex >= maxColumns) {
            wasTruncated = true;
            continue;
          }

          final value = _readSpreadsheetCellValue(cell, sharedStrings);
          if (value.isEmpty) {
            continue;
          }
          cellMap[columnIndex] = value;
          maxColumnIndex = math.max(maxColumnIndex, columnIndex);
        }

        if (cellMap.isNotEmpty) {
          rows[rowIndex] = cellMap;
        }
      }

      if (rows.isEmpty) {
        continue;
      }

      final visibleColumnCount = math.min(maxColumnIndex + 1, maxColumns);
      final sortedRowIndices = rows.keys.toList()..sort();
      final buffer = StringBuffer();
      buffer.writeln('<section class="sheet">');
      buffer.writeln('<h2>${_escapeHtml(name)}</h2>');
      buffer.writeln('<div class="table-wrap"><table>');
      buffer.writeln('<thead><tr><th class="corner"></th>');
      for (var column = 0; column < visibleColumnCount; column += 1) {
        buffer.write('<th>${_spreadsheetColumnLabel(column)}</th>');
      }
      buffer.writeln('</tr></thead><tbody>');

      for (final rowIndex in sortedRowIndices) {
        buffer.write('<tr><th class="row-index">$rowIndex</th>');
        final cells = rows[rowIndex]!;
        for (var column = 0; column < visibleColumnCount; column += 1) {
          final value = cells[column] ?? '';
          buffer.write('<td>${_escapeHtml(value)}</td>');
        }
        buffer.writeln('</tr>');
      }

      buffer.writeln('</tbody></table></div></section>');
      sections.add(buffer.toString());
    }

    if (sections.isEmpty) {
      throw const FormatException('XLSX 文件没有可显示数据');
    }

    return HtmlPreparedFilePreview(
      descriptor: descriptor,
      kind: HtmlPreparedFilePreviewKind.spreadsheet,
      htmlBody: sections.join('\n'),
      note: wasTruncated ? '已为移动端预览限制显示范围。' : null,
    );
  }

  Future<PresentationPreparedFilePreview> parsePptx({
    required FilePreviewDescriptor descriptor,
    required String localPath,
  }) async {
    final archive = await _decodeArchive(localPath);
    final presentationXml = _readUtf8File(archive, 'ppt/presentation.xml');
    final presentationDocument =
        presentationXml == null || presentationXml.isEmpty
        ? null
        : XmlDocument.parse(presentationXml);
    final presentationRels = _readRelationships(
      archive,
      relsPath: 'ppt/_rels/presentation.xml.rels',
      baseDir: 'ppt',
    );
    final slideSize =
        _readPresentationSlideSize(presentationDocument) ??
        const _PresentationSize(width: 9144000, height: 5143500);
    final slidePaths = _resolvePresentationSlidePaths(
      archive,
      presentationDocument,
      presentationRels,
    );
    if (slidePaths.isEmpty) {
      throw const FormatException('PPTX 演示文稿中没有幻灯片');
    }

    final slides = <PresentationPreviewSlide>[];
    for (var index = 0; index < slidePaths.length; index += 1) {
      final slidePath = slidePaths[index];
      final slideXml = _readUtf8File(archive, slidePath);
      if (slideXml == null || slideXml.isEmpty) {
        continue;
      }
      final slideDocument = XmlDocument.parse(slideXml);
      final slideRels = _readRelationships(
        archive,
        relsPath:
            '${p.posix.dirname(slidePath)}/_rels/${p.posix.basename(slidePath)}.rels',
        baseDir: p.posix.dirname(slidePath),
      );
      slides.add(
        _parsePresentationSlide(
          archive,
          slideDocument,
          relationships: slideRels,
          slideIndex: index + 1,
          slideSize: slideSize,
        ),
      );
    }

    if (slides.isEmpty) {
      throw const FormatException('PPTX 演示文稿中没有可显示内容');
    }

    return PresentationPreparedFilePreview(
      descriptor: descriptor,
      document: PresentationPreviewDocument(
        slideWidth: slideSize.width,
        slideHeight: slideSize.height,
        slides: slides,
      ),
    );
  }

  String _renderDocxParagraph(XmlElement paragraph) {
    final text = _collectDocxText(paragraph).trim();
    if (text.isEmpty) {
      return '';
    }

    final style = _resolveDocxParagraphStyle(paragraph);
    final escaped = _escapeHtml(text).replaceAll('\n', '<br />');
    if (style.startsWith('h')) {
      return '<$style>$escaped</$style>';
    }
    if (style == 'li') {
      return '<p class="doc-list-item">$escaped</p>';
    }
    return '<p>$escaped</p>';
  }

  String _renderDocxTable(XmlElement table) {
    final rows = table.childElements
        .where((row) => row.name.local == 'tr')
        .toList();
    if (rows.isEmpty) {
      return '';
    }

    final buffer = StringBuffer('<div class="table-wrap"><table><tbody>');
    for (final row in rows) {
      buffer.write('<tr>');
      for (final cell in row.childElements.where((c) => c.name.local == 'tc')) {
        final paragraphs = cell.childElements
            .where((child) => child.name.local == 'p')
            .map(_collectDocxText)
            .map((text) => text.trim())
            .where((text) => text.isNotEmpty)
            .toList();
        final cellHtml = paragraphs.isEmpty
            ? '&nbsp;'
            : paragraphs
                  .map((text) => _escapeHtml(text).replaceAll('\n', '<br />'))
                  .join('<br />');
        buffer.write('<td>$cellHtml</td>');
      }
      buffer.write('</tr>');
    }
    buffer.write('</tbody></table></div>');
    return buffer.toString();
  }

  String _collectDocxText(XmlElement root) {
    final buffer = StringBuffer();
    for (final element in root.descendants.whereType<XmlElement>()) {
      switch (element.name.local) {
        case 't':
          buffer.write(element.innerText);
          break;
        case 'tab':
          buffer.write('    ');
          break;
        case 'br':
        case 'cr':
          buffer.write('\n');
          break;
      }
    }
    return buffer.toString();
  }

  String _resolveDocxParagraphStyle(XmlElement paragraph) {
    final styleElement = _firstDescendant(paragraph, 'pStyle');
    final rawStyle = (_attributeValue(styleElement, 'val') ?? '').toLowerCase();
    if (rawStyle.contains('heading1') || rawStyle == 'title') {
      return 'h1';
    }
    if (rawStyle.contains('heading2') || rawStyle.contains('subtitle')) {
      return 'h2';
    }
    if (rawStyle.contains('heading3')) {
      return 'h3';
    }
    if (_firstDescendant(paragraph, 'numPr') != null) {
      return 'li';
    }
    return 'p';
  }

  List<String> _readSharedStrings(Archive archive) {
    final sharedStringsXml = _readUtf8File(archive, 'xl/sharedStrings.xml');
    if (sharedStringsXml == null || sharedStringsXml.isEmpty) {
      return const [];
    }

    final document = XmlDocument.parse(sharedStringsXml);
    return _descendantsNamed(
      document.rootElement,
      'si',
    ).map((item) => _collectSpreadsheetText(item).trim()).toList();
  }

  String _readSpreadsheetCellValue(
    XmlElement cell,
    List<String> sharedStrings,
  ) {
    final type = _attributeValue(cell, 't') ?? '';
    if (type == 'inlineStr') {
      final inline = _firstDescendant(cell, 'is');
      return inline == null ? '' : _collectSpreadsheetText(inline);
    }

    final valueElement = _firstDescendant(cell, 'v');
    final rawValue = valueElement?.innerText.trim() ?? '';
    if (rawValue.isEmpty) {
      return '';
    }

    switch (type) {
      case 's':
        final index = int.tryParse(rawValue);
        if (index == null || index < 0 || index >= sharedStrings.length) {
          return rawValue;
        }
        return sharedStrings[index];
      case 'b':
        return rawValue == '1' ? 'TRUE' : 'FALSE';
      default:
        return rawValue;
    }
  }

  String _collectSpreadsheetText(XmlElement root) {
    final buffer = StringBuffer();
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (element.name.local == 't') {
        buffer.write(element.innerText);
      }
    }
    return buffer.toString();
  }

  PresentationPreviewSlide _parsePresentationSlide(
    Archive archive,
    XmlDocument document, {
    required Map<String, String> relationships,
    required int slideIndex,
    required _PresentationSize slideSize,
  }) {
    final elements = <PresentationPreviewElement>[];
    final shapeTree = _firstDescendant(document.rootElement, 'spTree');
    if (shapeTree != null) {
      final fallbackCounter = _PresentationFallbackCounter();
      for (final child in shapeTree.childElements) {
        _collectPresentationElements(
          archive,
          child,
          elements: elements,
          relationships: relationships,
          slideSize: slideSize,
          transform: _TransformContext.identity(),
          fallbackCounter: fallbackCounter,
        );
      }
    }

    return PresentationPreviewSlide(
      index: slideIndex,
      label: _resolvePresentationSlideLabel(elements, slideIndex),
      backgroundColorArgb: 0xFFFFFFFF,
      defaultTextColorArgb: 0xFF111827,
      elements: elements,
    );
  }

  void _collectPresentationElements(
    Archive archive,
    XmlElement node, {
    required List<PresentationPreviewElement> elements,
    required Map<String, String> relationships,
    required _PresentationSize slideSize,
    required _TransformContext transform,
    required _PresentationFallbackCounter fallbackCounter,
  }) {
    switch (node.name.local) {
      case 'sp':
        final textElement = _parsePresentationTextElement(
          node,
          slideSize: slideSize,
          transform: transform,
          fallbackCounter: fallbackCounter,
        );
        if (textElement != null) {
          elements.add(textElement);
        }
        return;
      case 'pic':
        final imageElement = _parsePresentationImageElement(
          archive,
          node,
          relationships: relationships,
          transform: transform,
        );
        if (imageElement != null) {
          elements.add(imageElement);
        }
        return;
      case 'graphicFrame':
        final tableElement = _parsePresentationTableElement(
          node,
          transform: transform,
        );
        if (tableElement != null) {
          elements.add(tableElement);
        }
        return;
      case 'grpSp':
        final groupTransform = _resolveGroupTransform(node, transform);
        for (final child in node.childElements) {
          _collectPresentationElements(
            archive,
            child,
            elements: elements,
            relationships: relationships,
            slideSize: slideSize,
            transform: groupTransform,
            fallbackCounter: fallbackCounter,
          );
        }
        return;
      default:
        return;
    }
  }

  PresentationTextElement? _parsePresentationTextElement(
    XmlElement shape, {
    required _PresentationSize slideSize,
    required _TransformContext transform,
    required _PresentationFallbackCounter fallbackCounter,
  }) {
    final paragraphs = _extractPresentationParagraphs(shape);
    if (paragraphs.isEmpty) {
      return null;
    }
    final role = _resolvePresentationTextRole(shape, paragraphs: paragraphs);
    final geometry = _resolvePresentationGeometry(
      node: shape,
      slideSize: slideSize,
      transform: transform,
      role: role,
      fallbackIndex: fallbackCounter.next(role),
      allowFallback: true,
    );
    if (geometry == null) {
      return null;
    }

    return PresentationTextElement(
      x: geometry.x,
      y: geometry.y,
      width: geometry.width,
      height: geometry.height,
      role: role,
      paragraphs: paragraphs,
      fillColorArgb: _resolveDirectFillColor(shape),
      borderColorArgb: _resolveDirectBorderColor(shape),
    );
  }

  PresentationImageElement? _parsePresentationImageElement(
    Archive archive,
    XmlElement picture, {
    required Map<String, String> relationships,
    required _TransformContext transform,
  }) {
    final geometry = _resolvePresentationGeometry(
      node: picture,
      slideSize: const _PresentationSize(width: 1, height: 1),
      transform: transform,
      role: PresentationTextRole.body,
      fallbackIndex: 0,
      allowFallback: false,
    );
    if (geometry == null) {
      return null;
    }

    final blip = _firstDescendant(picture, 'blip');
    final relationId = _attributeValue(blip, 'embed');
    if (relationId == null || relationId.isEmpty) {
      return null;
    }
    final target = relationships[relationId];
    if (target == null) {
      return null;
    }
    final bytes = _readBinaryFile(archive, target);
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    return PresentationImageElement(
      x: geometry.x,
      y: geometry.y,
      width: geometry.width,
      height: geometry.height,
      bytes: bytes,
      mimeType: mime.lookupMimeType(target) ?? 'application/octet-stream',
      borderColorArgb: _resolveDirectBorderColor(picture),
    );
  }

  PresentationTableElement? _parsePresentationTableElement(
    XmlElement graphicFrame, {
    required _TransformContext transform,
  }) {
    final table = _firstDescendant(graphicFrame, 'tbl');
    if (table == null) {
      return null;
    }
    final geometry = _resolvePresentationGeometry(
      node: graphicFrame,
      slideSize: const _PresentationSize(width: 1, height: 1),
      transform: transform,
      role: PresentationTextRole.body,
      fallbackIndex: 0,
      allowFallback: false,
    );
    if (geometry == null) {
      return null;
    }

    final rows = <PresentationTableRow>[];
    for (final row in table.childElements.where((e) => e.name.local == 'tr')) {
      final cells = <String>[];
      for (final cell in row.childElements.where((e) => e.name.local == 'tc')) {
        final parts = <String>[];
        for (final paragraph in cell.descendants.whereType<XmlElement>()) {
          if (paragraph.name.local != 'p') {
            continue;
          }
          final text = _collectPresentationParagraphText(paragraph).trim();
          if (text.isNotEmpty) {
            parts.add(text);
          }
        }
        cells.add(parts.isEmpty ? '' : parts.join('\n'));
      }
      if (cells.isNotEmpty) {
        rows.add(PresentationTableRow(cells: cells));
      }
    }
    if (rows.isEmpty) {
      return null;
    }

    return PresentationTableElement(
      x: geometry.x,
      y: geometry.y,
      width: geometry.width,
      height: geometry.height,
      rows: rows,
      fillColorArgb: _resolveDirectFillColor(graphicFrame),
      borderColorArgb: _resolveDirectBorderColor(graphicFrame) ?? 0xFFCBD5E1,
    );
  }

  List<PresentationTextParagraph> _extractPresentationParagraphs(
    XmlElement shape,
  ) {
    final textBody = _firstDescendant(shape, 'txBody');
    if (textBody == null) {
      return const [];
    }

    final rawParagraphs = textBody.childElements
        .where((element) => element.name.local == 'p')
        .map(
          (paragraph) =>
              (paragraph, _collectPresentationParagraphText(paragraph)),
        )
        .where((entry) => entry.$2.trim().isNotEmpty)
        .toList();
    if (rawParagraphs.isEmpty) {
      return const [];
    }

    final roleHint = _resolvePresentationTextRole(shape, paragraphs: const []);
    return [
      for (var index = 0; index < rawParagraphs.length; index += 1)
        _buildPresentationParagraph(
          rawParagraphs[index].$1,
          rawParagraphs[index].$2.trim(),
          roleHint: roleHint,
          totalCount: rawParagraphs.length,
        ),
    ];
  }

  PresentationTextParagraph _buildPresentationParagraph(
    XmlElement paragraph,
    String text, {
    required PresentationTextRole roleHint,
    required int totalCount,
  }) {
    final paragraphProps = _directChildNamed(paragraph, 'pPr');
    final level =
        int.tryParse(_attributeValue(paragraphProps, 'lvl') ?? '') ?? 0;
    return PresentationTextParagraph(
      text: text,
      align: _resolvePresentationTextAlign(paragraphProps),
      level: level,
      bullet: _presentationParagraphHasBullet(
        paragraph,
        roleHint: roleHint,
        totalParagraphCount: totalCount,
      ),
      fontSizePt: _resolvePresentationFontSizePt(paragraph, roleHint),
      colorArgb: _resolveDirectParagraphColor(paragraph) ?? 0xFF111827,
      bold: _resolvePresentationParagraphBold(paragraph, roleHint),
    );
  }

  String _collectPresentationParagraphText(XmlElement paragraph) {
    final buffer = StringBuffer();
    for (final element in paragraph.descendants.whereType<XmlElement>()) {
      switch (element.name.local) {
        case 't':
          buffer.write(element.innerText);
          break;
        case 'br':
          buffer.write('\n');
          break;
      }
    }
    return buffer.toString();
  }

  bool _presentationParagraphHasBullet(
    XmlElement paragraph, {
    required PresentationTextRole roleHint,
    required int totalParagraphCount,
  }) {
    if (roleHint == PresentationTextRole.title ||
        roleHint == PresentationTextRole.subtitle) {
      return false;
    }
    if (_firstDescendant(paragraph, 'buNone') != null) {
      return false;
    }
    if (_firstDescendant(paragraph, 'buChar') != null ||
        _firstDescendant(paragraph, 'buAutoNum') != null) {
      return true;
    }
    final level =
        int.tryParse(
          _attributeValue(_directChildNamed(paragraph, 'pPr'), 'lvl') ?? '',
        ) ??
        0;
    return level > 0 || totalParagraphCount > 1;
  }

  double _resolvePresentationFontSizePt(
    XmlElement paragraph,
    PresentationTextRole roleHint,
  ) {
    final sizes = paragraph.descendants
        .whereType<XmlElement>()
        .where(
          (element) =>
              element.name.local == 'rPr' ||
              element.name.local == 'defRPr' ||
              element.name.local == 'endParaRPr',
        )
        .map((element) => double.tryParse(_attributeValue(element, 'sz') ?? ''))
        .whereType<double>()
        .map((value) => value / 100.0)
        .toList();
    if (sizes.isNotEmpty) {
      return sizes.reduce(math.max);
    }

    return switch (roleHint) {
      PresentationTextRole.title => 28,
      PresentationTextRole.subtitle => 20,
      PresentationTextRole.caption => 13,
      PresentationTextRole.body => 18,
    };
  }

  bool _resolvePresentationParagraphBold(
    XmlElement paragraph,
    PresentationTextRole roleHint,
  ) {
    for (final element in paragraph.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'rPr' &&
          element.name.local != 'defRPr' &&
          element.name.local != 'endParaRPr') {
        continue;
      }
      final raw = (_attributeValue(element, 'b') ?? '').toLowerCase();
      if (raw == '1' || raw == 'true') {
        return true;
      }
    }
    return roleHint == PresentationTextRole.title;
  }

  PresentationTextRole _resolvePresentationTextRole(
    XmlElement shape, {
    required List<PresentationTextParagraph> paragraphs,
  }) {
    final placeholder = _firstDescendant(shape, 'ph');
    final type = (_attributeValue(placeholder, 'type') ?? '').trim();
    if (type == 'title' || type == 'ctrTitle') {
      return PresentationTextRole.title;
    }
    if (type == 'subTitle') {
      return PresentationTextRole.subtitle;
    }
    if (type == 'dt' || type == 'ftr' || type == 'sldNum') {
      return PresentationTextRole.caption;
    }

    final shapeName =
        (_attributeValue(_firstDescendant(shape, 'cNvPr'), 'name') ?? '')
            .toLowerCase();
    if (shapeName.contains('title')) {
      return PresentationTextRole.title;
    }
    if (shapeName.contains('subtitle')) {
      return PresentationTextRole.subtitle;
    }

    if (paragraphs.isNotEmpty) {
      final maxFontSize = paragraphs
          .map((paragraph) => paragraph.fontSizePt ?? 0)
          .reduce(math.max);
      if (maxFontSize >= 24) {
        return PresentationTextRole.title;
      }
      if (maxFontSize >= 18 && paragraphs.length == 1) {
        return PresentationTextRole.subtitle;
      }
    }
    return PresentationTextRole.body;
  }

  PresentationTextAlign _resolvePresentationTextAlign(
    XmlElement? paragraphProps,
  ) {
    final raw = (_attributeValue(paragraphProps, 'algn') ?? '').toLowerCase();
    return switch (raw) {
      'ctr' => PresentationTextAlign.center,
      'r' => PresentationTextAlign.end,
      'just' => PresentationTextAlign.justify,
      _ => PresentationTextAlign.start,
    };
  }

  _PresentationRect? _resolvePresentationGeometry({
    required XmlElement node,
    required _PresentationSize slideSize,
    required _TransformContext transform,
    required PresentationTextRole role,
    required int fallbackIndex,
    required bool allowFallback,
  }) {
    final rawGeometry =
        _readNodeGeometry(node) ??
        (allowFallback
            ? _fallbackPresentationGeometry(
                slideSize,
                role: role,
                fallbackIndex: fallbackIndex,
              )
            : null);
    if (rawGeometry == null) {
      return null;
    }
    return transform.apply(rawGeometry);
  }

  _PresentationRect? _readNodeGeometry(XmlElement node) {
    switch (node.name.local) {
      case 'sp':
      case 'pic':
        final shapeProps = _directChildNamed(node, 'spPr');
        return _readGeometryFromTransform(_firstDescendant(shapeProps, 'xfrm'));
      case 'graphicFrame':
        return _readGeometryFromTransform(_directChildNamed(node, 'xfrm'));
      default:
        return null;
    }
  }

  _PresentationRect? _readGeometryFromTransform(XmlElement? transform) {
    if (transform == null) {
      return null;
    }
    final offset = _firstDescendant(transform, 'off');
    final extent = _firstDescendant(transform, 'ext');
    final x = double.tryParse(_attributeValue(offset, 'x') ?? '');
    final y = double.tryParse(_attributeValue(offset, 'y') ?? '');
    final width = double.tryParse(_attributeValue(extent, 'cx') ?? '');
    final height = double.tryParse(_attributeValue(extent, 'cy') ?? '');
    if (x == null || y == null || width == null || height == null) {
      return null;
    }
    return _PresentationRect(x: x, y: y, width: width, height: height);
  }

  _PresentationRect _fallbackPresentationGeometry(
    _PresentationSize slideSize, {
    required PresentationTextRole role,
    required int fallbackIndex,
  }) {
    final width = slideSize.width;
    final height = slideSize.height;
    return switch (role) {
      PresentationTextRole.title => _PresentationRect(
        x: width * 0.08,
        y: height * 0.08,
        width: width * 0.84,
        height: height * 0.14,
      ),
      PresentationTextRole.subtitle => _PresentationRect(
        x: width * 0.08,
        y: height * 0.23,
        width: width * 0.84,
        height: height * 0.1,
      ),
      PresentationTextRole.caption => _PresentationRect(
        x: width * 0.08,
        y: height * 0.9,
        width: width * 0.84,
        height: height * 0.05,
      ),
      PresentationTextRole.body => _PresentationRect(
        x: width * 0.08,
        y: height * (0.3 + math.min(fallbackIndex, 2) * 0.18),
        width: width * 0.84,
        height: height * math.max(0.16, 0.48 - fallbackIndex * 0.08),
      ),
    };
  }

  _TransformContext _resolveGroupTransform(
    XmlElement group,
    _TransformContext parent,
  ) {
    final groupProperties = _directChildNamed(group, 'grpSpPr');
    final transform = _firstDescendant(groupProperties, 'xfrm');
    if (transform == null) {
      return parent;
    }
    final offset = _firstDescendant(transform, 'off');
    final extent = _firstDescendant(transform, 'ext');
    final childOffset = _firstDescendant(transform, 'chOff');
    final childExtent = _firstDescendant(transform, 'chExt');
    final groupOffsetX =
        double.tryParse(_attributeValue(offset, 'x') ?? '') ?? 0;
    final groupOffsetY =
        double.tryParse(_attributeValue(offset, 'y') ?? '') ?? 0;
    final groupExtentX =
        double.tryParse(_attributeValue(extent, 'cx') ?? '') ?? 1;
    final groupExtentY =
        double.tryParse(_attributeValue(extent, 'cy') ?? '') ?? 1;
    final childOffsetX =
        double.tryParse(_attributeValue(childOffset, 'x') ?? '') ?? 0;
    final childOffsetY =
        double.tryParse(_attributeValue(childOffset, 'y') ?? '') ?? 0;
    final childExtentX =
        double.tryParse(_attributeValue(childExtent, 'cx') ?? '') ??
        groupExtentX;
    final childExtentY =
        double.tryParse(_attributeValue(childExtent, 'cy') ?? '') ??
        groupExtentY;
    final scaleX = groupExtentX == 0 || childExtentX == 0
        ? parent.scaleX
        : parent.scaleX * (groupExtentX / childExtentX);
    final scaleY = groupExtentY == 0 || childExtentY == 0
        ? parent.scaleY
        : parent.scaleY * (groupExtentY / childExtentY);

    return _TransformContext(
      translateX:
          parent.translateX + (groupOffsetX - parent.originX) * parent.scaleX,
      translateY:
          parent.translateY + (groupOffsetY - parent.originY) * parent.scaleY,
      scaleX: scaleX,
      scaleY: scaleY,
      originX: childOffsetX,
      originY: childOffsetY,
    );
  }

  int? _resolveDirectFillColor(XmlElement shape) {
    final shapeProps = _directChildNamed(shape, 'spPr') ?? shape;
    return _parseColorFromElement(_firstDescendant(shapeProps, 'solidFill'));
  }

  int? _resolveDirectBorderColor(XmlElement shape) {
    final shapeProps = _directChildNamed(shape, 'spPr') ?? shape;
    return _parseColorFromElement(_firstDescendant(shapeProps, 'ln'));
  }

  int? _resolveDirectParagraphColor(XmlElement paragraph) {
    for (final element in paragraph.descendants.whereType<XmlElement>()) {
      if (element.name.local != 'rPr' &&
          element.name.local != 'defRPr' &&
          element.name.local != 'endParaRPr') {
        continue;
      }
      final color = _parseColorFromElement(element);
      if (color != null) {
        return color;
      }
    }
    return null;
  }

  int? _parseColorFromElement(XmlElement? root) {
    if (root == null) {
      return null;
    }
    for (final element in root.descendants.whereType<XmlElement>()) {
      switch (element.name.local) {
        case 'srgbClr':
          return _parseRgbColor(_attributeValue(element, 'val'));
        case 'schemeClr':
          final scheme = (_attributeValue(element, 'val') ?? '').toLowerCase();
          return switch (scheme) {
            'dk1' || 'tx1' => 0xFF111827,
            'lt1' || 'bg1' => 0xFFFFFFFF,
            'accent1' => 0xFF2563EB,
            'accent2' => 0xFF059669,
            'accent3' => 0xFFF59E0B,
            'accent4' => 0xFF7C3AED,
            'accent5' => 0xFFDB2777,
            'accent6' => 0xFF0891B2,
            _ => null,
          };
        case 'sysClr':
          return _parseRgbColor(
            _attributeValue(element, 'lastClr') ??
                _attributeValue(element, 'val'),
          );
      }
    }
    return null;
  }

  String _resolvePresentationSlideLabel(
    List<PresentationPreviewElement> elements,
    int slideIndex,
  ) {
    for (final element in elements) {
      if (element case PresentationTextElement(
        :final role,
        :final paragraphs,
      )) {
        if (role == PresentationTextRole.title && paragraphs.isNotEmpty) {
          return paragraphs.first.text;
        }
      }
    }
    for (final element in elements) {
      if (element case PresentationTextElement(:final paragraphs)) {
        if (paragraphs.isNotEmpty) {
          return paragraphs.first.text;
        }
      }
    }
    return '第 $slideIndex 页';
  }

  _PresentationSize? _readPresentationSlideSize(XmlDocument? presentation) {
    final sizeElement = _firstDescendant(presentation?.rootElement, 'sldSz');
    final width = double.tryParse(_attributeValue(sizeElement, 'cx') ?? '');
    final height = double.tryParse(_attributeValue(sizeElement, 'cy') ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return _PresentationSize(width: width, height: height);
  }

  List<String> _resolvePresentationSlidePaths(
    Archive archive,
    XmlDocument? presentationDocument,
    Map<String, String> presentationRels,
  ) {
    final slidePaths = <String>[];
    if (presentationDocument != null) {
      for (final slideId in _descendantsNamed(
        presentationDocument.rootElement,
        'sldId',
      )) {
        final relId = _attributeValue(slideId, 'id');
        final path = relId == null ? null : presentationRels[relId];
        if (path != null) {
          slidePaths.add(path);
        }
      }
    }
    if (slidePaths.isNotEmpty) {
      return slidePaths;
    }

    final files =
        archive.files
            .where(
              (file) =>
                  file.isFile &&
                  p.posix.dirname(file.name) == 'ppt/slides' &&
                  p.posix.basename(file.name).startsWith('slide') &&
                  p.posix.extension(file.name) == '.xml',
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return files.map((file) => file.name).toList();
  }

  Future<Archive> _decodeArchive(String localPath) async {
    final bytes = await File(localPath).readAsBytes();
    return ZipDecoder().decodeBytes(bytes);
  }

  Map<String, String> _readRelationships(
    Archive archive, {
    required String relsPath,
    required String baseDir,
  }) {
    final xmlString = _readUtf8File(archive, relsPath);
    if (xmlString == null || xmlString.isEmpty) {
      return const {};
    }

    final document = XmlDocument.parse(xmlString);
    final result = <String, String>{};
    for (final element in _descendantsNamed(
      document.rootElement,
      'Relationship',
    )) {
      final id = _attributeValue(element, 'Id');
      final target = _attributeValue(element, 'Target');
      if (id == null || target == null) {
        continue;
      }
      result[id] = p.posix.normalize(p.posix.join(baseDir, target));
    }
    return result;
  }

  String? _readUtf8File(Archive archive, String name) {
    final bytes = _readBinaryFile(archive, name);
    if (bytes == null) {
      return null;
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  Uint8List? _readBinaryFile(Archive archive, String name) {
    final entry = archive.findFile(name);
    if (entry == null || !entry.isFile) {
      return null;
    }
    final bytes = entry.readBytes() ?? entry.content;
    return Uint8List.fromList(bytes);
  }

  XmlElement? _directChildNamed(XmlElement? root, String localName) {
    if (root == null) {
      return null;
    }
    for (final child in root.childElements) {
      if (child.name.local == localName) {
        return child;
      }
    }
    return null;
  }

  XmlElement? _firstDescendant(XmlElement? root, String localName) {
    if (root == null) {
      return null;
    }
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) {
        return element;
      }
    }
    return null;
  }

  Iterable<XmlElement> _descendantsNamed(
    XmlElement root,
    String localName,
  ) sync* {
    for (final element in root.descendants.whereType<XmlElement>()) {
      if (element.name.local == localName) {
        yield element;
      }
    }
  }

  String? _attributeValue(XmlElement? element, String localName) {
    if (element == null) {
      return null;
    }
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName) {
        return attribute.value;
      }
    }
    return null;
  }

  int _columnIndexFromCellReference(String cellReference) {
    final letters = cellReference.replaceAll(RegExp(r'[^A-Z]'), '');
    var result = 0;
    for (final unit in letters.codeUnits) {
      result = result * 26 + unit - 64;
    }
    return math.max(0, result - 1);
  }

  String _spreadsheetColumnLabel(int index) {
    var current = index + 1;
    final buffer = StringBuffer();
    while (current > 0) {
      final remainder = (current - 1) % 26;
      buffer.writeCharCode(65 + remainder);
      current = (current - 1) ~/ 26;
    }
    return buffer.toString().split('').reversed.join();
  }

  int? _parseRgbColor(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final normalized = value.replaceAll('#', '').padLeft(6, '0');
    if (normalized.length < 6) {
      return null;
    }
    final rgb = int.tryParse(
      normalized.substring(normalized.length - 6),
      radix: 16,
    );
    if (rgb == null) {
      return null;
    }
    return 0xFF000000 | rgb;
  }

  String _escapeHtml(String value) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(value);
  }
}

final officePreviewParserProvider = Provider<OfficePreviewParser>((ref) {
  return const OfficePreviewParser();
});

class _PresentationSize {
  const _PresentationSize({required this.width, required this.height});

  final double width;
  final double height;
}

class _PresentationRect {
  const _PresentationRect({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

class _TransformContext {
  const _TransformContext({
    required this.translateX,
    required this.translateY,
    required this.scaleX,
    required this.scaleY,
    required this.originX,
    required this.originY,
  });

  const _TransformContext.identity()
    : translateX = 0,
      translateY = 0,
      scaleX = 1,
      scaleY = 1,
      originX = 0,
      originY = 0;

  final double translateX;
  final double translateY;
  final double scaleX;
  final double scaleY;
  final double originX;
  final double originY;

  _PresentationRect apply(_PresentationRect rect) {
    return _PresentationRect(
      x: translateX + (rect.x - originX) * scaleX,
      y: translateY + (rect.y - originY) * scaleY,
      width: rect.width * scaleX,
      height: rect.height * scaleY,
    );
  }
}

class _PresentationFallbackCounter {
  final _counts = <PresentationTextRole, int>{};

  int next(PresentationTextRole role) {
    final current = _counts[role] ?? 0;
    _counts[role] = current + 1;
    return current;
  }
}
