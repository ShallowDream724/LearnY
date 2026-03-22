import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learn_y/core/files/file_preview_registry.dart';
import 'package:learn_y/core/files/preview/file_preview_models.dart';
import 'package:learn_y/core/files/preview/office_preview_parser.dart';

void main() {
  group('OfficePreviewParser', () {
    const parser = OfficePreviewParser();
    const registry = FilePreviewRegistry();

    test('parses basic DOCX paragraphs and tables', () async {
      final path = await _writeArchive(
        Archive()..add(
          ArchiveFile.string('word/document.xml', '''
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    <w:p>
      <w:pPr>
        <w:pStyle w:val="Heading1" />
      </w:pPr>
      <w:r><w:t>LearnY 文档</w:t></w:r>
    </w:p>
    <w:p>
      <w:r><w:t>第一段内容</w:t></w:r>
    </w:p>
    <w:tbl>
      <w:tr>
        <w:tc><w:p><w:r><w:t>A1</w:t></w:r></w:p></w:tc>
        <w:tc><w:p><w:r><w:t>B1</w:t></w:r></w:p></w:tc>
      </w:tr>
    </w:tbl>
  </w:body>
</w:document>
'''),
        ),
        suffix: '.docx',
      );

      final preview = await parser.parseDocx(
        descriptor: registry.describe(fileName: 'sample.docx'),
        localPath: path,
      );

      expect(preview, isA<HtmlPreparedFilePreview>());
      expect(preview.htmlBody, contains('LearnY 文档'));
      expect(preview.htmlBody, contains('第一段内容'));
      expect(preview.htmlBody, contains('A1'));
      expect(preview.htmlBody, contains('<table>'));
    });

    test('parses basic XLSX shared strings and sheet data', () async {
      final path = await _writeArchive(
        Archive()
          ..add(
            ArchiveFile.string('xl/workbook.xml', '''
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="课程表" sheetId="1" r:id="rId1" />
  </sheets>
</workbook>
'''),
          )
          ..add(
            ArchiveFile.string('xl/_rels/workbook.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="worksheet" Target="worksheets/sheet1.xml" />
</Relationships>
'''),
          )
          ..add(
            ArchiveFile.string('xl/sharedStrings.xml', '''
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <si><t>课程</t></si>
  <si><t>土力学</t></si>
</sst>
'''),
          )
          ..add(
            ArchiveFile.string('xl/worksheets/sheet1.xml', '''
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
    </row>
  </sheetData>
</worksheet>
'''),
          ),
        suffix: '.xlsx',
      );

      final preview = await parser.parseXlsx(
        descriptor: registry.describe(fileName: 'sheet.xlsx'),
        localPath: path,
      );

      expect(preview, isA<HtmlPreparedFilePreview>());
      expect(preview.htmlBody, contains('课程表'));
      expect(preview.htmlBody, contains('课程'));
      expect(preview.htmlBody, contains('土力学'));
    });

    test('parses PPTX slide layout into positioned elements', () async {
      final path = await _writeArchive(
        Archive()
          ..add(
            ArchiveFile.string('ppt/presentation.xml', '''
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <p:sldSz cx="9144000" cy="5143500" />
  <p:sldIdLst>
    <p:sldId id="256" r:id="rId1" />
  </p:sldIdLst>
</p:presentation>
'''),
          )
          ..add(
            ArchiveFile.string('ppt/_rels/presentation.xml.rels', '''
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="slide" Target="slides/slide1.xml" />
</Relationships>
'''),
          )
          ..add(
            ArchiveFile.string('ppt/slides/slide1.xml', '''
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:nvSpPr>
          <p:nvPr><p:ph type="title" /></p:nvPr>
        </p:nvSpPr>
        <p:spPr>
          <a:xfrm>
            <a:off x="731520" y="365760" />
            <a:ext cx="7680960" cy="914400" />
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:p><a:r><a:t>商品级课件</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
      <p:sp>
        <p:spPr>
          <a:xfrm>
            <a:off x="731520" y="1463040" />
            <a:ext cx="7315200" cy="2194560" />
          </a:xfrm>
        </p:spPr>
        <p:txBody>
          <a:p><a:r><a:t>统一文件预览</a:t></a:r></a:p>
          <a:p><a:r><a:t>横竖屏自适应</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>
'''),
          ),
        suffix: '.pptx',
      );

      final preview = await parser.parsePptx(
        descriptor: registry.describe(fileName: 'slides.pptx'),
        localPath: path,
      );

      expect(preview.document.slides, hasLength(1));
      expect(preview.document.slideWidth, 9144000);
      expect(preview.document.slides.first.label, '商品级课件');
      final textElements = preview.document.slides.first.elements
          .whereType<PresentationTextElement>()
          .toList();
      expect(textElements, hasLength(2));
      expect(textElements.first.role, PresentationTextRole.title);
      expect(textElements.first.paragraphs.first.text, '商品级课件');
      expect(
        textElements.last.paragraphs.map((paragraph) => paragraph.text),
        containsAll(<String>['统一文件预览', '横竖屏自适应']),
      );
      expect(textElements.first.width, greaterThan(1000));
    });
  });
}

Future<String> _writeArchive(Archive archive, {required String suffix}) async {
  final directory = await Directory.systemTemp.createTemp(
    'learny-office-preview-',
  );
  final file = File('${directory.path}/preview$suffix');
  final bytes = ZipEncoder().encodeBytes(archive);
  await file.writeAsBytes(bytes, flush: true);

  addTearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  return file.path;
}
