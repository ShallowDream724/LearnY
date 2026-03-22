import 'dart:typed_data';

import '../file_preview_registry.dart';

sealed class PreparedFilePreview {
  const PreparedFilePreview({required this.descriptor});

  final FilePreviewDescriptor descriptor;
}

final class PdfPreparedFilePreview extends PreparedFilePreview {
  const PdfPreparedFilePreview({
    required super.descriptor,
    required this.filePath,
  });

  final String filePath;
}

final class ImagePreparedFilePreview extends PreparedFilePreview {
  const ImagePreparedFilePreview({
    required super.descriptor,
    required this.filePath,
  });

  final String filePath;
}

final class TextPreparedFilePreview extends PreparedFilePreview {
  const TextPreparedFilePreview({
    required super.descriptor,
    required this.content,
    required this.isTruncated,
  });

  final String content;
  final bool isTruncated;
}

enum HtmlPreparedFilePreviewKind { document, spreadsheet }

final class HtmlPreparedFilePreview extends PreparedFilePreview {
  const HtmlPreparedFilePreview({
    required super.descriptor,
    required this.kind,
    required this.htmlBody,
    this.note,
  });

  final HtmlPreparedFilePreviewKind kind;
  final String htmlBody;
  final String? note;
}

final class PresentationPreparedFilePreview extends PreparedFilePreview {
  const PresentationPreparedFilePreview({
    required super.descriptor,
    required this.document,
  });

  final PresentationPreviewDocument document;
}

final class UnsupportedPreparedFilePreview extends PreparedFilePreview {
  const UnsupportedPreparedFilePreview({
    required super.descriptor,
    required this.message,
  });

  final String message;
}

class PresentationPreviewDocument {
  const PresentationPreviewDocument({
    required this.slideWidth,
    required this.slideHeight,
    required this.slides,
  });

  final double slideWidth;
  final double slideHeight;
  final List<PresentationPreviewSlide> slides;
}

class PresentationPreviewSlide {
  const PresentationPreviewSlide({
    required this.index,
    required this.label,
    required this.elements,
    this.backgroundColorArgb,
    this.defaultTextColorArgb,
  });

  final int index;
  final String label;
  final List<PresentationPreviewElement> elements;
  final int? backgroundColorArgb;
  final int? defaultTextColorArgb;
}

sealed class PresentationPreviewElement {
  const PresentationPreviewElement({
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

enum PresentationTextRole { title, subtitle, body, caption }

enum PresentationTextAlign { start, center, end, justify }

final class PresentationTextElement extends PresentationPreviewElement {
  const PresentationTextElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.role,
    required this.paragraphs,
    this.fillColorArgb,
    this.borderColorArgb,
  });

  final PresentationTextRole role;
  final List<PresentationTextParagraph> paragraphs;
  final int? fillColorArgb;
  final int? borderColorArgb;
}

class PresentationTextParagraph {
  const PresentationTextParagraph({
    required this.text,
    required this.align,
    required this.level,
    required this.bullet,
    this.fontSizePt,
    this.colorArgb,
    this.bold = false,
  });

  final String text;
  final PresentationTextAlign align;
  final int level;
  final bool bullet;
  final double? fontSizePt;
  final int? colorArgb;
  final bool bold;
}

final class PresentationImageElement extends PresentationPreviewElement {
  const PresentationImageElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.bytes,
    required this.mimeType,
    this.borderColorArgb,
  });

  final Uint8List bytes;
  final String mimeType;
  final int? borderColorArgb;
}

final class PresentationTableElement extends PresentationPreviewElement {
  const PresentationTableElement({
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required this.rows,
    this.fillColorArgb,
    this.borderColorArgb,
  });

  final List<PresentationTableRow> rows;
  final int? fillColorArgb;
  final int? borderColorArgb;
}

class PresentationTableRow {
  const PresentationTableRow({required this.cells});

  final List<String> cells;
}
